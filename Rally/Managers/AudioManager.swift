import AVFoundation

/// Owns the audio engine and routes `GameEvent`s to the right SFX.
///
/// ## Day-N goal vs. Day-0 reality
///
/// The GDD describes a layered-stems adaptive soundtrack
/// (`§1.2 Adaptive Audio System`). Building that requires authored stems
/// which we don't have yet. **In the meantime**, the per-hit SFX — the
/// thing that actually determines whether the game feels like Flappy Bird
/// — is provided by `ToneSynth`, a programmatic synthesizer that needs no
/// assets.
///
/// When real stems land later, plug them into `stemNodes` here and the
/// per-hit SFX pipeline doesn't change.
///
/// ## Hot-path discipline
///
/// - `AVAudioEngine` is started once at process launch and stays running.
/// - The synth is wired before the engine starts so the audio I/O thread
///   sees a stable graph.
/// - All `play(_:)` calls happen on the main thread and return in <1 µs.
final class AudioManager {
    static let shared = AudioManager()

    var isEnabled: Bool = true {
        didSet { mixer.outputVolume = isEnabled ? 1.0 : 0.0 }
    }

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let synth = ToneSynth()

    private init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        engine.attach(synth.sourceNode)
        engine.connect(synth.sourceNode, to: mixer, format: synth.outputFormat)

        configureSession()
        startEngine()

        GameEventBus.shared.subscribe(self) { [weak self] event in
            self?.handle(event)
        }
    }

    /// Called from `RallyApp.init` to force first-touch latency to zero.
    func prewarm() {
        // Play a silent voice through the synth pipeline so the audio I/O
        // graph is fully spun up before the first real hit.
        let primer = ToneSynth.Patch(
            freqStartHz: 880, freqEndHz: 880,
            durationMs: 30, waveform: .sine,
            noiseMix: 0, peak: 0.0001,
            attackMs: 1, releaseMs: 1
        )
        synth.play(primer)
    }

    // MARK: - Session lifecycle

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Audio failures must never crash gameplay.
        }
    }

    private func startEngine() {
        do {
            try engine.start()
        } catch {
            // Try once more after a session reset before giving up.
            try? AVAudioSession.sharedInstance().setActive(true)
            try? engine.start()
        }
    }

    // MARK: - Event routing

    private func handle(_ event: GameEvent) {
        guard isEnabled, engine.isRunning else { return }
        switch event {
        case .hit(let quality, _, _, _):
            handleHit(quality: quality)
        case .miss:
            synth.play(ToneSynth.patchWing)
        case .comboTier(let tier) where tier > 0:
            synth.play(ToneSynth.patchTier(tier))
        case .comboBreak:
            synth.play(ToneSynth.patchDie)
        case .sessionStart, .sessionEnd, .comboTier, .cosmeticEquipped:
            break
        }
    }

    private func handleHit(quality: HitQuality) {
        switch quality {
        case .perfect:
            // Two voices for that Flappy chunky-thump feel: a low bonk plus
            // a high chime, fired simultaneously.
            synth.play(ToneSynth.patchHit)
            synth.play(ToneSynth.patchPoint)
        case .great:
            synth.play(ToneSynth.patchPoint)
        case .good:
            var soft = ToneSynth.patchPoint
            soft.peak *= 0.6
            soft.freqStartHz *= 0.8
            soft.freqEndHz *= 0.8
            synth.play(soft)
        case .miss:
            break
        }
    }
}
