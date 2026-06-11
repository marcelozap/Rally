import UIKit
import SpriteKit
import CoreGraphics

// MARK: - RallyAvatarPartRenderer  (Anime Cel-Shade Edition)
//
// Renders avatar body parts in a "lowkey anime" style:
//   • Hard 2-tone cel shading — no smooth gradients, sharp shadow edge at ~40 %
//   • Thick ink outlines handled by SKShapeNode.strokeColor (see attachRenderedSprite)
//   • Head texture bakes in anime face features: large eyes, iris gradient,
//     specular dots, small nose, simple mouth arc, optional cheek blush
//   • Saturated, slightly stylised colour palette
//   • Hair rendered as a separate cel-shade layer with a spiky / swept silhouette
//
// Coordinate contract (unchanged from previous version)
// ──────────────────────────────────────────────────────
//   All CGPaths are centred at origin in SpriteKit y-up space.
//   UIKit y-down rendering flips them; SpriteKit texture y-flip restores orientation.
//   tx = -bbox.minX + padding,  ty = -bbox.minY + padding

enum RallyAvatarPartRenderer {

    // MARK: - Cache

    private static var cache: [String: SKTexture] = [:]
    static func invalidate() { cache.removeAll() }

    // MARK: - Anime palette helpers

    /// Returns the hard cel-shadow colour for a given base.
    private static func shadow(_ base: UIColor, strength: CGFloat = 0.28) -> UIColor {
        base.mix(with: .black, t: strength)
    }
    /// Returns the hard cel-highlight colour for a given base.
    private static func highlight(_ base: UIColor, strength: CGFloat = 0.50) -> UIColor {
        base.mix(with: .white, t: strength)
    }

    // MARK: - Public entry points

    static func torsoTexture(shirtColor: UIColor, accentColor: UIColor, scale: CGFloat) -> SKTexture {
        let key = "torso-anime-\(shirtColor.hexKey)-\(accentColor.hexKey)-\(scale)"
        if let t = cache[key] { return t }
        let path = RallyAvatarGeometry.premiumTorsoPath(scale: scale)
        let tex = render(path: path, padding: 4) { ctx, size, tx, ty in
            drawTorso(ctx: ctx, path: path, tx: tx, ty: ty, size: size,
                      shirtColor: shirtColor, accentColor: accentColor, scale: scale)
        }
        cache[key] = tex; return tex
    }

    static func shortsTexture(shortsColor: UIColor, scale: CGFloat) -> SKTexture {
        let key = "shorts-anime-\(shortsColor.hexKey)-\(scale)"
        if let t = cache[key] { return t }
        let path = RallyAvatarGeometry.athleticShortsPath(scale: scale)
        let tex = render(path: path, padding: 3) { ctx, size, tx, ty in
            drawShorts(ctx: ctx, path: path, tx: tx, ty: ty, size: size,
                       color: shortsColor, scale: scale)
        }
        cache[key] = tex; return tex
    }

    static func armTexture(skinColor: UIColor, scale: CGFloat,
                            topWidth: CGFloat, bottomWidth: CGFloat, length: CGFloat) -> SKTexture {
        let key = "arm-anime-\(skinColor.hexKey)-\(scale)-\(topWidth)-\(bottomWidth)-\(length)"
        if let t = cache[key] { return t }
        let path = RallyAvatarGeometry.armPath(scale: scale, topWidth: topWidth,
                                                bottomWidth: bottomWidth, length: length)
        let tex = render(path: path, padding: 3) { ctx, size, tx, ty in
            drawArm(ctx: ctx, path: path, tx: tx, ty: ty, size: size,
                    skinColor: skinColor, scale: scale)
        }
        cache[key] = tex; return tex
    }

    /// Head texture — bakes face features (eyes, brows, nose, mouth, blush) directly in.
    static func headTexture(skinColor: UIColor, scale: CGFloat,
                             eyeColor: UIColor = UIColor(red: 0.22, green: 0.52, blue: 0.94, alpha: 1),
                             hairColor: UIColor = UIColor(red: 0.05, green: 0.04, blue: 0.06, alpha: 1)) -> SKTexture {
        let key = "head-anime-\(skinColor.hexKey)-\(eyeColor.hexKey)-\(hairColor.hexKey)-\(scale)"
        if let t = cache[key] { return t }
        let path = RallyAvatarGeometry.premiumHeadPath(scale: scale)
        let tex = render(path: path, padding: 6) { ctx, size, tx, ty in
            drawHead(ctx: ctx, path: path, tx: tx, ty: ty, size: size,
                     skinColor: skinColor, eyeColor: eyeColor, hairColor: hairColor, scale: scale)
        }
        cache[key] = tex; return tex
    }

