import AVFoundation

/// Owns the `AVAudioEngine` and the layered stem mixer. See `GDD.md §1.2`.
///
/// The hot path here is intentionally allocation-free:
///   - All stem buffers are loaded once at session start.
///   - All player nodes are attached / wired exactly once.
///   - Tier transitions only adjust target volumes; the per-frame `tick(_:)`
///     ramps current volume toward the target.
final class AudioManager {
    static let shared = AudioManager()

    var isEnabled: Bool = true {
        didSet { mixer.outputVolume = isEnabled ? 1.0 : 0.0 }
    }

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()

    /// One player node per stem. Index lines up with `StemTier`.
    private var stemNodes: [AVAudioPlayerNode] = []
    private var stemBuffers: [AVAudioPCMBuffer] = []
    private var stemTargetVolumes: [Float] = []
    private var stemCurrentVolumes: [Float] = []

    /// Pool of stinger nodes used for hit cues. Round-robin to avoid
    /// re-allocating per hit.
    private var stingerPool: [AVAudioPlayerNode] = []
    private var stingerCursor: Int = 0

    /// Per-hit-quality stinger buffer cache.
    private var stingerBuffers: [HitQuality: AVAudioPCMBuffer] = [:]

    private init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        GameEventBus.shared.subscribe(self) { [weak self] event in
            self?.handle(event)
        }

        configureSession()
        // Real stems get loaded on `.sessionStart`; this just gets the engine
        // running so the first hit isn't cold.
        try? engine.start()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Audio failures should never crash gameplay.
        }
    }

    // MARK: Event routing

    private func handle(_ event: GameEvent) {
        guard isEnabled else { return }
        switch event {
        case .sessionStart:
            prepareDefaultTrack()
        case .sessionEnd:
            stopAllStems()
        case .hit(let quality, _, _, _):
            playStinger(quality: quality)
        case .comboTier(let tier):
            setActiveTier(tier)
        case .comboBreak:
            setActiveTier(0)
        default:
            break
        }
    }

    // MARK: Stems

    /// Stub: load a built-in track. Once real assets ship, replace this with
    /// a `loadTrack(_ trackID: String)` that reads from `Resources/Tracks/`.
    private func prepareDefaultTrack() {
        // No assets yet — just wire the topology so the indexing works.
        // Add ≤5 stems matching the GDD's tier table.
        let stemCount = 5
        guard stemNodes.isEmpty else { return }

        for _ in 0..<stemCount {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: mixer, format: nil)
            stemNodes.append(node)
        }
        stemTargetVolumes = Array(repeating: 0, count: stemCount)
        stemCurrentVolumes = Array(repeating: 0, count: stemCount)
        // Tier 0 (drums) is always on once a buffer is loaded.
        stemTargetVolumes[0] = 1.0

        // Stinger pool.
        for _ in 0..<8 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: mixer, format: nil)
            stingerPool.append(node)
        }
    }

    private func stopAllStems() {
        for node in stemNodes { node.stop() }
        stemCurrentVolumes = stemCurrentVolumes.map { _ in 0 }
        stemTargetVolumes = stemTargetVolumes.map { _ in 0 }
    }

    /// Activate stems `[0...tier]` and silence the rest. Volumes ramp via
    /// `tick(_:)`.
    private func setActiveTier(_ tier: Int) {
        for i in stemTargetVolumes.indices {
            stemTargetVolumes[i] = i <= tier ? 1.0 : 0.0
        }
    }

    /// Drive this from `GameScene.update(_:)` (or a CADisplayLink) once the
    /// audio assets are real. For now it's wired but a no-op (volumes stay
    /// at their targets since there are no buffers).
    func tick(deltaSeconds: Float) {
        let rampRate: Float = 1.0 / 0.25 // 250 ms to reach target
        for i in stemTargetVolumes.indices {
            let target = stemTargetVolumes[i]
            let current = stemCurrentVolumes[i]
            let step = rampRate * deltaSeconds
            let next: Float
            if abs(target - current) <= step {
                next = target
            } else {
                next = current + (target > current ? step : -step)
            }
            stemCurrentVolumes[i] = next
            stemNodes[i].volume = next
        }
    }

    // MARK: Stingers

    private func playStinger(quality: HitQuality) {
        guard let buffer = stingerBuffers[quality] else {
            // No buffer authored yet for this grade — silently skip.
            return
        }
        let node = stingerPool[stingerCursor]
        stingerCursor = (stingerCursor + 1) % stingerPool.count

        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        node.play()
    }
}
