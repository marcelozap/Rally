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

    private var size: CGSize
    private var strikeY: CGFloat

    private var lowerGradient: SKShapeNode!
    private var upperGradient: SKShapeNode!
    private var horizonLine: SKShapeNode!
    private var leftAura: SKShapeNode!
    private var rightAura: SKShapeNode!
    private var centerSheen: SKShapeNode!
    private var centerRunway: SKShapeNode!
    private var sunHalo: SKShapeNode!
    private var sunDisc: SKShapeNode!
    private var netTape: SKShapeNode!
    private var serviceLine: SKShapeNode!
    private var baselineLine: SKShapeNode!
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
        gradient.fillColor = UIColor(red: 0.06, green: 0.08, blue: 0.16, alpha: 1)
        gradient.strokeColor = .clear
        gradient.alpha = 0.85
        gradient.zPosition = -100
        addChild(gradient)
        lowerGradient = gradient

        // A second pass above the horizon line: very subtle navy tone so
        // the upper portion of the screen isn't a void.
        let upper = SKShapeNode(rect: CGRect(x: 0, y: strikeY, width: size.width, height: size.height - strikeY))
        upper.fillColor = UIColor(red: 0.02, green: 0.03, blue: 0.1, alpha: 1)
        upper.strokeColor = .clear
        upper.alpha = 0.7
        upper.zPosition = -100
        addChild(upper)
        upperGradient = upper

        let auraSize = CGSize(width: size.width * 0.42, height: strikeY * 1.32)
        let leftAuraNode = SKShapeNode(ellipseOf: auraSize)
        leftAuraNode.fillColor = UIColor(red: 0.17, green: 0.66, blue: 0.72, alpha: 1)
        leftAuraNode.strokeColor = .clear
        leftAuraNode.alpha = 0.06
        leftAuraNode.position = CGPoint(x: size.width * 0.2, y: strikeY * 0.42)
        leftAuraNode.zPosition = -99
        addChild(leftAuraNode)
        leftAura = leftAuraNode

        let rightAuraNode = SKShapeNode(ellipseOf: auraSize)
        rightAuraNode.fillColor = UIColor(red: 0.8, green: 0.33, blue: 0.55, alpha: 1)
        rightAuraNode.strokeColor = .clear
        rightAuraNode.alpha = 0.05
        rightAuraNode.position = CGPoint(x: size.width * 0.8, y: strikeY * 0.46)
        rightAuraNode.zPosition = -99
        addChild(rightAuraNode)
        rightAura = rightAuraNode

        let centerSheenNode = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.5, height: strikeY * 0.72))
        centerSheenNode.fillColor = UIColor(white: 1.0, alpha: 1.0)
        centerSheenNode.strokeColor = .clear
        centerSheenNode.alpha = 0.035
        centerSheenNode.position = CGPoint(x: size.width * 0.5, y: strikeY * 0.18)
        centerSheenNode.zPosition = -98
        addChild(centerSheenNode)
        centerSheen = centerSheenNode

        let halo = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.36, height: strikeY * 0.46))
        halo.fillColor = UIColor(red: 0.99, green: 0.7, blue: 0.4, alpha: 1)
        halo.strokeColor = .clear
        halo.alpha = 0.08
        halo.position = CGPoint(x: size.width * 0.5, y: strikeY * 1.12)
        halo.zPosition = -99
        addChild(halo)
        sunHalo = halo

        let sun = SKShapeNode(circleOfRadius: min(size.width * 0.09, 52))
        sun.fillColor = UIColor(red: 1.0, green: 0.78, blue: 0.42, alpha: 1)
        sun.strokeColor = UIColor.white.withAlphaComponent(0.22)
        sun.lineWidth = 1
        sun.glowWidth = 12
        sun.alpha = 0.74
        sun.position = CGPoint(x: size.width * 0.5, y: strikeY * 1.1)
        sun.zPosition = -98
        addChild(sun)
        sunDisc = sun

        let runway = SKShapeNode(rectOf: CGSize(width: size.width * 0.18, height: strikeY * 0.9), cornerRadius: size.width * 0.05)
        runway.fillColor = UIColor(white: 1.0, alpha: 1.0)
        runway.strokeColor = .clear
        runway.alpha = 0.06
        runway.position = CGPoint(x: size.width * 0.5, y: strikeY * 0.16)
        runway.zPosition = -97
        addChild(runway)
        centerRunway = runway
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
        horizonLine = horizon

        let tape = SKShapeNode(rect: CGRect(x: 0, y: -0.5, width: size.width, height: 1))
        tape.position = CGPoint(x: 0, y: strikeY * 0.985)
        tape.fillColor = UIColor(white: 1.0, alpha: 0.16)
        tape.strokeColor = .clear
        tape.glowWidth = 2
        tape.zPosition = -89
        addChild(tape)
        netTape = tape
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
            let meta = NSMutableDictionary()
            meta["baseAlpha"] = NSNumber(value: Double(alpha))
            line.userData = meta
            gridNode.addChild(line)
        }

        let service = SKShapeNode(rect: CGRect(x: 0, y: -0.5, width: size.width * 0.56, height: 1))
        service.position = CGPoint(x: size.width * 0.22, y: strikeY * 0.46)
        service.fillColor = UIColor(white: 1.0, alpha: 0.16)
        service.strokeColor = .clear
        service.glowWidth = 2
        service.zPosition = -93
        addChild(service)
        serviceLine = service

        let baseline = SKShapeNode(rect: CGRect(x: 0, y: -0.5, width: size.width * 0.8, height: 1))
        baseline.position = CGPoint(x: size.width * 0.1, y: strikeY * 0.1)
        baseline.fillColor = UIColor(white: 1.0, alpha: 0.11)
        baseline.strokeColor = .clear
        baseline.glowWidth = 1
        baseline.zPosition = -93
        addChild(baseline)
        baselineLine = baseline

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
            let meta = NSMutableDictionary()
            meta["baseAlpha"] = NSNumber(value: 0.22)
            line.userData = meta
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
        horizonLine?.run(burst)
    }

    func resize(to size: CGSize, strikeYRatio: CGFloat) {
        guard size.width > 0, size.height > 0 else { return }
        self.size = size
        self.strikeY = size.height * strikeYRatio

        lowerGradient.path = CGPath(rect: CGRect(x: 0, y: 0, width: size.width, height: strikeY), transform: nil)
        upperGradient.path = CGPath(
            rect: CGRect(x: 0, y: strikeY, width: size.width, height: size.height - strikeY),
            transform: nil
        )

        let auraSize = CGSize(width: size.width * 0.42, height: strikeY * 1.32)
        leftAura.path = CGPath(ellipseIn: CGRect(origin: CGPoint(x: -auraSize.width / 2, y: -auraSize.height / 2), size: auraSize), transform: nil)
        leftAura.position = CGPoint(x: size.width * 0.2, y: strikeY * 0.42)
        rightAura.path = CGPath(ellipseIn: CGRect(origin: CGPoint(x: -auraSize.width / 2, y: -auraSize.height / 2), size: auraSize), transform: nil)
        rightAura.position = CGPoint(x: size.width * 0.8, y: strikeY * 0.46)

        let centerSheenSize = CGSize(width: size.width * 0.5, height: strikeY * 0.72)
        centerSheen.path = CGPath(
            ellipseIn: CGRect(origin: CGPoint(x: -centerSheenSize.width / 2, y: -centerSheenSize.height / 2), size: centerSheenSize),
            transform: nil
        )
        centerSheen.position = CGPoint(x: size.width * 0.5, y: strikeY * 0.18)

        let haloSize = CGSize(width: size.width * 0.36, height: strikeY * 0.46)
        sunHalo.path = CGPath(
            ellipseIn: CGRect(origin: CGPoint(x: -haloSize.width / 2, y: -haloSize.height / 2), size: haloSize),
            transform: nil
        )
        sunHalo.position = CGPoint(x: size.width * 0.5, y: strikeY * 1.12)

        let sunRadius = min(size.width * 0.09, 52)
        sunDisc.path = CGPath(
            ellipseIn: CGRect(x: -sunRadius, y: -sunRadius, width: sunRadius * 2, height: sunRadius * 2),
            transform: nil
        )
        sunDisc.position = CGPoint(x: size.width * 0.5, y: strikeY * 1.1)

        let runwaySize = CGSize(width: size.width * 0.18, height: strikeY * 0.9)
        centerRunway.path = CGPath(
            roundedRect: CGRect(origin: CGPoint(x: -runwaySize.width / 2, y: -runwaySize.height / 2), size: runwaySize),
            cornerWidth: size.width * 0.05,
            cornerHeight: size.width * 0.05,
            transform: nil
        )
        centerRunway.position = CGPoint(x: size.width * 0.5, y: strikeY * 0.16)

        horizonLine.path = CGPath(rect: CGRect(x: 0, y: -1, width: size.width, height: 2), transform: nil)
        horizonLine.position = CGPoint(x: 0, y: strikeY)
        netTape.path = CGPath(rect: CGRect(x: 0, y: -0.5, width: size.width, height: 1), transform: nil)
        netTape.position = CGPoint(x: 0, y: strikeY * 0.985)

        serviceLine.path = CGPath(rect: CGRect(x: 0, y: -0.5, width: size.width * 0.56, height: 1), transform: nil)
        serviceLine.position = CGPoint(x: size.width * 0.22, y: strikeY * 0.46)

        baselineLine.path = CGPath(rect: CGRect(x: 0, y: -0.5, width: size.width * 0.8, height: 1), transform: nil)
        baselineLine.position = CGPoint(x: size.width * 0.1, y: strikeY * 0.1)

        let horizontalLines = gridNode.children.compactMap { $0 as? SKShapeNode }.filter { $0.userData?["baseAlpha"] != nil }
        let rowCount = 14
        let vanishX = size.width / 2
        var horizontalIndex = 0
        for line in horizontalLines {
            if horizontalIndex < rowCount {
                let frac = CGFloat(horizontalIndex) / CGFloat(rowCount - 1)
                let y = strikeY - frac * frac * strikeY
                line.path = CGPath(rect: CGRect(x: 0, y: -0.5, width: size.width, height: 1), transform: nil)
                line.position = CGPoint(x: 0, y: y)
                horizontalIndex += 1
            } else {
                let verticalIndex = horizontalIndex - rowCount
                let columnCount = 11
                let frac = CGFloat(verticalIndex) / CGFloat(columnCount - 1)
                let bottomX = frac * size.width
                let path = CGMutablePath()
                path.move(to: CGPoint(x: vanishX, y: strikeY))
                path.addLine(to: CGPoint(x: bottomX, y: 0))
                line.path = path
                line.position = .zero
                horizontalIndex += 1
            }
        }
    }

    func setMomentum(tier: Int, phase: String, breaking: Bool) {
        let targetHorizonAlpha: CGFloat
        let targetGlow: CGFloat
        let targetGridAlpha: CGFloat
        let lowerAlpha: CGFloat
        let upperAlpha: CGFloat
        let auraLeftAlpha: CGFloat
        let auraRightAlpha: CGFloat
        let runwayAlpha: CGFloat
        let lineAlpha: CGFloat
        let sunAlpha: CGFloat
        let haloAlpha: CGFloat

        if breaking {
            targetHorizonAlpha = 0.28
            targetGlow = 6
            targetGridAlpha = 0.42
            lowerAlpha = 0.74
            upperAlpha = 0.56
            auraLeftAlpha = 0.02
            auraRightAlpha = 0.02
            runwayAlpha = 0.02
            lineAlpha = 0.05
            sunAlpha = 0.42
            haloAlpha = 0.03
        } else {
            switch tier {
            case 4:
                targetHorizonAlpha = 0.86
                targetGlow = 20
                targetGridAlpha = 1.0
                lowerAlpha = 0.96
                upperAlpha = 0.82
                auraLeftAlpha = 0.1
                auraRightAlpha = 0.1
                runwayAlpha = 0.08
                lineAlpha = 0.14
                sunAlpha = 0.88
                haloAlpha = 0.11
            case 3:
                targetHorizonAlpha = 0.76
                targetGlow = 18
                targetGridAlpha = 0.94
                lowerAlpha = 0.92
                upperAlpha = 0.78
                auraLeftAlpha = 0.09
                auraRightAlpha = 0.09
                runwayAlpha = 0.07
                lineAlpha = 0.12
                sunAlpha = 0.84
                haloAlpha = 0.1
            case 2:
                targetHorizonAlpha = 0.68
                targetGlow = 16
                targetGridAlpha = 0.88
                lowerAlpha = 0.9
                upperAlpha = 0.76
                auraLeftAlpha = 0.08
                auraRightAlpha = 0.08
                runwayAlpha = 0.06
                lineAlpha = 0.11
                sunAlpha = 0.8
                haloAlpha = 0.09
            case 1:
                targetHorizonAlpha = 0.61
                targetGlow = 15
                targetGridAlpha = 0.82
                lowerAlpha = 0.88
                upperAlpha = 0.74
                auraLeftAlpha = 0.07
                auraRightAlpha = 0.07
                runwayAlpha = 0.055
                lineAlpha = 0.1
                sunAlpha = 0.77
                haloAlpha = 0.08
            default:
                targetHorizonAlpha = phase == "breaker" ? 0.62 : 0.55
                targetGlow = phase == "pressure" || phase == "breaker" ? 16 : 14
                targetGridAlpha = phase == "pressure" || phase == "breaker" ? 0.84 : 0.76
                lowerAlpha = phase == "breaker" ? 0.9 : 0.85
                upperAlpha = phase == "breaker" ? 0.78 : 0.7
                auraLeftAlpha = phase == "pressure" || phase == "breaker" ? 0.08 : 0.06
                auraRightAlpha = phase == "pressure" || phase == "breaker" ? 0.08 : 0.05
                runwayAlpha = phase == "pressure" || phase == "breaker" ? 0.065 : 0.05
                lineAlpha = phase == "pressure" || phase == "breaker" ? 0.11 : 0.09
                sunAlpha = phase == "pressure" || phase == "breaker" ? 0.82 : 0.74
                haloAlpha = phase == "pressure" || phase == "breaker" ? 0.09 : 0.07
            }
        }

        let duration = 0.24
        let fadeNode = { (node: SKNode?, alpha: CGFloat) in
            node?.run(.fadeAlpha(to: alpha, duration: duration))
        }
        fadeNode(horizonLine, targetHorizonAlpha)
        fadeNode(lowerGradient, lowerAlpha)
        fadeNode(upperGradient, upperAlpha)
        fadeNode(leftAura, auraLeftAlpha)
        fadeNode(rightAura, auraRightAlpha)
        fadeNode(centerRunway, runwayAlpha)
        fadeNode(sunDisc, sunAlpha)
        fadeNode(sunHalo, haloAlpha)
        fadeNode(netTape, lineAlpha * 1.25)
        fadeNode(serviceLine, lineAlpha)
        fadeNode(baselineLine, lineAlpha * 0.84)
        horizonLine?.run(.customAction(withDuration: duration) { [weak self] _, elapsed in
            guard let self else { return }
            let progress = elapsed / CGFloat(duration)
            let current = self.horizonLine.glowWidth
            self.horizonLine.glowWidth = current + (targetGlow - current) * progress
        })
        gridNode.children.forEach { child in
            let baseAlpha = CGFloat((child.userData?["baseAlpha"] as? NSNumber)?.doubleValue ?? Double(child.alpha))
            child.run(.fadeAlpha(to: targetGridAlpha * baseAlpha, duration: duration))
        }
    }
}
