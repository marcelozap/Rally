import CoreGraphics
import Foundation

/// Central knob room for "game feel". The single source of truth for every
/// number that affects how the game _feels_ — input latency, frame-stop
/// durations, shake amplitudes, audio envelopes, haptic intensities.
///
/// Rules:
/// 1. No `Tunables` value is ever computed at runtime. They are all baked at
///    build time so the feel is reproducible commit-to-commit.
/// 2. If a tweakable number appears in more than one file, it goes here.
/// 3. The names read like a designer's spreadsheet, not a programmer's
///    variables — `frameStopHitMs`, not `tFreeze`.
enum Tunables {

    // MARK: - Frame-stop ("hit pause")
    //
    // Two regimes:
    //
    // 1. Per-hit "weight" pause — strictly sub-frame at 60 Hz. Just enough
    //    to make the brain interpret the moment as heavier than it is,
    //    without ever costing a full vsync. Follows GDD §1.1 (6 / 3 / 0 ms).
    //    A previous draft used 24 / 12 / 0 ms (GDD §0.5) which was full
    //    visible hitches at 60 Hz — that broke the 16th-note flow.
    //
    // 2. Death pause — the iconic Flappy freeze. Long, deliberate, the
    //    "oh no" moment. Coincides with the red flash, screen shake, and
    //    descending death tone.

    static let frameStopPerfectMs: Double = 6
    static let frameStopGreatMs:   Double = 3
    static let frameStopGoodMs:    Double = 0
    static let frameStopMissMs:    Double = 0

    /// Extended freeze on a combo break — the "you died" moment.
    static let frameStopDeathMs:   Double = 220

    // MARK: - Screen shake (in points, applied to the camera)

    static let shakeAmplitudePerfect: CGFloat = 6
    static let shakeAmplitudeGreat:   CGFloat = 3
    static let shakeAmplitudeGood:    CGFloat = 1.5
    static let shakeAmplitudeMiss:    CGFloat = 0
    static let shakeAmplitudeDeath:   CGFloat = 18    // The "Flappy hit"

    static let shakeDurationHitMs:    Double = 120
    static let shakeDurationDeathMs:  Double = 380

    // MARK: - Visual feedback timing

    static let hitBurstDurationMs:    Double = 300
    static let perfectBurstDurationMs: Double = 450
    static let scoreTweenDurationMs:  Double = 220
    static let redFlashDurationMs:    Double = 380
    static let tierFlashDurationMs:   Double = 600

    // MARK: - Strike-line anticipation pulse
    //
    // A short brighten + expand on the strike line, scheduled to start
    // `strikePulseLeadMs` *before* a ball is due to land on it. The point
    // is to convert the timing read from "judge depth-scale" to "match the
    // pulse" — the same trick Beat Saber's saber-flash uses.

    /// How far ahead of the ball's arrival the pulse begins.
    static let strikePulseLeadMs: Double = 120

    /// Total pulse duration (rise + fall).
    static let strikePulseDurationMs: Double = 180

    /// Peak glow width during the pulse — additive over the strike line's
    /// resting glow.
    static let strikePulseGlowWidth: CGFloat = 28

    /// Peak alpha during the pulse, 0...1.
    static let strikePulsePeakAlpha: CGFloat = 0.95

    // MARK: - Haptic intensity (0...1)

    static let hapticPerfect: Float = 1.0
    static let hapticGreat:   Float = 0.7
    static let hapticGood:    Float = 0.4
    static let hapticMiss:    Float = 0.3
    static let hapticDeath:   Float = 1.0

    /// Soft transient fired on finger touch-down — the swing "start" tap.
    /// Flappy's tap fired a haptic on every touch regardless of outcome;
    /// having one here gives the swing a tactile beginning, not just a
    /// tactile end. Kept low so it never competes with the strike haptic.
    static let hapticTouchDown: Float = 0.22

    // MARK: - Audio envelope (the Flappy SFX palette, synthesized)
    //
    // See Audio/ToneSynth.swift. Each tuple is (frequencyHz, durationMs).

    enum Audio {
        // Per-hit "point" chime. Flappy used a quick high-pitched ding.
        static let pointFreqHz:     Double = 1320
        static let pointGlideHz:    Double = 1760
        static let pointDurationMs: Double = 120
        static let pointWaveform:   ToneSynth.Waveform = .sine

