import SpriteKit
import UIKit

/// Owns visual feedback: particle bursts, screen shake, screen flashes,
/// and tier transitions.
///
/// `GameScene` attaches itself once on `didMove(to:)` via `attach(scene:,
/// shakeTarget:)`. After that, the manager listens on `GameEventBus` and
/// renders into the bound scene with no further coordination required.
final class ParticleManager {
    static let shared = ParticleManager()

    var isEnabled: Bool = true

    weak var scene: SKScene?
    weak var shakeTarget: SKNode?

    private init() {
        GameEventBus.shared.subscribe(self) { [weak self] event in
            self?.handle(event)
        }
    }

    func attach(scene: SKScene, shakeTarget: SKNode) {
        self.scene = scene
        self.shakeTarget = shakeTarget
    }

    // MARK: - Event routing

    private func handle(_ event: GameEvent) {
        guard isEnabled, let scene = scene else { return }
        switch event {
        case .hit(let quality, _, let position, _, _):
            emitHitBurst(quality: quality, at: position, in: scene)
            applyHitShake(quality: quality)
        case .miss:
            applyMissShake()
        case .comboTier(let tier) where tier > 0:
            emitTierFlash(tier: tier, in: scene)
        case .comboBreak:
            emitDeathSequence(in: scene)
        default:
            break
        }
    }

    // MARK: - Hit burst

    private func emitHitBurst(quality: HitQuality, at point: CGPoint, in scene: SKScene) {
        let burst = SKShapeNode(circleOfRadius: 4)
        burst.position = point
        burst.strokeColor = color(for: quality)
        burst.fillColor = .clear
        burst.glowWidth = quality == .perfect ? 12 : 7
        burst.lineWidth = quality == .perfect ? 2.2 : 1.8
        burst.zPosition = 100
        scene.addChild(burst)

        let scaleTo: CGFloat
        let durationMs: Double
        switch quality {
        case .perfect:
            scaleTo = 11
            durationMs = Tunables.perfectBurstDurationMs * 0.82
        case .great:
            scaleTo = 7
            durationMs = Tunables.hitBurstDurationMs * 0.8
        case .good:
            scaleTo = 4.2
            durationMs = Tunables.hitBurstDurationMs * 0.6
        case .miss:
            scaleTo = 2.4
            durationMs = Tunables.hitBurstDurationMs * 0.45
        }

        let expand = SKAction.scale(to: scaleTo, duration: durationMs.seconds)
        expand.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: durationMs.seconds)
        burst.run(.sequence([.group([expand, fade]), .removeFromParent()]))

        emitDirectionalStreak(quality: quality, at: point, in: scene)
        emitQualityEcho(quality: quality, at: point, in: scene)

