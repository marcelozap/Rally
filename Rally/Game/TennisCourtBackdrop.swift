import SpriteKit
import UIKit

/// Perspective tennis court — reads as 3D-ish without SceneKit. Single centered
/// corridor toward the net; player stays fixed at the bottom.
final class TennisCourtBackdrop: SKNode {

    private let strikeYRatio: CGFloat
    private var venue: CourtVenue
    private var layoutSize: CGSize

    /// Net band kept for `pulseHorizon` animations after rebuild.
    private weak var netBandRef: SKShapeNode?

    init(size: CGSize, strikeYRatio: CGFloat, surface: CourtVenue = .current) {
        self.layoutSize = size
        self.strikeYRatio = strikeYRatio
        self.venue = surface
        super.init()
        zPosition = -100
        rebuild(with: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func apply(surface: CourtVenue) {
        venue = surface
        rebuild(with: layoutSize)
    }

    func resize(to size: CGSize) {
        layoutSize = size
        rebuild(with: size)
    }

    func resize(to size: CGSize, strikeYRatio _: CGFloat) {
        resize(to: size)
    }

    private func rebuild(with size: CGSize) {
        let pal = venue.palette
        removeAllChildren()
        netBandRef = nil

        let strikeY = size.height * strikeYRatio
        // Extend the near edge below the visible viewport so gameplay never
        // reads like the court ends before the player's feet.
        let nearY = -size.height * Tunables.gameplayCourtNearOverscanRatio
        let topY = size.height * 1.02

        let skyLower = SKShapeNode(rect: CGRect(x: 0, y: strikeY, width: size.width, height: topY - strikeY))
        skyLower.fillColor = pal.skyBottom
        skyLower.strokeColor = .clear
        skyLower.zPosition = -100
        addChild(skyLower)

        let skyUpper = SKShapeNode(rect: CGRect(x: 0, y: strikeY + (topY - strikeY) * 0.55, width: size.width, height: (topY - strikeY) * 0.45))
        skyUpper.fillColor = pal.skyTop
        skyUpper.strokeColor = .clear
        skyUpper.alpha = 0.92
        skyUpper.zPosition = -99
        addChild(skyUpper)

        let farY = size.height * Tunables.gameplayCourtFarYRatio
        let nearHalf = size.width * Tunables.gameplayCourtNearHalfWidthRatio
        let farHalf = size.width * Tunables.gameplayCourtFarHalfWidthRatio
        let cx = size.width / 2

        let courtPath = CGMutablePath()
        courtPath.move(to: CGPoint(x: cx - nearHalf, y: nearY))
        courtPath.addLine(to: CGPoint(x: cx + nearHalf, y: nearY))
        courtPath.addLine(to: CGPoint(x: cx + farHalf, y: farY))
        courtPath.addLine(to: CGPoint(x: cx - farHalf, y: farY))
        courtPath.closeSubpath()

        let courtTrapezoid = SKShapeNode(path: courtPath)
        courtTrapezoid.fillColor = pal.court
        courtTrapezoid.strokeColor = pal.line.withAlphaComponent(0.85)
        courtTrapezoid.lineWidth = 2
        courtTrapezoid.zPosition = -95
        addChild(courtTrapezoid)

        // Horizontal depth grid — reads as court stripes receding toward the baseline.
        let gridSteps = 6
        for g in 1..<gridSteps {
            let u = CGFloat(g) / CGFloat(gridSteps)
            let y = nearY + (farY - nearY) * u
            let halfAtY = nearHalf + (farHalf - nearHalf) * u
            let gp = CGMutablePath()
            gp.move(to: CGPoint(x: cx - halfAtY, y: y))
            gp.addLine(to: CGPoint(x: cx + halfAtY, y: y))
            let gridLine = SKShapeNode(path: gp)
            gridLine.strokeColor = pal.courtDark.withAlphaComponent(0.42)
            gridLine.lineWidth = 1
            gridLine.zPosition = -94
            addChild(gridLine)
        }

        if venue == .wimbledonGrass {
            let stripeCount = 10
            for i in 0..<stripeCount where i % 2 != 0 {
                let t0 = CGFloat(i) / CGFloat(stripeCount)
                let t1 = CGFloat(i + 1) / CGFloat(stripeCount)
                let lx0 = cx - nearHalf + (2 * nearHalf) * t0
                let lx1 = cx - nearHalf + (2 * nearHalf) * t1
                let fx0 = cx - farHalf + (2 * farHalf) * t0
                let fx1 = cx - farHalf + (2 * farHalf) * t1
                let sp = CGMutablePath()
                sp.move(to: CGPoint(x: lx0, y: nearY))
                sp.addLine(to: CGPoint(x: lx1, y: nearY))
                sp.addLine(to: CGPoint(x: fx1, y: farY))
                sp.addLine(to: CGPoint(x: fx0, y: farY))
                sp.closeSubpath()
                let stripe = SKShapeNode(path: sp)
                stripe.fillColor = pal.courtDark.withAlphaComponent(0.35)
                stripe.strokeColor = .clear
                stripe.zPosition = -94
                addChild(stripe)
            }
        }

        for sign in [-1, 1] as [Int] {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: cx + CGFloat(sign) * nearHalf, y: nearY))
            path.addLine(to: CGPoint(x: cx + CGFloat(sign) * farHalf, y: farY))
            let line = SKShapeNode(path: path)
            line.strokeColor = pal.line.withAlphaComponent(0.9)
            line.lineWidth = 2.5
            line.glowWidth = 1
            line.zPosition = -93
            addChild(line)
        }

        let cm = CGMutablePath()
        cm.move(to: CGPoint(x: cx, y: nearY + 10))
        cm.addLine(to: CGPoint(x: cx, y: farY - 6))
        // SKShapeNode lacks lineDashPattern, so dash the CGPath itself.
        let dashedCenter = cm.copy(dashingWithPhase: 0, lengths: [6, 8])
        let centerMark = SKShapeNode(path: dashedCenter)
        centerMark.strokeColor = pal.line.withAlphaComponent(0.55)
        centerMark.lineWidth = 1.5
        centerMark.zPosition = -92
        addChild(centerMark)

        let fbPath = CGMutablePath()
        fbPath.move(to: CGPoint(x: cx - farHalf, y: farY))
        fbPath.addLine(to: CGPoint(x: cx + farHalf, y: farY))
        let farBaseline = SKShapeNode(path: fbPath)
        farBaseline.strokeColor = pal.line
        farBaseline.lineWidth = 3
        farBaseline.zPosition = -91
        addChild(farBaseline)

        let netY = nearY + (farY - nearY) * Tunables.gameplayCourtNetDepthRatio
        let netHalfNear = nearHalf * Tunables.gameplayCourtNetNearHalfScalar
        let netHalfFar = farHalf * Tunables.gameplayCourtNetFarHalfScalar
        let np = CGMutablePath()
        np.move(to: CGPoint(x: cx - netHalfNear, y: netY))
        np.addLine(to: CGPoint(x: cx + netHalfNear, y: netY))
        np.addLine(to: CGPoint(x: cx + netHalfFar, y: netY + 10))
        np.addLine(to: CGPoint(x: cx - netHalfFar, y: netY + 10))
        np.closeSubpath()
        let netBand = SKShapeNode(path: np)
        netBand.fillColor = UIColor(white: 1, alpha: 0.88)
        netBand.strokeColor = UIColor(white: 0.75, alpha: 1)
        netBand.lineWidth = 1
        netBand.zPosition = -90
        addChild(netBand)
        netBandRef = netBand
    }