    static func legTexture(skinColor: UIColor, scale: CGFloat,
                            legVisualHeight: CGFloat, side: CGFloat) -> SKTexture {
        let key = "leg-anime-\(skinColor.hexKey)-\(scale)-\(legVisualHeight)-\(side)"
        if let t = cache[key] { return t }
        let path = RallyAvatarGeometry.athleticLegPath(scale: scale,
                                                        height: legVisualHeight, side: side)
        let tex = render(path: path, padding: 3) { ctx, size, tx, ty in
            drawLeg(ctx: ctx, path: path, tx: tx, ty: ty, size: size,
                    skinColor: skinColor, scale: scale)
        }
        cache[key] = tex; return tex
    }

    // MARK: - Generic render helper

    private static func render(
        path: CGPath,
        padding: CGFloat,
        draw: (CGContext, CGSize, CGFloat, CGFloat) -> Void
    ) -> SKTexture {
        let bbox   = path.boundingBox
        let canvasW = max(1, bbox.width  + padding * 2)
        let canvasH = max(1, bbox.height + padding * 2)
        let canvasSize = CGSize(width: canvasW, height: canvasH)
        let tx = -bbox.minX + padding
        let ty = -bbox.minY + padding

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let image = renderer.image { ctx in draw(ctx.cgContext, canvasSize, tx, ty) }
        return SKTexture(image: image)
    }

    // MARK: - Cel-shade fill helper
    //
    // Fills `path` with base colour then draws a hard shadow band on the
    // right (shadow) side and a hard highlight strip on the left (lit) side.
    //
    // shadowFrac  — width of shadow zone as fraction of bounding-box width
    // highlightFrac — width of highlight strip as fraction of bbox width

    private static func celFill(
        ctx: CGContext,
        path: CGPath,
        tx: CGFloat, ty: CGFloat,
        size: CGSize,
        base: UIColor,
        shadowFrac: CGFloat = 0.38,
        highlightFrac: CGFloat = 0.16
    ) {
        let bbox = path.boundingBox
        ctx.saveGState()
        ctx.translateBy(x: tx, y: ty)
        ctx.addPath(path); ctx.clip()

        // 1. Base fill
        base.setFill()
        ctx.fill(CGRect(x: -tx, y: -ty, width: size.width, height: size.height))

        // 2. Shadow band — right side (hard edge)
        let shadowX = bbox.maxX - bbox.width * shadowFrac
        let shadowRect = CGRect(x: shadowX, y: bbox.minY, width: bbox.width * shadowFrac, height: bbox.height)
        shadow(base).setFill()
        ctx.fill(shadowRect)

        // 3. Highlight strip — left side (hard edge)
        let hlRect = CGRect(x: bbox.minX, y: bbox.minY, width: bbox.width * highlightFrac, height: bbox.height)
        highlight(base, strength: 0.38).withAlphaComponent(0.80).setFill()
        ctx.fill(hlRect)

        ctx.restoreGState()
    }

    // MARK: - Part draw implementations

    // ── Torso ───────────────────────────────────────────────────────────────

    private static func drawTorso(
        ctx: CGContext, path: CGPath, tx: CGFloat, ty: CGFloat, size: CGSize,
        shirtColor: UIColor, accentColor: UIColor, scale: CGFloat
    ) {
        celFill(ctx: ctx, path: path, tx: tx, ty: ty, size: size, base: shirtColor,
                shadowFrac: 0.35, highlightFrac: 0.14)

        // Accent side panel — thin strip on lit side
        let bbox = path.boundingBox
        let panelW = bbox.width * 0.10
        ctx.saveGState()
        ctx.translateBy(x: tx, y: ty)
        ctx.addPath(path); ctx.clip()
        let panelRect = CGRect(x: bbox.minX, y: bbox.minY, width: panelW, height: bbox.height)
        accentColor.withAlphaComponent(0.70).setFill()
        ctx.fill(panelRect)
        ctx.restoreGState()
    }

    // ── Shorts ──────────────────────────────────────────────────────────────

    private static func drawShorts(
        ctx: CGContext, path: CGPath, tx: CGFloat, ty: CGFloat, size: CGSize,
        color: UIColor, scale: CGFloat
    ) {
        celFill(ctx: ctx, path: path, tx: tx, ty: ty, size: size, base: color,
                shadowFrac: 0.40, highlightFrac: 0.12)
    }

