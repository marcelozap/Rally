import Foundation

/// The match-flow phase the player is in *right now*.
///
/// The spawner does not know about "warm-up" vs "exchange" — it just asks the
/// `MatchFlowCoordinator` for the current `PhaseProfile` every frame and uses
/// the BPM, hit-window scalar, and double-ball probability it returns.
///
/// Tunables live in `Tunables.MatchFlow`. Names read like a match commentator
/// would describe the rally:
///
/// - `.warmUp`   — first ~15% of the session. Slow, generous timing, no doubles.
/// - `.exchange` — the steady rally body. Medium BPM, normal windows.
/// - `.pressure` — driven by sustained combo *or* late-session clock. Faster
///                 BPM, tighter windows, occasional doubles.
/// - `.breaker`  — peak intensity: a high combo *and* late session. Fastest
///                 spawns, most doubles, narrow windows.
/// - `.recovery` — temporary cooldown after a combo break: spawn density drops
///                 for a few seconds so the player isn't immediately killed
///                 again. Always resolves back to whichever non-recovery phase
///                 the timeline would otherwise be in.
enum MatchFlowPhase: String, CaseIterable, Equatable {
    case warmUp    = "WARM-UP"
    case exchange  = "EXCHANGE"
    case pressure  = "PRESSURE"
    case breaker   = "BREAKER"
    case recovery  = "RECOVERY"
}

/// Numbers the spawner / scene read on the hot path. Anything not in here
/// stays at its global `Tunables` default for that phase.
struct PhaseProfile: Equatable {
    /// Beats per minute that the procedural beatmap should target while in
    /// this phase. The spawner doesn't change tempo mid-flight; this is read
    /// at chart-generation time per chunk.
    let bpm: Double

    /// Multiplier on `Tunables.ballTravelSeconds`. >1 means slower balls
    /// (easier reads). The warm-up phase uses ~1.15 so the very first balls
    /// are forgiving.
    let travelScalar: Double

    /// Multiplier on the timing-window widths in `HitQuality`. <1 means
    /// tighter windows. Defaults to 1.0; pressure/breaker shave 10-15%.
    let timingWindowScalar: Double

    /// Probability of emitting a double-ball alongside the main spawn.
    /// 0 in warm-up; ramps up through pressure and breaker.
    let doubleNoteProbability: Double

    /// Subdivision policy. Values are fractions of a beat (1.0 = quarter,
    /// 0.5 = eighth, 0.25 = sixteenth). The spawner picks one slot at random
    /// according to `subdivisionWeights` to keep the chart from sounding
    /// metronomic.
    let subdivisions: [Double]
    let subdivisionWeights: [Double]

    /// Multiplier on spawn density independent of subdivision — the spawner
    /// may roll a `rest` if `density < 1.0`, leaving a hole in the chart.
    let density: Double
}

/// Single source of truth for "what phase are we in right now?"
///
/// Inputs:
/// - elapsed `trackTime` (seconds, 0…sessionDurationSeconds)
/// - current `combo`
/// - whether the last meaningful event was a combo break (drives `.recovery`)
///
/// The coordinator owns no SpriteKit references — it can be unit-tested by
/// driving `update(...)` directly. `GameScene` queries `currentPhase` every
/// frame; `RhythmSpawner` queries `currentProfile()` when authoring chart
/// chunks.
final class MatchFlowCoordinator {

    private(set) var currentPhase: MatchFlowPhase = .warmUp
    private(set) var lastPhaseChangeAt: TimeInterval = 0

    /// Notified whenever the phase changes (warm-up → exchange, etc.).
    /// `GameScene` uses this for the debug overlay + bus event.
    var onPhaseChange: ((MatchFlowPhase, MatchFlowPhase) -> Void)?

    private let sessionDurationSeconds: Double
    private var combo: Int = 0
    private var recoveryUntil: TimeInterval = 0

    /// Designated init. `bpmResolver` defaults to bundled `Tunables` so
    /// unit tests are deterministic; production callers can pass a closure
    /// over `RemoteTunables.shared.bpm(for:)`.
    init(sessionDurationSeconds: Double, bpmResolver: BPMResolver? = nil) {
        self.sessionDurationSeconds = sessionDurationSeconds
        self.bpmResolver = bpmResolver ?? { phase in
            switch phase {
            case .warmUp:   return Tunables.MatchFlow.bpmWarmUp
            case .exchange: return Tunables.MatchFlow.bpmExchange
            case .pressure: return Tunables.MatchFlow.bpmPressure
            case .breaker:  return Tunables.MatchFlow.bpmBreaker
            case .recovery: return Tunables.MatchFlow.bpmExchange
            }
        }
    }

