import SpriteKit
import UIKit

/// Animated synthwave-style backdrop for the gameplay scene.
///
/// Visual layers, back to front:
///
/// 1. **Vertical gradient** — pitch-black at the strike line graduating to
///    a deep magenta-on-black just below the horizon. Static, drawn as a
///    full-size `SKShapeNode` with a `cgColor` fill.
/// 2. **Horizon line** — a single bright cyan stroke at the strike line
///    height that bleeds upward via glow. Provides a confident "stage
///    floor" for the action.
/// 3. **Receding grid** — a fan of perspective lines drawn in front of the
///    horizon. Slowly translates downward over `gridScrollSeconds` to give
///    the sense the floor is moving past you. The lines reset by snapping
///    a row offset; no allocations on the hot path.
///
/// The whole thing is one `SKNode` so the scene can add it as the lowest
/// `zPosition` and never think about it again.
final class SynthwaveBackground: SKNode {

    private let size: CGSize
    private let strikeY: CGFloat

    private let gridNode = SKNode()

    init(size: CGSize, strikeYRatio: CGFloat) {
        self.size = size
        self.strikeY = size.height * strikeYRatio
        super.init()
        buildGradient()
        buildHorizon()
        buildGrid()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Layers

    private func buildGradient() {
        // Subtle blue-magenta vignette at the bottom 25% of the screen.
        let gradient = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: strikeY))
        gradient.fillColor = UIColor(red: 0.08, green: 0.0, blue: 0.16, alpha: 1)
        gradient.strokeColor = .clear
        gradient.alpha = 0.85
        gradient.zPosition = -100
        addChild(gradient)

        // A second pass above the horizon line: very subtle navy tone so
        // the upper portion of the screen isn't a void.
        let upper = SKShapeNode(rect: CGRect(x: 0, y: strikeY, width: size.width, height: size.height - strikeY))
        upper.fillColor = UIColor(red: 0.0, green: 0.02, blue: 0.06, alpha: 1)
        upper.strokeColor = .clear
        upper.alpha = 0.7
        upper.zPosition = -100
        addChild(upper)
    }

    private func buildHorizon() {
        let horizon = SKShapeNode(rect: CGRect(x: 0, y: -1, width: size.width, height: 2))
        horizon.position = CGPoint(x: 0, y: strikeY)
        horizon.fillColor = UIColor(red: 0.8, green: 0.1, blue: 0.6, alpha: 1)
        horizon.strokeColor = .clear
        horizon.glowWidth = 14
        horizon.alpha = 0.55
        horizon.zPosition = -90
        addChild(horizon)
    }

    private func buildGrid() {
        gridNode.zPosition = -95
        gridNode.position = CGPoint(x: 0, y: 0)
        addChild(gridNode)

        // Perspective floor: a series of horizontal scanlines below the
        // horizon that get tighter and dimmer as they approach the bottom.
        // Lines are positioned in a non-linear "perspective" mapping so the
        // floor reads as receding.
        let rowCount = 14
        for i in 0..<rowCount {
            let frac = CGFloat(i) / CGFloat(rowCount - 1)
            // Quadratic spacing — rows pack closer together near the
            // horizon (top of the floor area).
            let y = strikeY - frac * frac * strikeY
            let alpha = 0.35 - 0.18 * frac
            let line = SKShapeNode(rect: CGRect(x: 0, y: -0.5, width: size.width, height: 1))
            line.position = CGPoint(x: 0, y: y)
            line.fillColor = UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: alpha)
            line.strokeColor = .clear
            line.glowWidth = 2
            gridNode.addChild(line)
        }

        // Vertical perspective lines — fan from a single vanishing point at
        // the screen-center / horizon to evenly-spaced points across the
        // bottom edge. These are static.
        let vanishX = size.width / 2
        let columnCount = 11
        for i in 0..<columnCount {
            let frac = CGFloat(i) / CGFloat(columnCount - 1)
            let bottomX = frac * size.width
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: vanishX, y: strikeY))
            path.addLine(to: CGPoint(x: bottomX, y: 0))
            line.path = path
            line.strokeColor = UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.22)
            line.lineWidth = 1
            line.glowWidth = 1
            line.zPosition = -94
            gridNode.addChild(line)
        }

        // Slow downward drift on the horizontal lines (NOT the vertical
        // ones, which need their fixed vanishing geometry).
        let scrollDuration: TimeInterval = 1.6
        let scroll = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: -strikeY * 0.12, duration: scrollDuration),
            .moveBy(x: 0, y:  strikeY * 0.12, duration: 0)
        ]))
        for child in gridNode.children where child is SKShapeNode {
            // Skip vertical lines (those have a path; horizontals have a path too).
            // Identify horizontals by their non-zero y position and zero-width path.
            if abs(child.position.y - strikeY) > 1 && child.position.y < strikeY {
                child.run(scroll)
            }
        }
    }

    // MARK: - Public hooks

    /// Briefly flashes the horizon line — for tier-up / "big moment"
    /// punctuation. Returns immediately; the animation is owned by the node.
    func pulseHorizon(intensity: CGFloat = 1.0) {
        guard let horizon = children.first(where: { $0.zPosition == -90 }) as? SKShapeNode else { return }
        let burst = SKAction.sequence([
            .group([
                .fadeAlpha(to: min(1.0, 0.85 * intensity), duration: 0.08),
                .scaleY(to: 3.0 * intensity, duration: 0.08)
            ]),
            .group([
                .fadeAlpha(to: 0.55, duration: 0.42),
                .scaleY(to: 1.0, duration: 0.42)
            ])
        ])
        horizon.run(burst)
    }
}