    // ── Arm ─────────────────────────────────────────────────────────────────

    private static func drawArm(
        ctx: CGContext, path: CGPath, tx: CGFloat, ty: CGFloat, size: CGSize,
        skinColor: UIColor, scale: CGFloat
    ) {
        celFill(ctx: ctx, path: path, tx: tx, ty: ty, size: size, base: skinColor,
                shadowFrac: 0.42, highlightFrac: 0.18)
    }

    // ── Head (with anime face features) ─────────────────────────────────────

    private static func drawHead(
        ctx: CGContext, path: CGPath, tx: CGFloat, ty: CGFloat, size: CGSize,
        skinColor: UIColor, eyeColor: UIColor, hairColor: UIColor, scale: CGFloat
    ) {
        let g = RallyAvatarGeometry.self

        // 1. Cel-shade skin base
        celFill(ctx: ctx, path: path, tx: tx, ty: ty, size: size, base: skinColor,
                shadowFrac: 0.36, highlightFrac: 0.14)

        ctx.saveGState()
        ctx.translateBy(x: tx, y: ty)

        // 2. Cheek blush — anime pink flush on cheekbones
        let blushColor = UIColor(red: 1.0, green: 0.58, blue: 0.65, alpha: 0.30)
        for side: CGFloat in [-1, 1] {
            let cx = side * g.headHalfWidth(scale: scale) * 0.55
            let cy = g.eyeCenterY(scale: scale) - g.headHeight * 0.08 * scale
            let blushW = g.headWidth * 0.18 * scale
            let blushH = blushW * 0.45
            blushColor.setFill()
            ctx.fillEllipse(in: CGRect(x: cx - blushW * 0.5, y: cy - blushH * 0.5,
                                       width: blushW, height: blushH))
        }

        // 3. Eyes — big anime style for each side
        for side: CGFloat in [-1, 1] {
            drawAnimeEye(ctx: ctx, side: side, scale: scale, eyeColor: eyeColor)
        }

        // 4. Brows
        let inkColor = UIColor(red: 0.11, green: 0.09, blue: 0.10, alpha: 1)
        for side: CGFloat in [-1, 1] {
            ctx.addPath(g.browPath(side: side, scale: scale))
            inkColor.setFill()
            ctx.fillPath()
        }

        // 5. Nose — simple small dot (anime style)
        let noseY = g.noseCenterY(scale: scale)
        let dotR = max(1.0, 1.1 * scale)
        skinColor.mix(with: .black, t: 0.30).setFill()
        ctx.fillEllipse(in: CGRect(x: -dotR * 0.5 + 0.5 * scale, y: noseY - dotR * 0.5,
                                   width: dotR, height: dotR))

        // 6. Mouth — simple friendly arc
        let mouthPath = g.friendlyMouthPath(scale: scale)
        ctx.addPath(mouthPath)
        ctx.setStrokeColor(inkColor.cgColor)
        ctx.setLineWidth(max(1.0, 1.2 * scale))
        ctx.setLineCap(.round)
        ctx.strokePath()

        ctx.restoreGState()
    }