        // Quick chromatic flash from the ball's color across the strike line.
        if quality == .perfect {
            emitPerfectChromaticFlash(at: point, color: burst.strokeColor, in: scene)
        }
    }

    private func emitPerfectChromaticFlash(at point: CGPoint, color: UIColor, in scene: SKScene) {
        let bar = SKShapeNode(rectOf: CGSize(width: scene.size.width * 1.2, height: 2))
        bar.position = CGPoint(x: scene.size.width / 2, y: point.y)
        bar.fillColor = color
        bar.strokeColor = .clear
        bar.glowWidth = 14
        bar.zPosition = 90
        bar.alpha = 0.72
        scene.addChild(bar)

        bar.run(.sequence([
            .group([
                .scaleY(to: 0.12, duration: 0.22),
                .fadeOut(withDuration: 0.22)
            ]),
            .removeFromParent()
        ]))
    }

    private func emitDirectionalStreak(quality: HitQuality, at point: CGPoint, in scene: SKScene) {
        let streak = SKShapeNode(rectOf: CGSize(width: 72, height: 3), cornerRadius: 1.5)
        streak.position = point
        streak.fillColor = color(for: quality).withAlphaComponent(0.9)
        streak.strokeColor = .clear
        streak.glowWidth = quality == .perfect ? 10 : 6
        streak.zPosition = 96
        scene.addChild(streak)

        let rise = CGFloat(quality == .perfect ? 38 : 26)
        let drift = CGFloat.random(in: -18...18)
        let target = CGPoint(x: point.x + drift, y: point.y + rise)
        let duration = (quality == .perfect ? 0.22 : 0.18)
        streak.run(.sequence([
            .group([
                .move(to: target, duration: duration),
                .fadeOut(withDuration: duration),
                .scaleX(to: quality == .perfect ? 1.45 : 1.22, duration: duration)
            ]),
            .removeFromParent()
        ]))
    }

    private func emitQualityEcho(quality: HitQuality, at point: CGPoint, in scene: SKScene) {
        let echo = SKShapeNode(circleOfRadius: quality == .perfect ? 22 : (quality == .great ? 16 : 11))
        echo.position = point
        echo.fillColor = .clear
        echo.strokeColor = color(for: quality).withAlphaComponent(quality == .good ? 0.42 : 0.72)
        echo.lineWidth = quality == .perfect ? 2.2 : 1.4
        echo.glowWidth = quality == .perfect ? 12 : (quality == .great ? 8 : 4)
        echo.zPosition = 95
        scene.addChild(echo)

        let driftX: CGFloat
        let driftY: CGFloat
        let scale: CGFloat
        let duration: TimeInterval
        switch quality {
        case .perfect:
            driftX = 0
            driftY = 10
            scale = 1.45
            duration = 0.24
        case .great:
            driftX = 4
            driftY = 6
            scale = 1.24
            duration = 0.2
        case .good:
            driftX = -6
            driftY = 2
            scale = 1.12
            duration = 0.16
        case .miss:
            driftX = 0
            driftY = 0
            scale = 1
            duration = 0.1
        }

        echo.run(.sequence([
            .group([
                .moveBy(x: driftX, y: driftY, duration: duration),
                .scale(to: scale, duration: duration),
                .fadeOut(withDuration: duration)
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Tier flash (combo level-up)

    private func emitTierFlash(tier: Int, in scene: SKScene) {
        let strikeY = scene.size.height * Tunables.strikeLineYRatio
        let bar = SKShapeNode(rectOf: CGSize(width: scene.size.width * 0.86, height: 4))
        bar.position = CGPoint(x: scene.size.width / 2, y: strikeY)
        bar.fillColor = tierColor(tier)
        bar.strokeColor = .clear
        bar.glowWidth = 16
        bar.zPosition = 80
        scene.addChild(bar)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = tierTitle(tier)
        label.fontSize = 16
        label.fontColor = tierColor(tier)
        label.position = CGPoint(x: scene.size.width / 2, y: strikeY + 54)
        label.zPosition = 82
        label.alpha = 0
        scene.addChild(label)

        bar.run(.sequence([
            .group([
                .scaleY(to: 0.18, duration: Tunables.tierFlashDurationMs.seconds * 0.78),
                .fadeOut(withDuration: Tunables.tierFlashDurationMs.seconds * 0.78)
            ]),
            .removeFromParent()
        ]))
        label.run(.sequence([
            .group([
                .fadeAlpha(to: 0.92, duration: 0.1),
                .scale(to: 1.04, duration: 0.14)
            ]),
            .wait(forDuration: 0.24),
            .group([
                .fadeOut(withDuration: 0.2),
                .scale(to: 1.0, duration: 0.2)
            ]),
            .removeFromParent()
        ]))

        if let target = shakeTarget {
            CameraShake.shake(
                target,
                amplitude: Tunables.shakeAmplitudeGreat * 0.82,
                durationMs: Tunables.shakeDurationHitMs * 0.8
            )
        }
    }

    // MARK: - Death sequence (combo break — the Flappy moment)

    private func emitDeathSequence(in scene: SKScene) {
        emitRedFlash(in: scene)
        emitRingShatter(in: scene)
        if let target = shakeTarget {
            CameraShake.shake(
                target,
                amplitude: Tunables.shakeAmplitudeDeath,
                durationMs: Tunables.shakeDurationDeathMs
            )
        }
    }

    private func emitRedFlash(in scene: SKScene) {
        let flash = SKShapeNode(rectOf: scene.size)
        flash.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        flash.fillColor = UIColor(red: 0.9, green: 0.16, blue: 0.28, alpha: 0.38)
        flash.strokeColor = .clear
        flash.zPosition = 1000
        flash.blendMode = .add
        scene.addChild(flash)

        flash.run(.sequence([
            .fadeOut(withDuration: Tunables.redFlashDurationMs.seconds),
            .removeFromParent()
        ]))
    }

    private func emitRingShatter(in scene: SKScene) {
        // Concentric ring blasting outward from the strike line center —
        // makes the death visually unambiguous even silently.
        let strikeY = scene.size.height * Tunables.strikeLineYRatio
        let ring = SKShapeNode(circleOfRadius: 20)
        ring.position = CGPoint(x: scene.size.width / 2, y: strikeY)
        ring.fillColor = .clear
        ring.strokeColor = UIColor(red: 1, green: 0.2, blue: 0.4, alpha: 1)
        ring.glowWidth = 10
        ring.lineWidth = 2.4
        ring.zPosition = 200
        scene.addChild(ring)

        ring.run(.sequence([
            .group([
                .scale(to: 18, duration: 0.4),
                .fadeOut(withDuration: 0.4)
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Shake helpers

    private func applyHitShake(quality: HitQuality) {
        guard let target = shakeTarget else { return }
        let amp: CGFloat
        switch quality {
        case .perfect: amp = Tunables.shakeAmplitudePerfect
        case .great:   amp = Tunables.shakeAmplitudeGreat
        case .good:    amp = Tunables.shakeAmplitudeGood
        case .miss:    return
        }
        CameraShake.shake(target, amplitude: amp, durationMs: Tunables.shakeDurationHitMs)
    }

    private func applyMissShake() {
        guard let target = shakeTarget else { return }
        CameraShake.shake(
            target,
            amplitude: Tunables.shakeAmplitudeGood * 0.7,
            durationMs: Tunables.shakeDurationHitMs * 0.8
        )
    }

    // MARK: - Colors

    private func color(for quality: HitQuality) -> UIColor {
        switch quality {
        case .perfect: return UIColor(red: 0.33, green: 0.88, blue: 0.95, alpha: 1)
        case .great:   return UIColor(red: 0.87, green: 0.71, blue: 0.43, alpha: 1)
        case .good:    return UIColor(red: 0.96, green: 0.88, blue: 0.74, alpha: 1)
        case .miss:    return .gray
        }
    }

    private func tierColor(_ tier: Int) -> UIColor {
        switch tier {
        case 1:  return UIColor(red: 0.33, green: 0.88, blue: 0.95, alpha: 1)
        case 2:  return UIColor(red: 0.87, green: 0.71, blue: 0.43, alpha: 1)
        case 3:  return UIColor(red: 0.8, green: 0.33, blue: 0.55, alpha: 1)
        default: return UIColor(red: 0.96, green: 0.88, blue: 0.74, alpha: 1)
        }
    }

    private func tierTitle(_ tier: Int) -> String {
        switch tier {
        case 1: return "RALLY"
        case 2: return "PRESSURE"
        case 3: return "SURGE"
        default: return "BREAKER"
        }
    }
}
