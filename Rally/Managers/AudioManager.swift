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
    private static var sharedInstance: AudioManager?

    static var shared: AudioManager {
        if let sharedInstance {
            return sharedInstance
        }
        let manager = AudioManager()
        sharedInstance = manager
        return manager
    }

    /// Applies a persisted mute value without forcing AVAudioEngine creation
    /// while sound is off. This keeps launch/test runs silent and avoids
    /// waking the audio stack until the player explicitly opts in.
    static func applySoundEnabledIfLoaded(_ enabled: Bool) {
        guard enabled || sharedInstance != nil else { return }
        shared.applySoundEnabled(enabled)
    }

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
        if enabled {
            ensureEngineRunning()
        }
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

    private func ensureEngineRunning() {
        guard !engine.isRunning else { return }
        configureSession()
        startEngine()
    }

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let musicMixer = AVAudioMixerNode()
    private let sfxSynth = ToneSynth()
    private let musicSynth = ToneSynth()
    private let musicEngine: MusicEngine

    private enum Constants {
        /// Music sits a bit under SFX so hits cut through the bed.
        static let musicMixLevel: Float = 0.82
    }

    private init() {
        self.musicEngine = MusicEngine(synth: musicSynth)

        engine.attach(mixer)
        engine.attach(musicMixer)

        isEnabled = RallyDefaults.resolvedSoundEnabled()
        refreshOutputVolumes()

        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: nil)

        engine.attach(sfxSynth.sourceNode)
        engine.connect(sfxSynth.sourceNode, to: mixer, format: sfxSynth.outputFormat)

        engine.attach(musicSynth.sourceNode)
        engine.connect(musicSynth.sourceNode, to: musicMixer, format: musicSynth.outputFormat)

        if isEnabled {
            ensureEngineRunning()
        }

        GameEventBus.shared.subscribe(self) { [weak self] event in
            self?.handle(event)
        }
    }

    /// Called from `RallyApp.init` to force first-touch latency to zero.
    func prewarm() {
        guard isEnabled else { return }
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
            // Rally should still speak when the phone is in silent mode; this
            // is a game, not a passive ambient app.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
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
        case .hit(let quality, _, _, let combo, let power):
            handleHit(quality: quality, combo: combo, power: power)
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

    private func handleHit(quality: HitQuality, combo: Int, power: CGFloat) {
        guard let contact = Self.contactSound(for: quality, combo: combo, power: power) else { return }
        // Both layers dispatch with the contact event. A brief string snap
        // sits over the ball's softer body; no delayed score chime is added.
        sfxSynth.play(contact.body)
        sfxSynth.play(contact.strings)
    }

    struct ContactSound {
        let body: ToneSynth.Patch
        let strings: ToneSynth.Patch
    }

    /// Pure recipes keep contact short, give each grade a distinct attack,
    /// and leave mixer headroom even at the strongest permitted swing.
    /// Inspectable without creating an AVAudioEngine or enabling sound.
    static func contactSound(for quality: HitQuality, combo: Int, power: CGFloat) -> ContactSound? {
        guard quality != .miss else { return nil }
        let safePower = power.isFinite ? Double(max(0.25, min(1.45, power))) : 1
        let gain = Float(0.82 + safePower * 0.18)
        let pitch = 0.94 + safePower * 0.075
        let tier = Tunables.comboTier(forCombo: max(0, combo))
        // Streaks gently brighten the string attack without turning each
        // contact into the previous rising arcade note.
        let stringPitch = pitch * (1 + Double(tier) * 0.012)
        let body: ToneSynth.Patch
        let strings: ToneSynth.Patch
        switch quality {
        case .perfect:
            body = .init(freqStartHz: 370 * pitch, freqEndHz: 165 * pitch,
                         durationMs: 74, waveform: .triangle, noiseMix: 0.25,
                         peak: 0.40 * gain, attackMs: 1, releaseMs: 71)
            strings = .init(freqStartHz: 950 * stringPitch, freqEndHz: 540 * stringPitch,
                            durationMs: 24, waveform: .sine, noiseMix: 0.82,
                            peak: 0.11 * gain, attackMs: 0.5, releaseMs: 23)
        case .great:
            body = .init(freqStartHz: 310 * pitch, freqEndHz: 145 * pitch,
                         durationMs: 86, waveform: .triangle, noiseMix: 0.20,
                         peak: 0.34 * gain, attackMs: 2, releaseMs: 82)
            strings = .init(freqStartHz: 740 * stringPitch, freqEndHz: 370 * stringPitch,
                            durationMs: 21, waveform: .sine, noiseMix: 0.66,
                            peak: 0.075 * gain, attackMs: 1, releaseMs: 19)
        case .good:
            body = .init(freqStartHz: 230 * pitch, freqEndHz: 110 * pitch,
                         durationMs: 102, waveform: .sine, noiseMix: 0.14,
                         peak: 0.25 * gain, attackMs: 3, releaseMs: 96)
            strings = .init(freqStartHz: 550 * stringPitch, freqEndHz: 260 * stringPitch,
                            durationMs: 18, waveform: .sine, noiseMix: 0.45,
                            peak: 0.035 * gain, attackMs: 2, releaseMs: 15)
        case .miss:
            return nil
        }
        return ContactSound(body: body, strings: strings)
    }
}
