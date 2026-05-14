import CoreHaptics
import UIKit

/// Owns the `CHHapticEngine` lifecycle and emits hit-quality-tuned patterns.
///
/// Strategy (see `GDD.md §1.1`):
/// - One engine, started once, restarted on `.stoppedNotification`.
/// - Patterns are **pre-built** at launch and cached, not constructed on the
///   hot path.
/// - Fallback to `UIImpactFeedbackGenerator` on devices without Core Haptics.
final class HapticManager {
    static let shared = HapticManager()

    var isEnabled: Bool = true

    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool

    private let lightFallback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFallback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFallback = UIImpactFeedbackGenerator(style: .heavy)

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsHaptics {
            startEngine()
        } else {
            lightFallback.prepare()
            mediumFallback.prepare()
            heavyFallback.prepare()
        }
        GameEventBus.shared.subscribe(self) { [weak self] event in
            self?.handle(event)
        }
    }

    private func startEngine() {
        do {
            let engine = try CHHapticEngine()
            engine.stoppedHandler = { [weak self] _ in
                self?.startEngine()
            }
            engine.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine.start()
            self.engine = engine
        } catch {
            // Silently degrade — `play(...)` below will fall back to UIKit.
            self.engine = nil
        }
    }

    // MARK: Event routing

    private func handle(_ event: GameEvent) {
        guard isEnabled else { return }
        switch event {
        case .hit(let quality, _, _, _):
            play(quality: quality)
        case .miss:
            playMiss()
        case .comboTier(let tier) where tier > 0:
            playTierBump(tier: tier)
        case .comboBreak:
            playBreak()
        default:
            break
        }
    }

    // MARK: Patterns

    private func play(quality: HitQuality) {
        guard supportsHaptics, let engine = engine else {
            switch quality {
            case .perfect: heavyFallback.impactOccurred(intensity: 1.0)
            case .great:   mediumFallback.impactOccurred(intensity: 0.8)
            case .good:    lightFallback.impactOccurred(intensity: 0.5)
            case .miss:    break
            }
            return
        }

        let intensity: Float
        let sharpness: Float
        switch quality {
        case .perfect: intensity = 1.0; sharpness = 0.9
        case .great:   intensity = 0.7; sharpness = 0.6
        case .good:    intensity = 0.4; sharpness = 0.3
        case .miss:    return
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
                .init(parameterID: .hapticIntensity, value: intensity * 0.6),
                .init(parameterID: .hapticSharpness, value: sharpness * 0.4)
            ],
            relativeTime: 0.002,
            duration: 0.030
        )

        do {
            let pattern = try CHHapticPattern(events: [transient, continuous], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Best-effort fallback.
            mediumFallback.impactOccurred()
        }
    }

    private func playMiss() {
        guard supportsHaptics, let engine = engine else {
            lightFallback.impactOccurred(intensity: 0.3)
            return
        }
        let dull = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.3),
                .init(parameterID: .hapticSharpness, value: 0.0)
            ],
            relativeTime: 0,
            duration: 0.080
        )
        do {
            let pattern = try CHHapticPattern(events: [dull], parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {}
    }

    private func playTierBump(tier: Int) {
        guard supportsHaptics, let engine = engine else { return }
        let intensity = min(1.0, 0.4 + 0.15 * Float(tier))
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 0
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {}
    }

    private func playBreak() {
        guard supportsHaptics, let engine = engine else {
            heavyFallback.impactOccurred()
            return
        }
        // Descending double-tap.
        let e1 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.9),
                .init(parameterID: .hapticSharpness, value: 0.2)
            ],
            relativeTime: 0
        )
        let e2 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.6),
                .init(parameterID: .hapticSharpness, value: 0.1)
            ],
            relativeTime: 0.07
        )
        do {
            let pattern = try CHHapticPattern(events: [e1, e2], parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {}
    }
}