        // Perfect-hit "thump" — closer to Flappy's hit.wav: a low percussive
        // bonk with a noisy attack.
        static let hitFreqHz:        Double = 220
        static let hitGlideHz:       Double = 110
        static let hitDurationMs:    Double = 180
        static let hitNoiseMix:      Float  = 0.35
        static let hitWaveform:      ToneSynth.Waveform = .triangle

        // Miss/swing — Flappy's wing.wav was a soft filtered whoosh.
        static let wingFreqHz:       Double = 520
        static let wingGlideHz:      Double = 220
        static let wingDurationMs:   Double = 90
        static let wingNoiseMix:     Float  = 0.65
        static let wingWaveform:     ToneSynth.Waveform = .triangle

        // Combo-break "die" — falling tone, the Flappy death wail.
        static let dieFreqHz:        Double = 330
        static let dieGlideHz:       Double = 80
        static let dieDurationMs:    Double = 520
        static let dieNoiseMix:      Float  = 0.10
        static let dieWaveform:      ToneSynth.Waveform = .sawtooth

        // Combo-tier "level up" stinger. Quick ascending chord.
        static let tierBaseFreqHz:   Double = 660
        static let tierStepHz:       Double = 110
        static let tierDurationMs:   Double = 200
        static let tierWaveform:     ToneSynth.Waveform = .square

        // Envelope shape (ADSR-ish, but compact for casual game SFX).
        static let attackMs:  Double = 4
        static let releaseMs: Double = 60
        static let peakLevel: Float  = 0.85
    }

    // MARK: - Ball physics / spawn

    static let ballRadiusPoints:      CGFloat = 22
    static let ballTravelSeconds:     Double  = 1.4
    static let strikeLineYRatio:      CGFloat = 0.25
    static let spawnLineYRatio:       CGFloat = 1.05
    static let cullBelowStrikePoints: CGFloat = 40

    // MARK: - Swing gesture (Pokemon-Go-style drag-and-release)

    /// Minimum drag distance in points before a pan registers as a swing.
    /// Shorter motions are treated as accidental contact and ignored.
    static let swingMinDistance:      CGFloat = 28

    /// Pan velocity (pt/s) above which the swing counts as "committed."
    /// Below this we still register the swing but emit a softer trail.
    static let swingFastVelocity:     CGFloat = 1400

    /// Trail color & visual.
    static let swingTrailGlowWidth:   CGFloat = 14
    static let swingTrailLineWidth:   CGFloat = 5

    // MARK: - Tennis physics (post-hit impulse; swipe angle sets direction)

    /// Base impulse scale — multiplied by hit quality and swipe speed factor.
    static let tennisImpulseBase: CGFloat = 480

    /// Small upward kick when the swipe is nearly horizontal so returns
    /// still clear the net; swipe angle carries most of the trajectory.
    static let tennisImpulseUpBias: CGFloat = 160

    /// Gravity after the ball is struck (points / s²). Incoming balls stay kinematic until contact.
    static let tennisGravityDy: CGFloat = -680

    /// Incoming ball lateral jitter around center court (points).
    static let tennisSpawnJitterX: CGFloat = 72

    /// Balls scale from this (far) toward `ballDepthScaleNear` as they approach.
    static let ballDepthScaleFar:  CGFloat = 0.52
    static let ballDepthScaleNear: CGFloat = 1.0

    // MARK: - Tennis ball feed (no rhythm chart)

    /// First arrival at the strike window, in seconds from session start (after countdown).
    static let tennisFeedLeadInSeconds: Double = 2.0

    /// Spacing between feeds at the start vs end of a run (seconds between arrivals).
    static let tennisFeedBaseInterval: Double = 1.78
    static let tennisFeedMinInterval: Double = 0.92

    // MARK: - Session difficulty ramp (time-based; no combo chart)

    /// Travel time multiplier: slower balls early, faster late (`× ballTravelSeconds`).
    static let sessionTravelScalarStart: Double = 1.14
    static let sessionTravelScalarEnd:   Double = 0.86

    /// Hit timing window: wider early, tighter late (see `HitQuality`).
    static let sessionTimingWindowScalarStart: Double = 1.10
    static let sessionTimingWindowEnd:          Double = 0.88

    /// Music `phaseFloor` thresholds — fractions of session duration.
    static let sessionPhaseWarmUpCutoff:   Double = 0.14
    static let sessionPhaseExchangeCutoff: Double = 0.42
    static let sessionPhasePressureCutoff: Double = 0.72

    // MARK: - Scoring

    static let comboTier1: Int = 5
    static let comboTier2: Int = 15
    static let comboTier3: Int = 30
    static let comboTier4: Int = 50

