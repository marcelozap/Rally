import Foundation
import os

/// Procedural, asset-free, combo-reactive soundtrack.
///
/// ## Why this exists
///
/// The GDD calls for an Adaptive Audio System: layered stems that intensify
/// with the combo tier. Authored stems would be the obvious choice, but they
/// require licensed music + a bunch of `AVAudioPlayerNode` plumbing.
/// `MusicEngine` instead drives a procedural composition through the same
/// `ToneSynth` we use for SFX. Zero assets, zero licensing, full reactivity.
///
/// ## Composition
///
/// Track is in **A minor**, **104 BPM**, four-on-the-floor. Resolution is a
/// 16th-note grid; each call to `tick()` advances the grid by one slot.
///
/// Stems unlock progressively as the combo tier climbs:
///
/// | Tier | Adds                                              |
/// |------|---------------------------------------------------|
/// | 0    | kick (1+3) + hat (every 8th)                      |
/// | 1    | bass (root motion on every beat)                  |
/// | 2    | arpeggio (16th-note minor triad)                  |
/// | 3    | lead melodic phrase (1-bar pattern)               |
/// | 4    | pad chord stack (every 2 bars, low + sustained)   |
///
/// Each stem fades in over `Constants.tierFadeMs` so the texture grows
/// organically rather than popping in.
///
/// ## Threading
///
/// Timer fires on a dedicated high-priority `DispatchQueue`. All synth
/// activations are `@Sendable` from that thread because `ToneSynth.play`
/// only touches a `OSAllocatedUnfairLock`-protected pool. The render thread
/// is not involved at scheduling time.
final class MusicEngine {

    // MARK: - Public surface

    /// Set by `AudioManager` from the combo-tier event. Clamped to 0…4.
    /// The *effective* tier driving stem gates is
    /// `max(targetTier, phaseFloor)` — so a `.breaker` phase keeps the bass
    /// + arp alive even when the player's combo dropped back to zero.
    var targetTier: Int {
        get { _targetTier.withLockUnchecked { $0 } }
        set { _targetTier.withLockUnchecked { $0 = max(0, min(4, newValue)) } }
    }

    /// Match-flow floor. Driven by `.phaseChanged` events. 0 in warm-up /
    /// exchange / recovery, escalates to 1 in pressure and 2 in breaker so
    /// the texture *fills in* visibly even on a stoic player.
    var phaseFloor: Int {
        get { _phaseFloor.withLockUnchecked { $0 } }
        set { _phaseFloor.withLockUnchecked { $0 = max(0, min(4, newValue)) } }
    }

    /// 0…1 fade gates per stem. Smooth so re-entry after a combo break
    /// doesn't sound like a cymbal crash.
    private struct StemGates: Sendable {
        var kick: Float = 1.0
        var hat:  Float = 1.0
        var bass: Float = 0.0
        var arp:  Float = 0.0
        var lead: Float = 0.0
        var pad:  Float = 0.0
    }

    private(set) var isPlaying: Bool = false

    init(synth: ToneSynth) {
        self.synth = synth
    }

    // MARK: - Lifecycle

    func start() {
        guard !isPlaying else { return }
        isPlaying = true
        sixteenthCount = 0

        // Reset gates so each run opens with just drums.
        _gates.withLockUnchecked { gates in
            gates = StemGates()
            gates.kick = 1.0
            gates.hat  = 1.0
        }

        let interval = 60.0 / Constants.bpm / 4.0
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + 0.05, repeating: interval, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        beatTimer = timer
    }

    func stop() {
        beatTimer?.cancel()
        beatTimer = nil
        isPlaying = false
    }

    /// Drives a clean ducking when a combo breaks: bass + arp + lead + pad
    /// drop instantly, drums remain. They'll fade back in once the player
    /// rebuilds combo.
    func duckAfterComboBreak() {
        _gates.withLockUnchecked { gates in
            gates.bass = 0
            gates.arp  = 0
            gates.lead = 0
            gates.pad  = 0
        }
    }

    // MARK: - Internals

    private let synth: ToneSynth
    private let timerQueue = DispatchQueue(
        label: "com.marcelozap.rally.music",
        qos: .userInteractive
    )
    private var beatTimer: DispatchSourceTimer?
    private var sixteenthCount: Int = 0

    private let _gates = OSAllocatedUnfairLock(initialState: StemGates())
    private let _targetTier = OSAllocatedUnfairLock(initialState: 0)
    private let _phaseFloor = OSAllocatedUnfairLock(initialState: 0)

    private enum Constants {
        static let bpm: Double = 104
        /// Per-tick fade speed (linear). At 16th-note intervals of ~136 ms,
        /// a `0.0625` step crossfades a stem fully in/out in ~16 ticks, i.e.
        /// roughly 4 beats — squarely inside the 2-6 beat brief and slow
        /// enough that re-entry after a combo break never pops.
        static let tierFadeStep: Float = 0.0625
    }

    // MARK: - Sequencer step