    func pulseHorizon(intensity: CGFloat = 1.0) {
        guard let netBand = netBandRef else { return }
        netBand.removeAction(forKey: "pulseNet")
        netBand.alpha = 1
        let up = SKAction.fadeAlpha(to: min(1, 0.55 + 0.35 * intensity), duration: 0.06)
        let down = SKAction.fadeAlpha(to: 1.0, duration: 0.28)
        netBand.run(.sequence([up, down]), withKey: "pulseNet")
    }

    func setMomentum(tier: Int, phase: String, breaking: Bool) {
        let intensity: CGFloat
        if breaking {
            intensity = 0.68
        } else {
            switch tier {
            case 4: intensity = 1.0
            case 3: intensity = 0.92
            case 2: intensity = 0.84
            case 1: intensity = 0.76
            default:
                intensity = (phase == "pressure" || phase == "breaker") ? 0.82 : 0.72
            }
        }

        let duration = 0.22
        let netAlpha = 0.88 + intensity * 0.12
        let skyAlpha = 0.90 + intensity * 0.10
        let courtAlpha = 0.94 + intensity * 0.06

        children.compactMap { $0 as? SKShapeNode }.forEach { node in
            if node == netBandRef {
                node.run(.fadeAlpha(to: netAlpha, duration: duration))
            } else if node.zPosition <= -99 {
                node.run(.fadeAlpha(to: skyAlpha, duration: duration))
            } else if node.zPosition <= -91 {
                node.run(.fadeAlpha(to: courtAlpha, duration: duration))
            }
        }

        pulseHorizon(intensity: intensity)
    }
}
