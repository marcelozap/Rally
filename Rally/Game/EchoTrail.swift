import SpriteKit

/// The "Echo Trail" — Rally's signature visual reward, scoped to v1.
///
/// When the player crosses `Tunables.comboTier1` (5) and lands a `.perfect`,
/// each subsequent perfect appends its position to a glowing path stroked
/// across the scene. The result is a self-drawn neon waveform of the run.
///
/// On `.comboBreak`, the path shatters into N point-sized fragments that
/// fade out in place. The shatter is the visual exclamation point on the
/// death freeze.
///
/// ## Why this is its own class
///
/// The trail has its own lifecycle (idle / drawing / shattered) that
/// doesn't map cleanly onto `ParticleManager`. Keeping it isolated also
/// lets us swap implementations later (e.g. `SKShader`-backed) without
/// touching gameplay.
///
/// ## Threading
///
/// All access on the SpriteKit main thread, like every other manager.
final class EchoTrail {

    private weak var scene: SKScene?
    private var pathNode: SKShapeNode?
    private var points: [CGPoint] = []
    private var active = false

    var isEnabled: Bool = true

    /// Combo threshold at which the trail begins. Mirrors the GDD's
    /// "5+ Perfect Hits in a row" spec.
    var activationCombo: Int = Tunables.comboTier1

    init() {
        GameEventBus.shared.subscribe(self) { [weak self] event in
            self?.handle(event)
        }
    }

    /// Bind to the current `GameScene`. Called from `didMove(to:)`.
    func attach(scene: SKScene) {
        self.scene = scene
        reset()
    }

    // MARK: - Event routing

    private func handle(_ event: GameEvent) {
        guard isEnabled else { return }
        switch event {
        case .hit(let quality, _, let position, let combo):
            guard quality == .perfect, combo >= activationCombo else { return }
            append(point: position, combo: combo)
        case .comboBreak:
            shatter()
        case .sessionStart, .sessionEnd:
            reset()
        default:
            break
        }
    }

    // MARK: - Drawing

    private func ensureNode() -> SKShapeNode? {
        if let node = pathNode { return node }
        guard let scene = scene else { return nil }
        let node = SKShapeNode()
        node.strokeColor = UIColor(red: 0, green: 1, blue: 1, alpha: 0.9)
        node.fillColor = .clear
        node.lineWidth = 3
        node.glowWidth = 14
        node.lineCap = .round
        node.lineJoin = .round
        node.zPosition = 55
        scene.addChild(node)
        pathNode = node
        return node
    }

    private func append(point: CGPoint, combo: Int) {
        guard let node = ensureNode() else { return }
        points.append(point)
        active = true

        // Glow scales with combo tier so a longer streak literally glows
        // brighter; the visual escalates with the run.
        let tier = Tunables.comboTier(forCombo: combo)
        let juice = Tunables.tierJuiceMultiplier(tier: tier)
        node.glowWidth = 14 * juice
        node.lineWidth = 3 + 1.5 * (juice - 1)

        let path = CGMutablePath()
        if let first = points.first {
            path.move(to: first)
            for p in points.dropFirst() {
                path.addLine(to: p)
            }
        }
        node.path = path
    }

    // MARK: - Shatter

    /// Replace the path with one short-lived shape per sampled point, then
    /// fade them out. Cheap (≤ N nodes), shape-distinct from the death
    /// flash, and synchronous so the explosion lands inside the death
    /// freeze.
    private func shatter() {
        guard active, let node = pathNode, let scene = scene else {
            reset()
            return
        }
        active = false

        // Sample at most ~30 points along the path so we don't spawn a
        // ridiculous number of nodes on a 50-perfect run.
        let sampled = sample(points: points, maxCount: 30)
        node.removeFromParent()
        pathNode = nil

        for p in sampled {
            let frag = SKShapeNode(circleOfRadius: 3)
            frag.position = p
            frag.fillColor = UIColor(red: 0, green: 1, blue: 1, alpha: 1)
            frag.strokeColor = .clear
            frag.glowWidth = 6
            frag.zPosition = 55
            scene.addChild(frag)
            let drift = CGVector(
                dx: CGFloat.random(in: -18...18),
                dy: CGFloat.random(in: -18...18)
            )
            let move  = SKAction.move(by: drift, duration: 0.45)
            let fade  = SKAction.fadeOut(withDuration: 0.45)
            let shrink = SKAction.scale(to: 0.2, duration: 0.45)
            frag.run(.sequence([.group([move, fade, shrink]), .removeFromParent()]))
        }
        points.removeAll(keepingCapacity: true)
    }

    private func sample(points: [CGPoint], maxCount: Int) -> [CGPoint] {
        guard points.count > maxCount else { return points }
        var out: [CGPoint] = []
        out.reserveCapacity(maxCount)
        let stride = Double(points.count) / Double(maxCount)
        for i in 0..<maxCount {
            let idx = min(points.count - 1, Int(Double(i) * stride))
            out.append(points[idx])
        }
        return out
    }

    // MARK: - Reset

    private func reset() {
        pathNode?.removeFromParent()
        pathNode = nil
        points.removeAll(keepingCapacity: true)
        active = false
    }
}
