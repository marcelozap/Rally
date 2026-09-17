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
/// 1. Start the engine eagerly in `init` when vibration is enabled.
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

    var isEnabled: Bool = true {
        didSet {
            guard oldValue != isEnabled else { return }
            if isEnabled {
                if supportsHaptics {
                    if engine == nil { startEngine() }
                    else { try? engine?.start() }
                    buildPatternCache()
                }
            } else {
                // Turning vibration off also cancels a pattern already in flight.
                hitPlayers.values.forEach { try? $0.stop(atTime: 0) }
                [missPlayer, breakPlayer, touchDownPlayer, primerPlayer].forEach { try? $0?.stop(atTime: 0) }
                tierPlayers.values.forEach { try? $0.stop(atTime: 0) }
            }
        }
    }

    private let supportsHaptics: Bool
    private var engine: CHHapticEngine?

    private var hitPlayers: [HitQuality: CHHapticPatternPlayer] = [:]
    private var missPlayer: CHHapticPatternPlayer?
    private var breakPlayer: CHHapticPatternPlayer?
    private var tierPlayers: [Int: CHHapticPatternPlayer] = [:]
    private var touchDownPlayer: CHHapticPatternPlayer?
    private var primerPlayer: CHHapticPatternPlayer?

    /// Throttle for `playTouchDown()` — a single swing should fire one
    /// touch-down haptic even if `.began` is delivered twice in the same
    /// vsync (rare, but cheap insurance).
    private var lastTouchDownAt: TimeInterval = 0
    private let minTouchDownGapSeconds: TimeInterval = 0.040

    /// Last-play timestamps per quality. Used to suppress duplicate plays
    /// inside the same vsync (~16ms) or whenever the spawner pumps two hits
    /// in very fast succession — without this the device buzzes into mush
    /// during a streak through the breaker phase.
    private var lastPlayAt: [HitQuality: TimeInterval] = [:]
    private let minRepeatGapSeconds: TimeInterval = 0.022

    private let lightFallback  = UIImpactFeedbackGenerator(style: .light)
    private let mediumFallback = UIImpactFeedbackGenerator(style: .medium)

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: UserDefaultsKeys.gameHapticsEnabled) == nil
            || defaults.bool(forKey: UserDefaultsKeys.gameHapticsEnabled)

        if supportsHaptics && isEnabled {
            startEngine()
            buildPatternCache()
        } else {
            [lightFallback, mediumFallback].forEach { $0.prepare() }
        }

        GameEventBus.shared.subscribe(self) { [weak self] event in
            self?.handle(event)
        }
    }

    /// Force the first dispatch through the engine so a real hit isn't the
    /// first one. Safe to call multiple times.
    func prewarm() {
        guard isEnabled else { return }
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
                DispatchQueue.main.async {
                    guard let self, self.isEnabled else { return }
                    self.startEngine()
                    self.buildPatternCache()
                }
            }
            engine.resetHandler = { [weak self] in
                DispatchQueue.main.async {
                    guard let self, self.isEnabled else { return }
                    try? self.engine?.start()
                    self.buildPatternCache()
                }
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

        if let pattern = makeTouchDownPattern(),
           let player = try? engine.makePlayer(with: pattern) {
            touchDownPlayer = player
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
        case .hit(let quality, _, _, _, _):
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
        // Throttle: never fire the same-quality pattern more often than
        // `minRepeatGapSeconds`. Prevents back-to-back perfects from melting
        // into one indistinct rumble at high hit rates.
        let now = CACurrentMediaTime()
        if let last = lastPlayAt[quality], now - last < minRepeatGapSeconds {
            return
        }
        lastPlayAt[quality] = now

        guard supportsHaptics, let player = hitPlayers[quality] else {
            guard let contact = Self.contactHaptics(for: quality) else { return }
            let fallback = quality == .perfect ? mediumFallback : lightFallback
            fallback.impactOccurred(intensity: CGFloat(contact.impactIntensity))
            return
        }
        try? player.start(atTime: 0)
    }

    private func playMiss() {
        guard supportsHaptics, let player = missPlayer else {
            lightFallback.impactOccurred(intensity: 0.14)
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
            mediumFallback.impactOccurred(intensity: 0.30)
            return
        }
        try? player.start(atTime: 0)
    }

    /// Public: fired by `GameScene` on swing touch-down (`UIPanGestureRecognizer.State.began`).
    ///
    /// Intentionally not routed through `GameEventBus` — touch-down is an
    /// input event, not a game event, and we don't want every manager to
    /// have to filter it out.
    func playTouchDown() {
        guard isEnabled else { return }
        let now = CACurrentMediaTime()
        if now - lastTouchDownAt < minTouchDownGapSeconds { return }
        lastTouchDownAt = now

        guard supportsHaptics, let player = touchDownPlayer else {
            lightFallback.impactOccurred(intensity: CGFloat(Tunables.hapticTouchDown * 0.4))
            return
        }
        try? player.start(atTime: 0)
    }

    // MARK: - Pattern definitions

    struct ContactHaptics {
        let impactIntensity: Float
        let sharpness: Float
        let bodyIntensity: Float
        let bodyDuration: TimeInterval
        let echoIntensity: Float
    }

    /// A clean contact has a crisp front edge and a very light echo; a safe
    /// contact is a softer single tap. These are design targets, not a claim
    /// of device calibration. All three need a physical-phone feel check.
    static func contactHaptics(for quality: HitQuality) -> ContactHaptics? {
        switch quality {
        case .perfect:
            return .init(impactIntensity: 0.46, sharpness: 0.70,
                         bodyIntensity: 0.10, bodyDuration: 0.027, echoIntensity: 0.12)
        case .great:
            return .init(impactIntensity: 0.34, sharpness: 0.50,
                         bodyIntensity: 0.095, bodyDuration: 0.026, echoIntensity: 0)
        case .good:
            return .init(impactIntensity: 0.20, sharpness: 0.20,
                         bodyIntensity: 0.08, bodyDuration: 0.030, echoIntensity: 0)
        case .miss:
            return nil
        }
    }

    private func makeHitPattern(quality: HitQuality) -> CHHapticPattern? {
        guard let contact = Self.contactHaptics(for: quality) else { return nil }
        var events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: contact.impactIntensity),
                .init(parameterID: .hapticSharpness, value: contact.sharpness)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                .init(parameterID: .hapticIntensity, value: contact.bodyIntensity),
                .init(parameterID: .hapticSharpness, value: contact.sharpness * 0.5)
            ], relativeTime: 0.002, duration: contact.bodyDuration)
        ]
        if contact.echoIntensity > 0 {
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: contact.echoIntensity),
                .init(parameterID: .hapticSharpness, value: contact.sharpness * 0.8)
            ], relativeTime: 0.018))
        }
        return try? CHHapticPattern(events: events, parameters: [])
    }

    private func makeMissPattern() -> CHHapticPattern? {
        let dull = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: Tunables.hapticMiss * 0.47),
                .init(parameterID: .hapticSharpness, value: 0.05)
            ],
            relativeTime: 0,
            duration: 0.045
        )
        return try? CHHapticPattern(events: [dull], parameters: [])
    }

    /// A brief, low thud closes a broken streak without a long vibration
    /// masking the next input.
    private func makeBreakPattern() -> CHHapticPattern? {
        let thump = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: Tunables.hapticDeath * 0.30),
                .init(parameterID: .hapticSharpness, value: 0.15)
            ],
            relativeTime: 0
        )
        let rumble = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.10),
                .init(parameterID: .hapticSharpness, value: 0.1)
            ],
            relativeTime: 0.005,
            duration: 0.065
        )
        let tail = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.10),
                .init(parameterID: .hapticSharpness, value: 0.05)
            ],
            relativeTime: 0.085
        )
        return try? CHHapticPattern(events: [thump, rumble, tail], parameters: [])
    }

    private func makeTierPattern(tier: Int) -> CHHapticPattern? {
        let intensity = min(0.28, 0.14 + 0.035 * Float(tier))
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: 0.55)
            ],
            relativeTime: 0
        )
        return try? CHHapticPattern(events: [event], parameters: [])
    }

    /// A single low-intensity, low-sharpness transient. Reads as a "touch
    /// landed" tap on the fingertip — distinct from any of the hit grades
    /// so the brain doesn't confuse it with strike feedback.
    private func makeTouchDownPattern() -> CHHapticPattern? {
        let tap = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: Tunables.hapticTouchDown * 0.4),
                .init(parameterID: .hapticSharpness, value: 0.35)
            ],
            relativeTime: 0
        )
        return try? CHHapticPattern(events: [tap], parameters: [])
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