    /// Map a raw combo count to the discrete tier (0...4) used by every
    /// "the player is on fire" subsystem (music stems, haptic ramps, juice
    /// multipliers). Single source of truth.
    static func comboTier(forCombo combo: Int) -> Int {
        switch combo {
        case 0..<comboTier1: return 0
        case comboTier1..<comboTier2: return 1
        case comboTier2..<comboTier3: return 2
        case comboTier3..<comboTier4: return 3
        default: return 4
        }
    }

    /// Per-tier multiplier applied to per-hit feel: shake amplitude, burst
    /// size, glow width. Tier 0 hits feel like the spec values; tier 4
    /// hits feel ~70% punchier. Audibly the SFX is also transposed up by
    /// `2 * tier` semitones (see `AudioManager.handleHit`).
    ///
    /// The multiplier is intentionally sub-linear past tier 2 so the
    /// game doesn't shake the screen off at sustained breaker-phase combos.
    static func tierJuiceMultiplier(tier: Int) -> CGFloat {
        switch max(0, min(tier, 4)) {
        case 0: return 1.00
        case 1: return 1.15
        case 2: return 1.30
        case 3: return 1.50
        default: return 1.70
        }
    }

    // MARK: - Match-flow phases (see MatchFlow.swift)
    //
    // Phase progression is driven by *whichever of clock-time or combo is
    // higher*. The clock-time thresholds keep the late session interesting
    // even when the player isn't comboing; the combo thresholds let a strong
    // player accelerate into Pressure / Breaker early.

    enum MatchFlow {
        /// 0…1 fractions of session duration at which the clock-driven phase
        /// floor escalates. A player at 0 combo who never misses still moves
        /// `warm-up → exchange → pressure → breaker` at these marks.
        static let warmUpProgress:   Double = 0.15
        static let pressureProgress: Double = 0.60
        static let breakerProgress:  Double = 0.85

        /// BPM per phase. The procedural beatmap regenerates chart chunks at
        /// these tempos so the spawn density visibly shifts.
        static let bpmWarmUp:    Double = 84
        static let bpmExchange:  Double = 110
        static let bpmPressure:  Double = 140
        static let bpmBreaker:   Double = 168

        /// How long the spawner stays in `.recovery` after a combo break.
        /// Short — just enough to clear the death-freeze + a beat or two.
        static let recoverySeconds: TimeInterval = 3.0
    }
}

extension Double {
    var seconds: TimeInterval { self / 1000.0 }
}

// MARK: - Live (runtime-mutable) feel knobs
//
// `Tunables` static-lets are the *spec*. `Tunables.live` is a small
// mirror of the feel knobs a designer actually wants to nudge at runtime
// (in the in-game DEBUG overlay), without rebuilding. The static-lets
// remain the authoritative defaults so a clean install always boots to
// the spec.
//
// Only the knobs included here are runtime-mutable. Everything else is
// still compiled in.

/// Snapshot of feel knobs that can be edited at runtime. Read-only from
/// gameplay; written only by the DEBUG tunables overlay.
///
/// IMPORTANT: All access is on the SpriteKit main thread. There is no
/// locking. If we ever expose this off-thread, switch to `OSAllocatedUnfairLock`.
struct LiveTunables {
    // Per-hit frame-stop (ms).
    var frameStopPerfectMs: Double = Tunables.frameStopPerfectMs
    var frameStopGreatMs:   Double = Tunables.frameStopGreatMs
    var frameStopDeathMs:   Double = Tunables.frameStopDeathMs

    // Camera shake amplitudes (points).
    var shakeAmplitudePerfect: CGFloat = Tunables.shakeAmplitudePerfect
    var shakeAmplitudeDeath:   CGFloat = Tunables.shakeAmplitudeDeath

    // Input.
    var swingMinDistance: CGFloat = Tunables.swingMinDistance

    // Anticipation pulse.
    var strikePulseLeadMs: Double = Tunables.strikePulseLeadMs

    // Ball pacing.
    var ballTravelSeconds: Double = Tunables.ballTravelSeconds

    // Haptic touch-down intensity is intentionally *not* exposed: the
    // `CHHapticPattern` is built once at engine warmup and would need a
    // rebuild to retake effect. Add it here if/when patterns can be
    // hot-rebuilt.
}

extension Tunables {
    /// Single mutable feel-knob bag. Migrate hot-path call sites to read
    /// from this instead of the static lets so the DEBUG overlay can
    /// retune them without a rebuild.
    static var live = LiveTunables()
}
