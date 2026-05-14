import AVFoundation

/// Owns the audio engine and routes `GameEvent`s to SFX + adaptive music.
///
/// ## Layout
///
/// Two parallel `ToneSynth` instances feed a single mixer node:
///
/// ```
///   sfxSynth   ─┐
///               ├─► mixer ─► engine.mainMixer ─► hardware
///   musicSynth ─┘
/// ```
///
/// Splitting prevents music notes from stealing SFX voices (each synth has
/// its own fixed pool). The music synth is driven by `MusicEngine`, which
/// fires per-stem notes on a 16th-note grid.
///
/// ## Hot-path discipline
///
/// - Engine started once, kept running for the app lifetime.
/// - All `play(_:)` calls are <1 µs and never allocate.
/// - Music tier is set _on_ the bus thread; gate fades happen on the music
///   timer thread inside `MusicEngine`.
final class AudioManager {
    static let shared = AudioManager()

    var isEnabled: Bool = true {
        didSet { mixer.outputVolume = isEnabled ? 1.0 : 0.0 }
    }

    /// Toggle the music bed without touching SFX. Reads/writes the music
    /// mixer's `outputVolume`.
    var isMusicEnabled: Bool = true {
        didSet { musicMixer.outputVolume = isMusicEnabled ? Constants.musicMixLevel : 0.0 }
    }

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let musicMixer = AVAudioMixerNode()
    private let sfxSynth = ToneSynth()
    private let musicSynth = ToneSynth()
    private let musicEngine: MusicEngine

    private enum Constants {
        /// Music sits a bit under SFX so hits cut through the bed.
        static let musicMixLevel: Float = 0.7
    }

    private init() {
        self.musicEngine = MusicEngine(synth: musicSynth)

        engine.attach(mixer)
        engine.attach(musicMixer)
        musicMixer.outputVolume = Constants.musicMixLevel

        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: nil)

        engine.attach(sfxSynth.sourceNode)
        engine.connect(sfxSynth.sourceNode, to: mixer, format: sfxSynth.outputFormat)

        engine.attach(musicSynth.sourceNode)
        engine.connect(musicSynth.sourceNode, to: musicMixer, format: musicSynth.outputFormat)

        configureSession()
        startEngine()

        GameEventBus.shared.subscribe(self) { [weak self] event in
            self?.handle(event)
        }
    }

    /// Called from `RallyApp.init` to force first-touch latency to zero.
    func prewarm() {
        let primer = ToneSynth.Patch(
            freqStartHz: 880, freqEndHz: 880,
            durationMs: 30, waveform: .sine,
            noiseMix: 0, peak: 0.0001,
            attackMs: 1, releaseMs: 1
        )
        sfxSynth.play(primer)
        musicSynth.play(primer)
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
            sfxSynth.play(ToneSynth.patchWing)
        case .comboTier(let tier):
            if tier > 0 { sfxSynth.play(ToneSynth.patchTier(tier)) }
            musicEngine.targetTier = tier
        case .comboBreak:
            sfxSynth.play(ToneSynth.patchDie)
            musicEngine.targetTier = 0
            musicEngine.duckAfterComboBreak()
        case .sessionStart:
            musicEngine.targetTier = 0
            musicEngine.start()
        case .sessionEnd:
            musicEngine.stop()
        case .cosmeticEquipped:
            break
        }
    }

    private func handleHit(quality: HitQuality) {
        switch quality {
        case .perfect:
            // Two voices for that Flappy chunky-thump feel: a low bonk plus
            // a high chime, fired simultaneously.
            sfxSynth.play(ToneSynth.patchHit)
            sfxSynth.play(ToneSynth.patchPoint)
        case .great:
            sfxSynth.play(ToneSynth.patchPoint)
        case .good:
            var soft = ToneSynth.patchPoint
            soft.peak *= 0.6
            soft.freqStartHz *= 0.8
            soft.freqEndHz *= 0.8
            sfxSynth.play(soft)
        case .miss:
            break
        }
    }
}