    private func tick() {
        advanceGates()
        let pos16 = sixteenthCount
        let posInBar = pos16 % 16
        let posInTwoBars = pos16 % 32

        let gates = _gates.withLockUnchecked { $0 }

        // --- Drums (always on once started) ---
        if posInBar % 8 == 0 {
            fireKick(velocity: gates.kick)
        }
        if posInBar % 2 == 0 {
            // Off-beats breathe harder than downbeats so the bed feels like
            // motion, not a metronome.
            let accent = (posInBar == 2 || posInBar == 6 || posInBar == 10 || posInBar == 14) ? 1.34 : 0.92
            fireHat(velocity: gates.hat * Float(accent))
        }

        // --- Bass (T1) ---
        if gates.bass > 0.01, posInBar % 4 == 0 {
            fireBass(step: (posInBar / 4) % bassPattern.count, velocity: gates.bass)
        }

        // --- Arp (T2): 8th-note arpeggio ---
        if gates.arp > 0.01, posInBar % 2 == 0 {
            fireArp(step: (posInBar / 2) % arpPattern.count, velocity: gates.arp)
        }

        // --- Lead (T3): a 1-bar melodic phrase ---
        if gates.lead > 0.01 {
            if let note = leadPattern[posInBar] {
                fireLead(freqHz: note, velocity: gates.lead)
            }
        }

        // --- Pad (T4): every 2 bars, sustained chord ---
        if gates.pad > 0.01, posInTwoBars == 0 {
            firePad(velocity: gates.pad)
        }

        sixteenthCount &+= 1
    }

    /// Fades each stem's gate toward 1.0 if that stem is enabled by the
    /// current effective tier, otherwise toward 0.0. The fades are linear
    /// and take ~4 beats to fully open or close (see `tierFadeStep`).
    /// Drums (kick + hat) are intentionally outside this loop — the pulse
    /// never dies, even on a combo break.
    private func advanceGates() {
        let combo = _targetTier.withLockUnchecked { $0 }
        let floor = _phaseFloor.withLockUnchecked { $0 }
        let tier  = max(combo, floor)
        _gates.withLockUnchecked { gates in
            gates.bass = step(gates.bass, towards: tier >= 1 ? 1.0 : 0.0)
            gates.arp  = step(gates.arp,  towards: tier >= 2 ? 1.0 : 0.0)
            gates.lead = step(gates.lead, towards: tier >= 3 ? 1.0 : 0.0)
            gates.pad  = step(gates.pad,  towards: tier >= 4 ? 1.0 : 0.0)
        }
    }

    @inline(__always)
    private func step(_ v: Float, towards target: Float) -> Float {
        if v < target { return min(target, v + Constants.tierFadeStep) }
        if v > target { return max(target, v - Constants.tierFadeStep) }
        return v
    }

    // MARK: - Stem voicings (A minor: A=55Hz, C=65.4, D=73.4, E=82.4, F=87.3, G=98.0)

    /// Root motion: A → A → C → E. A simple, hooky bass line that fits the
    /// neon-cyberpunk aesthetic without sounding like a video-game cliché.
    private let bassPattern: [Double] = [55.0, 55.0, 49.0, 65.4]

    /// 8th-note minor-7 arpeggio: A4 C5 E5 G5 E5 C5 E5 G5
    private let arpPattern: [Double] = [
        164.8, 220.0, 261.6, 329.6,
        261.6, 220.0, 261.6, 349.2
    ]

    /// 16th-note slots → optional lead note. Hooky melodic phrase that
    /// resolves down to A4. Nil slots mean rest.
    /// Positions are 0…15 (one bar).
    private let leadPattern: [Int: Double] = [
        2:  523.3,  // C5
        5:  587.3,  // D5
        8:  659.3,  // E5
        11: 587.3,  // D5
        14: 440.0   // A4
    ]

    // MARK: - Stem firing (all routed through ToneSynth on the music synth)

    private func fireKick(velocity: Float) {
        synth.play(ToneSynth.Patch(
            freqStartHz: 96, freqEndHz: 42,
            durationMs: 170,
            waveform: .triangle,
            noiseMix: 0.18,
            peak: 0.62 * velocity,
            attackMs: 1,
            releaseMs: 124
        ))
    }

    private func fireHat(velocity: Float) {
        synth.play(ToneSynth.Patch(
            freqStartHz: 7600, freqEndHz: 6200,
            durationMs: 52,
            waveform: .sine,
            noiseMix: 0.92,
            peak: 0.11 * velocity,
            attackMs: 1,
            releaseMs: 42
        ))
    }

    private func fireBass(step idx: Int, velocity: Float) {
        let f = bassPattern[idx]
        synth.play(ToneSynth.Patch(
            freqStartHz: f, freqEndHz: f,
            durationMs: 420,
            waveform: .triangle,
            noiseMix: 0.03,
            peak: 0.54 * velocity,
            attackMs: 6,
            releaseMs: 220
        ))
    }

    private func fireArp(step idx: Int, velocity: Float) {
        let f = arpPattern[idx]
        synth.play(ToneSynth.Patch(
            freqStartHz: f, freqEndHz: f,
            durationMs: 168,
            waveform: .triangle,
            noiseMix: 0,
            peak: 0.18 * velocity,
            attackMs: 8,
            releaseMs: 112
        ))
    }

    private func fireLead(freqHz: Double, velocity: Float) {
        synth.play(ToneSynth.Patch(
            freqStartHz: freqHz, freqEndHz: freqHz,
            durationMs: 520,
            waveform: .triangle,
            noiseMix: 0,
            peak: 0.16 * velocity,
            attackMs: 18,
            releaseMs: 280
        ))
    }

    private func firePad(velocity: Float) {
        // Four-voice suspended minor stack: A2, C3, E3, G3.
        for f in [110.0, 130.8, 164.8, 196.0] {
            synth.play(ToneSynth.Patch(
                freqStartHz: f, freqEndHz: f,
                durationMs: 2200,
                waveform: .triangle,
                noiseMix: 0,
                peak: 0.13 * velocity,
                attackMs: 280,
                releaseMs: 760
            ))
        }
    }
}
