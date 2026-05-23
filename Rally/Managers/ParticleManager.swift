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
        case .hit(let quality, _, let position, let combo):
            // Perfect hits read as "on the line" — snap their burst to
            // the strike line center even if the ball happened to be a
            // few points above/below at swing time. Great/good keep the
            // ball position so the player gets honest spatial feedback
            // about how they were grading.
            let burstPos: CGPoint
            if quality == .perfect {
                let strikeY = scene.size.height * Tunables.strikeLineYRatio
                burstPos = CGPoint(x: scene.size.width / 2, y: strikeY)
            } else {
                burstPos = position
            }
            let tier = Tunables.comboTier(forCombo: combo)
            let juice = Tunables.tierJuiceMultiplier(tier: tier)
            emitHitBurst(quality: quality, at: burstPos, juice: juice, in: scene)
            applyHitShake(quality: quality, juice: juice)
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

    private func emitHitBurst(
        quality: HitQuality,
        at point: CGPoint,
        juice: CGFloat,
        in scene: SKScene
    ) {
        let burst = SKShapeNode(circleOfRadius: 4)
        burst.position = point
        burst.strokeColor = color(for: quality)
        burst.fillColor = .clear
        burst.glowWidth = (quality == .perfect ? 14 : 8) * juice
        burst.lineWidth = 2
        burst.zPosition = 100
        scene.addChild(burst)

        let baseScale: CGFloat
        let durationMs: Double
        switch quality {
        case .perfect:
            baseScale = 14
            durationMs = Tunables.perfectBurstDurationMs
        case .great:
            baseScale = 9
            durationMs = Tunables.hitBurstDurationMs
        case .good:
            baseScale = 5
            durationMs = Tunables.hitBurstDurationMs * 0.8
        case .miss:
            baseScale = 2
            durationMs = Tunables.hitBurstDurationMs * 0.5
        }
        let scaleTo = baseScale * juice

        let expand = SKAction.scale(to: scaleTo, duration: durationMs.seconds)
        expand.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: durationMs.seconds)
        burst.run(.sequence([.group([expand, fade]), .removeFromParent()]))

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
        bar.glowWidth = 18
        bar.zPosition = 90
        bar.alpha = 0.9
        scene.addChild(bar)

        bar.run(.sequence([
            .group([
                .scaleY(to: 0.05, duration: 0.25),
                .fadeOut(withDuration: 0.25)
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Tier flash (combo level-up)

    private func emitTierFlash(tier: Int, in scene: SKScene) {
        let strikeY = scene.size.height * Tunables.strikeLineYRatio
        let bar = SKShapeNode(rectOf: CGSize(width: scene.size.width, height: 6))
        bar.position = CGPoint(x: scene.size.width / 2, y: strikeY)
        bar.fillColor = tierColor(tier)
        bar.strokeColor = .clear
        bar.glowWidth = 24
        bar.zPosition = 80
        scene.addChild(bar)

        bar.run(.sequence([
            .group([
                .scaleY(to: 0.1, duration: Tunables.tierFlashDurationMs.seconds),
                .fadeOut(withDuration: Tunables.tierFlashDurationMs.seconds)
            ]),
            .removeFromParent()
        ]))

        if let target = shakeTarget {
            CameraShake.shake(
                target,
                amplitude: Tunables.shakeAmplitudeGreat,
                durationMs: Tunables.shakeDurationHitMs
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
                amplitude: Tunables.live.shakeAmplitudeDeath,
                durationMs: Tunables.shakeDurationDeathMs
            )
        }
    }

    private func emitRedFlash(in scene: SKScene) {
        let flash = SKShapeNode(rectOf: scene.size)
        flash.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        flash.fillColor = UIColor(red: 1, green: 0.1, blue: 0.3, alpha: 0.55)
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
        ring.glowWidth = 14
        ring.lineWidth = 3
        ring.zPosition = 200
        scene.addChild(ring)

        ring.run(.sequence([
            .group([
                .scale(to: 22, duration: 0.45),
                .fadeOut(withDuration: 0.45)
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Shake helpers

    private func applyHitShake(quality: HitQuality, juice: CGFloat) {
        guard let target = shakeTarget else { return }
        let amp: CGFloat
        switch quality {
        case .perfect: amp = Tunables.live.shakeAmplitudePerfect
        case .great:   amp = Tunables.shakeAmplitudeGreat
        case .good:    amp = Tunables.shakeAmplitudeGood
        case .miss:    return
        }
        CameraShake.shake(target, amplitude: amp * juice, durationMs: Tunables.shakeDurationHitMs)
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
        case .perfect: return UIColor(red: 0,   green: 1,   blue: 1,   alpha: 1) // cyan
        case .great:   return UIColor(red: 0.8, green: 0,   blue: 1,   alpha: 1) // magenta
        case .good:    return UIColor(red: 1,   green: 1,   blue: 0.4, alpha: 1) // yellow
        case .miss:    return .gray
        }
    }

    private func tierColor(_ tier: Int) -> UIColor {
        switch tier {
        case 1:  return UIColor(red: 0,   green: 1,   blue: 1,   alpha: 1)
        case 2:  return UIColor(red: 1,   green: 0.2, blue: 0.7, alpha: 1)
        case 3:  return UIColor(red: 1,   green: 0.6, blue: 0,   alpha: 1)
        default: return UIColor(red: 1,   green: 1,   blue: 1,   alpha: 1)
        }
    }
}