    /// Drive every frame from `GameScene.update(_:)`.
    func update(trackTime: TimeInterval, combo: Int) {
        self.combo = combo

        let progress = sessionDurationSeconds <= 0
            ? 0
            : min(1, max(0, trackTime / sessionDurationSeconds))

        let resolved: MatchFlowPhase = {
            if trackTime < recoveryUntil { return .recovery }

            // Late-session always feels like at least .pressure, even if the
            // player has been quietly missing notes — the clock alone raises
            // stakes.
            let clockPhase: MatchFlowPhase
            switch progress {
            case ..<Tunables.MatchFlow.warmUpProgress:   clockPhase = .warmUp
            case ..<Tunables.MatchFlow.pressureProgress: clockPhase = .exchange
            case ..<Tunables.MatchFlow.breakerProgress:  clockPhase = .pressure
            default:                                     clockPhase = .breaker
            }

            // Combo upgrades clock-phase, never downgrades.
            let comboPhase: MatchFlowPhase
            switch combo {
            case ..<Tunables.comboTier1: comboPhase = .warmUp
            case ..<Tunables.comboTier2: comboPhase = .exchange
            case ..<Tunables.comboTier3: comboPhase = .pressure
            default:                     comboPhase = .breaker
            }

            return max(clockPhase, comboPhase, by: phaseRank)
        }()

        if resolved != currentPhase {
            let prev = currentPhase
            currentPhase = resolved
            lastPhaseChangeAt = trackTime
            onPhaseChange?(prev, resolved)
        }
    }

    /// Called by `GameScene` when a combo breaks. Schedules a short
    /// `.recovery` window so the spawner thins out for a couple of seconds.
    func registerComboBreak(at trackTime: TimeInterval) {
        recoveryUntil = trackTime + Tunables.MatchFlow.recoverySeconds
    }

    /// Profile for the *current* phase. Spawner reads this when it authors
    /// the next chart chunk.
    func currentProfile() -> PhaseProfile {
        profile(for: currentPhase)
    }

    /// BPM resolver. Defaults to bundled `Tunables`, but a `RemoteTunables`
    /// manifest can override per-phase BPM live without shipping a build.
    /// Injected (rather than calling `RemoteTunables.shared` directly) so
    /// tests don't reach across actor boundaries.
    typealias BPMResolver = (MatchFlowPhase) -> Double
    private let bpmResolver: BPMResolver

    /// Phase profile lookup. Pure given the injected `bpmResolver` —
    /// exposed for tests.
    func profile(for phase: MatchFlowPhase) -> PhaseProfile {
        let bpm = bpmResolver(phase)
        switch phase {
        case .warmUp:
            return PhaseProfile(
                bpm: bpm,
                travelScalar: 1.15,
                timingWindowScalar: 1.10,
                doubleNoteProbability: 0.0,
                subdivisions: [1.0],
                subdivisionWeights: [1.0],
                density: 0.85
            )
        case .exchange:
            return PhaseProfile(
                bpm: bpm,
                travelScalar: 1.0,
                timingWindowScalar: 1.0,
                doubleNoteProbability: 0.0,
                subdivisions: [1.0, 0.5],
                subdivisionWeights: [0.6, 0.4],
                density: 1.0
            )
        case .pressure:
            return PhaseProfile(
                bpm: bpm,
                travelScalar: 0.92,
                timingWindowScalar: 0.9,
                doubleNoteProbability: 0.0,
                subdivisions: [0.5, 0.25],
                subdivisionWeights: [0.75, 0.25],
                density: 1.0
            )
        case .breaker:
            return PhaseProfile(
                bpm: bpm,
                travelScalar: 0.85,
                timingWindowScalar: 0.85,
                doubleNoteProbability: 0.0,
                subdivisions: [0.5, 0.25],
                subdivisionWeights: [0.5, 0.5],
                density: 1.0
            )
        case .recovery:
            // Recovery is intentionally sparse — the player has just been
            // killed; give them a moment.
            return PhaseProfile(
                bpm: bpm,
                travelScalar: 1.05,
                timingWindowScalar: 1.05,
                doubleNoteProbability: 0.0,
                subdivisions: [1.0],
                subdivisionWeights: [1.0],
                density: 0.55
            )
        }
    }

    // MARK: - Helpers

    /// Ranking used to "pick whichever phase escalates more." Recovery is
    /// off this ladder — it's a temporary state, not an escalation tier.
    private func phaseRank(_ phase: MatchFlowPhase) -> Int {
        switch phase {
        case .warmUp:   return 0
        case .exchange: return 1
        case .pressure: return 2
        case .breaker:  return 3
        case .recovery: return -1
        }
    }
}

private func max(_ a: MatchFlowPhase, _ b: MatchFlowPhase, by rank: (MatchFlowPhase) -> Int) -> MatchFlowPhase {
    rank(a) >= rank(b) ? a : b
}
