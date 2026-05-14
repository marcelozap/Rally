import SpriteKit
import UIKit

/// Owns particle / shockwave effects. Decoupled from `GameScene` so the
/// scene only emits events — the manager decides what burst to spawn.
///
/// The manager holds a weak reference to the scene it should render into,
/// which is set by `GameScene` on `didMove(to:)`.
final class ParticleManager {
    static let shared = ParticleManager()

    var isEnabled: Bool = true
    weak var scene: SKScene?

    private init() {
        GameEventBus.shared.subscribe(self) { [weak self] event in
            self?.handle(event)
        }
    }

    func attach(to scene: SKScene) {
        self.scene = scene
    }

    // MARK: Event routing

    private func handle(_ event: GameEvent) {
        guard isEnabled, let scene = scene else { return }
        switch event {
        case .hit(let quality, _, let position, _):
            emitHitBurst(quality: quality, at: position, in: scene)
        case .comboBreak:
            emitBreakShatter(in: scene)
        case .comboTier(let tier) where tier > 0:
            emitTierFlash(tier: tier, in: scene)
        default:
            break
        }
    }

    // MARK: Effects

    private func emitHitBurst(quality: HitQuality, at point: CGPoint, in scene: SKScene) {
        let burst = SKShapeNode(circleOfRadius: 4)
        burst.position = point
        burst.strokeColor = color(for: quality)
        burst.fillColor = .clear
        burst.glowWidth = 8
        burst.lineWidth = 2
        scene.addChild(burst)

        let scaleTo: CGFloat = {
            switch quality {
            case .perfect: return 12
            case .great:   return 8
            case .good:    return 5
            case .miss:    return 2
            }
        }()
        let duration: TimeInterval = quality == .perfect ? 0.45 : 0.30

        let expand = SKAction.scale(to: scaleTo, duration: duration)
        expand.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: duration)
        let remove = SKAction.removeFromParent()
        burst.run(.sequence([.group([expand, fade]), remove]))
    }

    private func emitBreakShatter(in scene: SKScene) {
        let flash = SKShapeNode(rectOf: scene.size)
        flash.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        flash.fillColor = UIColor(red: 1, green: 0.1, blue: 0.3, alpha: 0.25)
        flash.strokeColor = .clear
        flash.zPosition = 1000
        scene.addChild(flash)

        flash.run(.sequence([
            .fadeOut(withDuration: 0.4),
            .removeFromParent()
        ]))
    }

    private func emitTierFlash(tier: Int, in scene: SKScene) {
        let bar = SKShapeNode(rectOf: CGSize(width: scene.size.width, height: 4))
        bar.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.25)
        bar.fillColor = tierColor(tier)
        bar.strokeColor = .clear
        bar.glowWidth = 16
        bar.zPosition = 500
        scene.addChild(bar)

        bar.run(.sequence([
            .group([
                .scaleY(to: 0.1, duration: 0.6),
                .fadeOut(withDuration: 0.6)
            ]),
            .removeFromParent()
        ]))
    }

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
