import CoreHaptics
import UIKit

/// Owns the `CHHapticEngine` and fires hit-quality-tuned patterns.
///
/// ## Latency budget
///
/// Flappy Bird's feel hinges on the haptic firing within the same vsync as
/// the visual. `CHHapticEngine`'s first play after process launch has a
/// non-trivial warm-up cost, so we:
///
/// 1. Start the engine eagerly in `init`.
/// 2. Pre-build every pattern as a `CHHapticPatternPlayer` and keep them
///    cached. Subsequent plays only call `start(atTime:)`.
/// 3. Fire a zero-intensity "primer" pattern on `prewarm()`, which forces
///    the engine through its first dispatch before the player touches the
///    screen.
///
/// ## Graceful degradation
///
/// On devices without Core Haptics (or if the engine dies), we fall back to
/// `UIImpactFeedbackGenerator`. Gameplay never depends on haptics succeeding.
final class HapticManager {
    static let shared = HapticManager()

    var isEnabled: Bool = true

    private let supportsHaptics: Bool
    private var engine: CHHapticEngine?

    private var hitPlayers: [HitQuality: CHHapticPatternPlayer] = [:]
    private var missPlayer: CHHapticPatternPlayer?
    private var breakPlayer: CHHapticPatternPlayer?
    private var tierPlayers: [Int: CHHapticPatternPlayer] = [:]
    private var primerPlayer: CHHapticPatternPlayer?

    private let lightFallback  = UIImpactFeedbackGenerator(style: .light)
    private let mediumFallback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFallback  = UIImpactFeedbackGenerator(style: .heavy)

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

        if supportsHaptics {
            startEngine()
            buildPatternCache()
        } else {
            [lightFallback, mediumFallback, heavyFallback].forEach { $0.prepare() }
        }

        GameEventBus.shared.subscribe(self) { [weak self] event in
            self?.handle(event)
        }
    }

    /// Force the first dispatch through the engine so a real hit isn't the
    /// first one. Safe to call multiple times.
    func prewarm() {
        guard supportsHaptics, let player = primerPlayer else {
            mediumFallback.prepare()
            return
        }
        try? player.start(atTime: 0)
    }

    // MARK: - Engine

    private func startEngine() {
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = false
            engine.stoppedHandler = { [weak self] _ in
                self?.startEngine()
                self?.buildPatternCache()
            }
            engine.resetHandler = { [weak self] in
                try? self?.engine?.start()
                self?.buildPatternCache()
            }
            try engine.start()
            self.engine = engine
        } catch {
            self.engine = nil
        }
    }

    private func buildPatternCache() {
        guard let engine = engine else { return }

        hitPlayers = [:]
        for quality in [HitQuality.perfect, .great, .good] {
            if let pattern = makeHitPattern(quality: quality),
               let player = try? engine.makePlayer(with: pattern) {
                hitPlayers[quality] = player
            }
        }

        if let pattern = makeMissPattern(),
           let player = try? engine.makePlayer(with: pattern) {
            missPlayer = player
        }

        if let pattern = makeBreakPattern(),
           let player = try? engine.makePlayer(with: pattern) {
            breakPlayer = player
        }

        tierPlayers = [:]
        for tier in 1...4 {
            if let pattern = makeTierPattern(tier: tier),
               let player = try? engine.makePlayer(with: pattern) {
                tierPlayers[tier] = player
            }
        }

        if let pattern = makePrimerPattern(),
           let player = try? engine.makePlayer(with: pattern) {
            primerPlayer = player
        }
    }

    // MARK: - Event routing

    private func handle(_ event: GameEvent) {
        guard isEnabled else { return }
        switch event {
        case .hit(let quality, _, _, _):
            play(quality: quality)
        case .miss:
            playMiss()
        case .comboTier(let tier) where tier > 0:
            playTier(tier: tier)
        case .comboBreak:
            playBreak()
        default:
            break
        }
    }

    // MARK: - Play

    private func play(quality: HitQuality) {
        guard supportsHaptics, let player = hitPlayers[quality] else {
            switch quality {
            case .perfect: heavyFallback.impactOccurred(intensity: 1.0)
            case .great:   mediumFallback.impactOccurred(intensity: 0.8)
            case .good:    lightFallback.impactOccurred(intensity: 0.5)
            case .miss:    break
            }
            return
        }
        try? player.start(atTime: 0)
    }

    private func playMiss() {
        guard supportsHaptics, let player = missPlayer else {
            lightFallback.impactOccurred(intensity: 0.3)
            return
        }
        try? player.start(atTime: 0)
    }

    private func playTier(tier: Int) {
        guard supportsHaptics, let player = tierPlayers[min(tier, 4)] else { return }
        try? player.start(atTime: 0)
    }

    private func playBreak() {
        guard supportsHaptics, let player = breakPlayer else {
            heavyFallback.impactOccurred(intensity: 1.0)
            return
        }
        try? player.start(atTime: 0)
    }

    // MARK: - Pattern definitions

    private func makeHitPattern(quality: HitQuality) -> CHHapticPattern? {
        let intensity: Float
        let sharpness: Float
        switch quality {
        case .perfect: intensity = Tunables.hapticPerfect; sharpness = 0.9
        case .great:   intensity = Tunables.hapticGreat;   sharpness = 0.65
        case .good:    intensity = Tunables.hapticGood;    sharpness = 0.4
        case .miss:    return nil
        }

        let transient = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )
        let continuous = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity * 0.5),
                .init(parameterID: .hapticSharpness, value: sharpness * 0.4)
            ],
            relativeTime: 0.003,
            duration: 0.028
        )
        return try? CHHapticPattern(events: [transient, continuous], parameters: [])
    }

    private func makeMissPattern() -> CHHapticPattern? {
        let dull = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: Tunables.hapticMiss),
                .init(parameterID: .hapticSharpness, value: 0.05)
            ],
            relativeTime: 0,
            duration: 0.080
        )
        return try? CHHapticPattern(events: [dull], parameters: [])
    }

    /// The "Flappy death" haptic — heavy thump followed by a descending
    /// second-tap. Calibrated to coincide with the death-thump audio and
    /// the extended frame-stop.
    private func makeBreakPattern() -> CHHapticPattern? {
        let thump = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: Tunables.hapticDeath),
                .init(parameterID: .hapticSharpness, value: 0.15)
            ],
            relativeTime: 0
        )
        let rumble = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.8),
                .init(parameterID: .hapticSharpness, value: 0.1)
            ],
            relativeTime: 0.005,
            duration: 0.180
        )
        let tail = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.55),
                .init(parameterID: .hapticSharpness, value: 0.05)
            ],
            relativeTime: 0.220
        )
        return try? CHHapticPattern(events: [thump, rumble, tail], parameters: [])
    }

    private func makeTierPattern(tier: Int) -> CHHapticPattern? {
        let intensity = min(1.0, 0.4 + 0.15 * Float(tier))
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 0
        )
        return try? CHHapticPattern(events: [event], parameters: [])
    }

    private func makePrimerPattern() -> CHHapticPattern? {
        let silent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.001),
                .init(parameterID: .hapticSharpness, value: 0.001)
            ],
            relativeTime: 0
        )
        return try? CHHapticPattern(events: [silent], parameters: [])
    }
}
