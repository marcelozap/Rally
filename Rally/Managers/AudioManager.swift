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

    private(set) var isEnabled: Bool = false
    /// True between `.sessionStart` and `.sessionEnd` — used to resume the
    /// music bed when the player unmutes mid-run.
    private var isSessionActive = false

    /// Toggle the music bed without touching SFX. Reads/writes the music
    /// mixer's `outputVolume`.
    var isMusicEnabled: Bool = true {
        didSet { refreshOutputVolumes() }
    }

    /// Applies the persisted master mute — stops music when disabled.
    func applySoundEnabled(_ enabled: Bool) {
        isEnabled = enabled
        refreshOutputVolumes()
        if enabled {
            if isSessionActive {
                musicEngine.start()
            }
        } else {
            musicEngine.stop()
        }
    }

    private func refreshOutputVolumes() {
        mixer.outputVolume = isEnabled ? 1.0 : 0.0
        musicMixer.outputVolume = (isEnabled && isMusicEnabled) ? Constants.musicMixLevel : 0.0
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

        if UserDefaults.standard.object(forKey: UserDefaultsKeys.soundEnabled) == nil {
            isEnabled = false
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.soundEnabled)
        }
        refreshOutputVolumes()

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
        #if DEBUG
        logAudioLatencyProbe()
        #endif
    }

    #if DEBUG
    /// Print the device's reported audio latency once at launch. The
    /// total perceived per-tap latency includes the host buffer
    /// (`ioBufferDuration`) plus the output device's transport delay
    /// (`outputLatency`); aim for the sum to be under ~12 ms on iPhone.
    /// Bluetooth audio routes will report a much larger output latency
    /// — that's expected, and gameplay should never assume tighter.
    private func logAudioLatencyProbe() {
        let session = AVAudioSession.sharedInstance()
        let out = session.outputLatency * 1000
        let buf = session.ioBufferDuration * 1000
        let rate = session.sampleRate
        let routes = session.currentRoute.outputs.map(\.portType.rawValue).joined(separator: ",")
        print(String(
            format: "[Rally] audio probe: outputLatency=%.2fms ioBuffer=%.2fms sampleRate=%.0fHz route=%@",
            out, buf, rate, routes.isEmpty ? "?" : routes
        ))
    }
    #endif

    // MARK: - Event routing

    private func handle(_ event: GameEvent) {
        guard isEnabled, engine.isRunning else { return }
        switch event {
        case .hit(let quality, _, _, let combo):
            handleHit(quality: quality, combo: combo)
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
            isSessionActive = true
            musicEngine.targetTier = 0
            musicEngine.phaseFloor = 0
            if isEnabled {
                musicEngine.start()
            }
        case .sessionEnd:
            isSessionActive = false
            musicEngine.stop()
        case .phaseChanged(_, let to):
            // Phase floor guarantees a minimum stem richness so the bed
            // visibly *fills in* with match-flow even if the player isn't
            // currently in a high combo tier.
            musicEngine.phaseFloor = phaseFloor(for: to)
        case .cosmeticEquipped:
            break
        }
    }

    private func phaseFloor(for phase: MatchFlowPhase) -> Int {
        switch phase {
        case .warmUp, .exchange, .recovery: return 0
        case .pressure:                     return 1
        case .breaker:                      return 2
        }
    }

    private func handleHit(quality: HitQuality, combo: Int) {
        // Transpose the per-hit chime up by 2 semitones per combo tier so
        // sustained streaks audibly *ascend*. The thump (`patchHit`) is
        // left at base pitch — its character is the body of the impact;
        // transposing it just makes it tinny.
        //
        // semitones = 2 * tier  →  ratio = 2^(semitones / 12) = 2^(tier/6)
        let tier = Tunables.comboTier(forCombo: combo)
        let chimeRatio = pow(2.0, Double(tier) / 6.0)

        var chime = ToneSynth.patchPoint
        chime.freqStartHz *= chimeRatio
        chime.freqEndHz   *= chimeRatio

        switch quality {
        case .perfect:
            // Two voices for that Flappy chunky-thump feel: a low bonk plus
            // a high chime, fired simultaneously.
            sfxSynth.play(ToneSynth.patchHit)
            sfxSynth.play(chime)
        case .great:
            sfxSynth.play(chime)
        case .good:
            chime.peak *= 0.6
            chime.freqStartHz *= 0.8
            chime.freqEndHz   *= 0.8
            sfxSynth.play(chime)
        case .miss:
            break
        }
    }
}
