import SpriteKit
import UIKit

/// A painted, perspective tennis club environment. All scenery is rasterized
/// once per layout; gameplay keeps its existing court projection and hit plane.
final class TennisCourtBackdrop: SKNode {
    private let strikeYRatio: CGFloat
    private var venue: CourtVenue
    private var layoutSize: CGSize
    private weak var netBandRef: SKShapeNode?

    private enum Layout {
        static let backDepth: CGFloat = 0.88
        static let baselineDepth: CGFloat = 0.83
        static let doublesHalfWidth: CGFloat = 0.86
        static let singlesHalfWidth: CGFloat = doublesHalfWidth * 0.75
        static let nearServiceDepth: CGFloat = 0.35
        static let farServiceDepth: CGFloat = 0.68
        static let netHeightRatio: CGFloat = 0.047
        static let textureScale: CGFloat = 3
        static let horizontalOverscan: CGFloat = 48
    }

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
        guard venue != surface else { return }
        venue = surface
        rebuild(with: layoutSize)
    }

    func resize(to size: CGSize) {
        guard layoutSize != size else { return }
        layoutSize = size
        rebuild(with: size)
    }

    func resize(to size: CGSize, strikeYRatio _: CGFloat) { resize(to: size) }

    private func rebuild(with size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        removeAllChildren()
        netBandRef = nil

        let nearY = -size.height * Tunables.gameplayCourtNearOverscanRatio
        let topY = size.height * 1.04
        let extent = CGSize(width: size.width + Layout.horizontalOverscan * 2, height: topY - nearY)
        let format = UIGraphicsImageRendererFormat()
        format.scale = Layout.textureScale
        format.preferredRange = .standard
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: extent, format: format)
        let image = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            // Author in SpriteKit's upward-growing coordinates.
            context.translateBy(x: Layout.horizontalOverscan, y: topY)
            context.scaleBy(x: 1, y: -1)
            drawEnvironment(context, size: size, nearY: nearY, topY: topY)
            drawCourt(context, size: size, nearY: nearY)
        }
        let backdrop = SKSpriteNode(texture: SKTexture(image: image), size: extent)
        backdrop.anchorPoint = CGPoint(x: 0, y: 0)
        backdrop.position = CGPoint(x: -Layout.horizontalOverscan, y: nearY)
        backdrop.zPosition = -100
        addChild(backdrop)
        buildNet(size: size)
    }

    /// The same trapezoid used by gameplay, with lateral coordinates normalized
    /// to its width. The painted far baseline sits inside the far runoff area.
    private func courtPoint(_ lateral: CGFloat, _ depth: CGFloat, size: CGSize) -> CGPoint {
        let nearY = -size.height * Tunables.gameplayCourtNearOverscanRatio
        let farY = size.height * Tunables.gameplayCourtFarYRatio
        let nearHalf = size.width * Tunables.gameplayCourtNearHalfWidthRatio
        let farHalf = size.width * Tunables.gameplayCourtFarHalfWidthRatio
        return CGPoint(x: size.width / 2 + lateral * (nearHalf + (farHalf - nearHalf) * depth),
                       y: nearY + (farY - nearY) * depth)
    }

    private func drawEnvironment(_ context: CGContext, size: CGSize, nearY: CGFloat, topY: CGFloat) {
        let palette = venue.palette
        let horizon = courtPoint(0, Layout.backDepth, size: size).y
        let sceneryLeft = -Layout.horizontalOverscan
        let sceneryWidth = size.width + Layout.horizontalOverscan * 2
        let skyRect = CGRect(x: sceneryLeft, y: nearY, width: sceneryWidth, height: topY - nearY)
        gradient(context, in: skyRect, bottom: palette.skyBottom, top: palette.skyTop)

        // A soft cloud bank and hazy hills keep the ball silhouette readable.
        let cloud = UIColor(red: 1, green: 0.98, blue: 0.91, alpha: 0.24)
        for index in 0..<4 {
            let x = size.width * (CGFloat(index) * 0.30 - 0.10)
            context.setFillColor(cloud.cgColor)
            context.fillEllipse(in: CGRect(x: x, y: horizon + size.height * 0.15,
                                          width: size.width * 0.45, height: size.height * 0.027))
        }
        let distant = UIColor(red: 0.30, green: 0.46, blue: 0.40, alpha: 0.38)
        let hillMargin = Layout.horizontalOverscan + 30
        var hills = [CGPoint(x: -hillMargin, y: horizon)]
        for index in 0...12 {
            let x = CGFloat(index) / 12 * (size.width + hillMargin * 2) - hillMargin
            let wave = sin(CGFloat(index) * 0.68) * 0.011 + sin(CGFloat(index) * 1.31) * 0.009
            hills.append(CGPoint(x: x, y: horizon + size.height * (0.068 + wave)))
        }
        hills.append(CGPoint(x: size.width + hillMargin, y: horizon))
        fill(context, points: hills, color: distant)

        let apronColor: UIColor
        switch venue {
        case .miamiHard:
            apronColor = UIColor(red: 0.20, green: 0.39, blue: 0.35, alpha: 1)
        case .wimbledonGrass:
            apronColor = UIColor(red: 0.22, green: 0.37, blue: 0.23, alpha: 1)
        case .redClay, .barcelonaClay:
            apronColor = UIColor(red: 0.54, green: 0.36, blue: 0.25, alpha: 1)
        }
        gradient(context, in: CGRect(x: sceneryLeft, y: nearY, width: sceneryWidth, height: horizon - nearY + 6),
                 bottom: apronColor, top: blend(apronColor, with: palette.skyBottom, amount: 0.16))

        // Trees are deliberately quiet silhouettes, behind the windscreen.
        var random = CourtNoise(seed: 723)
        for index in 0..<20 {
            let x = CGFloat(index) / 19 * size.width + (random.next() - 0.5) * 18
            let height = size.height * (0.028 + random.next() * 0.023)
            let green = UIColor(red: 0.12 + random.next() * 0.05,
                                green: 0.26 + random.next() * 0.05,
                                blue: 0.20, alpha: 0.78)
            context.setFillColor(green.cgColor)
            context.fillEllipse(in: CGRect(x: x - height * 0.6, y: horizon + 8,
                                          width: height * 1.2, height: height))
        }
        if venue == .miamiHard {
            drawPalm(context, at: CGPoint(x: size.width * 0.11, y: horizon + 8),
                     height: size.height * 0.115)
            drawPalm(context, at: CGPoint(x: size.width * 0.91, y: horizon + 8),
                     height: size.height * 0.092)
        } else {
            drawClubhouse(context, size: size, horizon: horizon)
        }

        // Back windscreen, rail and restrained fence mesh.
        let fenceBottom = horizon + 2
        let fenceHeight = size.height * 0.039
        let fenceRect = CGRect(x: sceneryLeft - 2, y: fenceBottom, width: sceneryWidth + 4, height: fenceHeight)
        gradient(context, in: fenceRect,
                 bottom: UIColor(red: 0.08, green: 0.19, blue: 0.15, alpha: 1),
                 top: UIColor(red: 0.16, green: 0.28, blue: 0.22, alpha: 1))
        let rail = UIColor(red: 0.63, green: 0.67, blue: 0.56, alpha: 0.46)
        stroke(context, points: [CGPoint(x: sceneryLeft, y: fenceBottom + fenceHeight),
                                 CGPoint(x: size.width + Layout.horizontalOverscan, y: fenceBottom + fenceHeight)],
               color: rail, width: 1)
        for index in -2...12 {
            let x = CGFloat(index) * size.width / 10
            stroke(context, points: [CGPoint(x: x, y: fenceBottom),
                                     CGPoint(x: x, y: fenceBottom + fenceHeight + 5)],
                   color: rail, width: 1.2)
        }
        context.saveGState()
        context.clip(to: fenceRect)
        let meshColor = UIColor(white: 0.85, alpha: 0.055)
        let firstMeshColumn = Int(floor((sceneryLeft - fenceHeight) / 8))
        let lastMeshColumn = Int(ceil((size.width + Layout.horizontalOverscan) / 8))
        for index in firstMeshColumn...lastMeshColumn {
            let x = CGFloat(index) * 8
            stroke(context, points: [CGPoint(x: x, y: fenceBottom),
                                     CGPoint(x: x + fenceHeight, y: fenceBottom + fenceHeight)],
                   color: meshColor, width: 0.6)
        }
        context.restoreGState()

        // Side corridors recede toward the same court projection.
        for sign: CGFloat in [-1, 1] {
            fill(context, points: [courtPoint(sign * 1.08, 0, size: size),
                                   courtPoint(sign * 1.22, 0, size: size),
                                   courtPoint(sign * 1.22, Layout.backDepth, size: size),
                                   courtPoint(sign * 1.08, Layout.backDepth, size: size)],
                 color: UIColor(white: 0.95, alpha: 0.065))
            stroke(context, points: [courtPoint(sign * 1.22, 0, size: size),
                                     courtPoint(sign * 1.22, Layout.backDepth, size: size)],
                   color: UIColor(white: 0.08, alpha: 0.17), width: 2)
        }
    }

    private func drawCourt(_ context: CGContext, size: CGSize, nearY: CGFloat) {
        let palette = venue.palette
        let court = polygon([courtPoint(-1, 0, size: size), courtPoint(1, 0, size: size),
                             courtPoint(1, Layout.backDepth, size: size),
                             courtPoint(-1, Layout.backDepth, size: size)])
        let backY = courtPoint(0, Layout.backDepth, size: size).y
        context.saveGState()
        context.addPath(court)
        context.clip()
        // Extend the material fill while retaining the original court projection.
        gradient(context, in: CGRect(x: -Layout.horizontalOverscan, y: nearY,
                                    width: size.width + Layout.horizontalOverscan * 2, height: backY - nearY),
                 bottom: blend(palette.court, with: palette.courtDark, amount: 0.26),
                 top: blend(palette.court, with: palette.skyBottom, amount: 0.12))

        if venue == .wimbledonGrass {
            for stripe in 0..<12 where stripe.isMultiple(of: 2) {
                let left = CGFloat(stripe) / 6 - 1
                let right = CGFloat(stripe + 1) / 6 - 1
                fill(context, points: [courtPoint(left, 0, size: size), courtPoint(right, 0, size: size),
                                       courtPoint(right, Layout.backDepth, size: size),
                                       courtPoint(left, Layout.backDepth, size: size)],
                     color: palette.courtDark.withAlphaComponent(0.16))
            }
        } else {
            // The surround and playing rectangle are two related material tones.
            fill(context, points: [courtPoint(-Layout.doublesHalfWidth, 0, size: size),
                                   courtPoint(Layout.doublesHalfWidth, 0, size: size),
                                   courtPoint(Layout.doublesHalfWidth, Layout.baselineDepth, size: size),
                                   courtPoint(-Layout.doublesHalfWidth, Layout.baselineDepth, size: size)],
                 color: palette.courtDark.withAlphaComponent(venue == .miamiHard ? 0.14 : 0.06))
        }

        // Deterministic, low-contrast material grain. Never generated per frame.
        var random = CourtNoise(seed: 9182)
        for _ in 0..<2100 {
            let depth = random.next() * Layout.backDepth
            let lateral = random.next() * 2 - 1
            let point = courtPoint(lateral, depth, size: size)
            let diameter = (1 - depth) * 0.70 + 0.25
            context.setFillColor(UIColor(white: random.next() > 0.5 ? 1 : 0, alpha: 0.052).cgColor)
            context.fillEllipse(in: CGRect(x: point.x, y: point.y, width: diameter, height: diameter * 0.5))
        }
        context.restoreGState()

        // Regulation-inspired doubles alleys, service boxes and center marks.
        // There is no full-length center stripe on a tennis court.
        let lineColor = palette.line
        for side: CGFloat in [-1, 1] {
            for lane in [Layout.doublesHalfWidth, Layout.singlesHalfWidth] {
                stroke(context, points: [courtPoint(side * lane, 0, size: size),
                                         courtPoint(side * lane, Layout.baselineDepth, size: size)],
                       color: lineColor, width: lane == Layout.doublesHalfWidth ? 2.0 : 1.65)
            }
        }
        stroke(context, points: [courtPoint(-Layout.doublesHalfWidth, Layout.baselineDepth, size: size),
                                 courtPoint(Layout.doublesHalfWidth, Layout.baselineDepth, size: size)],
               color: lineColor, width: 2)
        for depth in [Layout.nearServiceDepth, Layout.farServiceDepth] {
            stroke(context, points: [courtPoint(-Layout.singlesHalfWidth, depth, size: size),
                                     courtPoint(Layout.singlesHalfWidth, depth, size: size)],
                   color: lineColor, width: 1.8)
        }
        stroke(context, points: [courtPoint(0, Layout.nearServiceDepth, size: size),
                                 courtPoint(0, Layout.farServiceDepth, size: size)],
               color: lineColor.withAlphaComponent(0.9), width: 1.65)
        stroke(context, points: [courtPoint(0, Layout.baselineDepth, size: size),
                                 courtPoint(0, Layout.baselineDepth - 0.008, size: size)],
               color: lineColor, width: 1.6)

        // A net shadow grounds the suspended mesh without covering contact cues.
        let netDepth = Tunables.gameplayCourtNetDepthRatio
        fill(context, points: [courtPoint(-0.94, netDepth, size: size),
                               courtPoint(0.94, netDepth, size: size),
                               courtPoint(0.90, netDepth - 0.017, size: size),
                               courtPoint(-0.94, netDepth - 0.017, size: size)],
             color: UIColor(red: 0.04, green: 0.10, blue: 0.08, alpha: 0.16))
    }

    private func buildNet(size: CGSize) {
        let netDepth = Tunables.gameplayCourtNetDepthRatio
        let left = courtPoint(-0.90, netDepth, size: size)
        let right = courtPoint(0.90, netDepth, size: size)
        let height = size.height * Layout.netHeightRatio
        let sag = height * 0.13
        let middleX = size.width / 2
        let net = SKShapeNode(path: polygon([left, right,
                                            CGPoint(x: right.x, y: right.y + height),
                                            CGPoint(x: middleX, y: left.y + height - sag),
                                            CGPoint(x: left.x, y: left.y + height)]))
        net.fillColor = UIColor(red: 0.05, green: 0.11, blue: 0.09, alpha: 0.20)
        net.strokeColor = .clear
        net.zPosition = -95
        addChild(net)

        let mesh = CGMutablePath()
        let columns = max(24, Int((right.x - left.x) / 6))
        for index in 0...columns {
            let fraction = CGFloat(index) / CGFloat(columns)
            let x = left.x + (right.x - left.x) * fraction
            let dip = sin(fraction * .pi) * sag
            mesh.move(to: CGPoint(x: x, y: left.y + 1))
            mesh.addLine(to: CGPoint(x: x, y: left.y + height - dip - 1))
        }
        for row in 1...7 {
            let fraction = CGFloat(row) / 8
            mesh.move(to: CGPoint(x: left.x, y: left.y + height * fraction))
            mesh.addQuadCurve(to: CGPoint(x: right.x, y: right.y + height * fraction),
                              control: CGPoint(x: middleX, y: left.y + height * fraction - sag * fraction * 2))
        }
        let meshNode = SKShapeNode(path: mesh)
        meshNode.strokeColor = UIColor(red: 0.04, green: 0.10, blue: 0.08, alpha: 0.48)
        meshNode.lineWidth = 0.65
        meshNode.zPosition = -94
        addChild(meshNode)

        let tape = CGMutablePath()
        tape.move(to: CGPoint(x: left.x, y: left.y + height))
        tape.addQuadCurve(to: CGPoint(x: right.x, y: right.y + height),
                          control: CGPoint(x: middleX, y: left.y + height - sag * 2))
        let netBand = SKShapeNode(path: tape)
        netBand.strokeColor = venue.palette.line
        netBand.lineWidth = 3.1
        netBand.lineCap = .round
        netBand.zPosition = -92
        addChild(netBand)
        netBandRef = netBand

        for point in [left, right] {
            let post = SKShapeNode(rect: CGRect(x: point.x - 2.0, y: point.y - 2,
                                               width: 4, height: height + 6), cornerRadius: 1.5)
            post.fillColor = UIColor(red: 0.15, green: 0.24, blue: 0.20, alpha: 1)
            post.strokeColor = UIColor(red: 0.70, green: 0.74, blue: 0.64, alpha: 0.55)
            post.lineWidth = 0.8
            post.zPosition = -91
            addChild(post)
        }
        let strap = SKShapeNode(rect: CGRect(x: middleX - 1.2, y: left.y,
                                            width: 2.4, height: height - sag))
        strap.fillColor = venue.palette.line.withAlphaComponent(0.8)
        strap.strokeColor = .clear
        strap.zPosition = -91
        addChild(strap)
    }

    private func drawClubhouse(_ context: CGContext, size: CGSize, horizon: CGFloat) {
        let isGrass = venue == .wimbledonGrass
        let x = size.width * (isGrass ? 0.68 : 0.08)
        let width = size.width * 0.24
        let base = horizon + size.height * 0.026
        let height = size.height * 0.037
        context.setFillColor(UIColor(red: 0.76, green: 0.72, blue: 0.59, alpha: 1).cgColor)
        context.fill(CGRect(x: x, y: base, width: width, height: height))
        fill(context, points: [CGPoint(x: x - 5, y: base + height),
                               CGPoint(x: x + width + 5, y: base + height),
                               CGPoint(x: x + width * 0.88, y: base + height * 1.32),
                               CGPoint(x: x + width * 0.14, y: base + height * 1.32)],
             color: isGrass ? UIColor(red: 0.29, green: 0.33, blue: 0.28, alpha: 1)
                            : UIColor(red: 0.59, green: 0.34, blue: 0.24, alpha: 1))
        context.setFillColor(UIColor(red: 0.22, green: 0.33, blue: 0.29, alpha: 1).cgColor)
        for index in 0..<5 {
            context.fill(CGRect(x: x + width * (0.07 + CGFloat(index) * 0.185),
                                y: base + height * 0.25, width: width * 0.10, height: height * 0.48))
        }
    }

    private func drawPalm(_ context: CGContext, at base: CGPoint, height: CGFloat) {
        let crown = CGPoint(x: base.x + height * 0.09, y: base.y + height)
        let trunk = CGMutablePath()
        trunk.move(to: base)
        trunk.addQuadCurve(to: crown, control: CGPoint(x: base.x + height * 0.04, y: base.y + height * 0.6))
        context.addPath(trunk)
        context.setStrokeColor(UIColor(red: 0.36, green: 0.35, blue: 0.26, alpha: 0.82).cgColor)
        context.setLineWidth(2.8)
        context.strokePath()
        for index in 0..<7 {
            let angle = CGFloat(index) / 6 * .pi
            let tip = CGPoint(x: crown.x + cos(angle) * height * 0.42,
                              y: crown.y + sin(angle) * height * 0.10 - height * 0.15)
            let frond = CGMutablePath()
            frond.move(to: crown)
            frond.addQuadCurve(to: tip, control: CGPoint(x: (crown.x + tip.x) / 2,
                                                        y: crown.y + height * 0.16))
            context.addPath(frond)
            context.setStrokeColor(UIColor(red: 0.17, green: 0.33, blue: 0.26, alpha: 0.90).cgColor)
            context.setLineWidth(3)
            context.setLineCap(.round)
            context.strokePath()
        }
    }

    private func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private func fill(_ context: CGContext, points: [CGPoint], color: UIColor) {
        context.addPath(polygon(points))
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    private func stroke(_ context: CGContext, points: [CGPoint], color: UIColor, width: CGFloat) {
        guard let first = points.first else { return }
        context.beginPath()
        context.move(to: first)
        for point in points.dropFirst() { context.addLine(to: point) }
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.butt)
        context.strokePath()
    }

    private func gradient(_ context: CGContext, in rect: CGRect, bottom: UIColor, top: UIColor) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [bottom.cgColor, top.cgColor] as CFArray,
                                        locations: [0, 1]) else { return }
        context.saveGState()
        context.clip(to: rect)
        context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY),
                                   end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        context.restoreGState()
    }

    private func blend(_ first: UIColor, with second: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount, alpha: a1 + (a2 - a1) * amount)
    }

    func pulseHorizon(intensity: CGFloat = 1.0) {
        guard let netBand = netBandRef else { return }
        netBand.removeAction(forKey: "pulseNet")
        netBand.alpha = 1
        netBand.run(.sequence([.fadeAlpha(to: max(0.72, 1 - intensity * 0.18), duration: 0.06),
                               .fadeAlpha(to: 1, duration: 0.28)]), withKey: "pulseNet")
    }

    func setMomentum(tier: Int, phase: String, breaking: Bool) {
        let intensity = breaking ? 0.68 : min(1, 0.72 + CGFloat(max(0, tier)) * 0.07)
        pulseHorizon(intensity: intensity)
    }
}

/// A stable noise sequence makes material grain repeatable across launches.
private struct CourtNoise {
    var seed: UInt64
    mutating func next() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((seed >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
    }
}