    /// Draws one anime eye centred at RallyAvatarGeometry eye position.
    private static func drawAnimeEye(ctx: CGContext, side: CGFloat, scale: CGFloat, eyeColor: UIColor) {
        let g = RallyAvatarGeometry.self
        let cx = g.eyeCenterX(side: side, scale: scale)
        let cy = g.eyeCenterY(scale: scale)
        let ew = g.headWidth * 0.135 * scale   // wider than before
        let eh = g.headHeight * 0.155 * scale  // taller — anime eyes

        let eyeRect = CGRect(x: cx - ew * 0.5, y: cy - eh * 0.5, width: ew, height: eh)
        let cornerW = ew * 0.35
        let cornerH = eh * 0.40

        // White of eye
        ctx.saveGState()
        let eyePath = CGMutablePath()
        eyePath.addRoundedRect(in: eyeRect, cornerWidth: cornerW, cornerHeight: cornerH)
        UIColor.white.setFill()
        ctx.addPath(eyePath)
        ctx.fillPath()

        // Coloured iris — top 65 % of eye
        let irisH = eh * 0.68
        let irisRect = CGRect(x: cx - ew * 0.5, y: cy - eh * 0.5, width: ew, height: irisH)
        ctx.saveGState()
        ctx.addPath(eyePath); ctx.clip()
        eyeColor.setFill()
        ctx.fill(irisRect)
        // Iris top highlight (lighter strip at very top)
        eyeColor.mix(with: .white, t: 0.55).withAlphaComponent(0.85).setFill()
        ctx.fill(CGRect(x: cx - ew * 0.5, y: cy + irisH * 0.20,
                        width: ew, height: irisH * 0.22))
        // Iris lower dark band
        eyeColor.mix(with: .black, t: 0.30).setFill()
        ctx.fill(CGRect(x: cx - ew * 0.5, y: cy - eh * 0.50,
                        width: ew, height: irisH * 0.28))
        ctx.restoreGState()

        // Pupil — dark oval
        let pupilW = ew * 0.34
        let pupilH = irisH * 0.52
        UIColor(red: 0.08, green: 0.06, blue: 0.08, alpha: 1).setFill()
        ctx.fillEllipse(in: CGRect(x: cx - pupilW * 0.5, y: cy - pupilH * 0.5,
                                   width: pupilW, height: pupilH))

        // Specular dot — upper-left
        UIColor.white.setFill()
        let spec1W = ew * 0.18
        ctx.fillEllipse(in: CGRect(x: cx - ew * 0.22, y: cy + pupilH * 0.18,
                                   width: spec1W, height: spec1W * 0.85))
        // Small secondary specular
        let spec2W = spec1W * 0.48
        ctx.fillEllipse(in: CGRect(x: cx + ew * 0.08, y: cy - pupilH * 0.10,
                                   width: spec2W, height: spec2W))

        // Top lash line — thick dark arc above iris
        let inkColor = UIColor(red: 0.09, green: 0.07, blue: 0.09, alpha: 1)
        let lashPath = CGMutablePath()
        lashPath.addRoundedRect(in: CGRect(x: cx - ew * 0.52,
                                           y: cy + eh * 0.28,
                                           width: ew * 1.04,
                                           height: eh * 0.22),
                                cornerWidth: ew * 0.20, cornerHeight: eh * 0.10)
        ctx.addPath(lashPath)
        inkColor.setFill()
        ctx.fillPath()

        // Outline the eye shape
        ctx.addPath(eyePath)
        ctx.setStrokeColor(inkColor.cgColor)
        ctx.setLineWidth(max(1.2, 1.1 * scale))
        ctx.strokePath()

        ctx.restoreGState()
    }

    // ── Leg ─────────────────────────────────────────────────────────────────

    private static func drawLeg(
        ctx: CGContext, path: CGPath, tx: CGFloat, ty: CGFloat, size: CGSize,
        skinColor: UIColor, scale: CGFloat
    ) {
        celFill(ctx: ctx, path: path, tx: tx, ty: ty, size: size, base: skinColor,
                shadowFrac: 0.40, highlightFrac: 0.16)
    }
}

// MARK: - SKShapeNode → anime sprite upgrade

extension SKShapeNode {
    /// Replaces this node's fill with a cel-shaded SKSpriteNode child.
    /// Pass `outlineColor` to keep an ink outline (set strokeColor); pass nil to hide stroke.
    @discardableResult
    func attachRenderedSprite(
        _ texture: SKTexture,
        zPos: CGFloat = 0,
        outlineColor: UIColor? = UIColor(red: 0.10, green: 0.08, blue: 0.10, alpha: 0.90),
        outlineWidth: CGFloat = 1.4
    ) -> SKSpriteNode {
        fillColor = .clear
        if let ink = outlineColor {
            strokeColor = ink
            lineWidth   = outlineWidth
        } else {
            strokeColor = .clear
        }
        let sprite = SKSpriteNode(texture: texture)
        sprite.zPosition = zPos
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.yScale = -1   // SpriteKit y-flip correction
        addChild(sprite)
        return sprite
    }
}

// MARK: - UIColor helpers

private extension UIColor {
    var hexKey: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }

    func mix(with other: UIColor, t: CGFloat) -> UIColor {
        let c = min(max(t, 0), 1)
        var r1: CGFloat=0, g1: CGFloat=0, b1: CGFloat=0, a1: CGFloat=0
        var r2: CGFloat=0, g2: CGFloat=0, b2: CGFloat=0, a2: CGFloat=0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red:   r1*(1-c) + r2*c,
                       green: g1*(1-c) + g2*c,
                       blue:  b1*(1-c) + b2*c,
                       alpha: a1*(1-c) + a2*c)
    }
}

extension CGContext {
    func fillEllipse(in rect: CGRect) {
        addEllipse(in: rect)
        fillPath()
    }
}
