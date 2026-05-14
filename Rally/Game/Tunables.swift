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
    // 1. Per-hit "weight" pause — short (sub-frame at 60 Hz for great, ~1.5
    //    frames for perfect). Just enough to make a perfect hit feel like a
    //    proper impact, but not so long it interrupts a 16th-note run.
    //
    // 2. Death pause — the iconic Flappy freeze. Long, deliberate, the
    //    "oh no" moment. Coincides with the red flash, screen shake, and
    //    descending death tone.

    static let frameStopPerfectMs: Double = 24
    static let frameStopGreatMs:   Double = 12
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

    // MARK: - Haptic intensity (0...1)

    static let hapticPerfect: Float = 1.0
    static let hapticGreat:   Float = 0.7
    static let hapticGood:    Float = 0.4
    static let hapticMiss:    Float = 0.3
    static let hapticDeath:   Float = 1.0

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

    // MARK: - Scoring

    static let comboTier1: Int = 5
    static let comboTier2: Int = 15
    static let comboTier3: Int = 30
    static let comboTier4: Int = 50
}

extension Double {
    var seconds: TimeInterval { self / 1000.0 }
}
