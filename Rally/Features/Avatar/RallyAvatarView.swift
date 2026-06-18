import SwiftUI

struct RallyAvatarView: View {
    let appearance: RallyAvatarAppearance
    let targetHeight: CGFloat
    var showsRacket: Bool = true
    var breathingPhase: Double = 0

    var body: some View {
        Canvas { context, size in
            var context = context
            drawAvatar(in: &context, size: size)
        }
        .frame(height: targetHeight)
        .accessibilityLabel("Rally player avatar")
    }

    // MARK: - Composite Figure

    private func drawAvatar(in context: inout GraphicsContext, size: CGSize) {
        let scale = min(size.width / 150, targetHeight / 226) * appearance.bodyScale
        let layout = RallyAvatarRebuildDefaults.CourtLayout.make(profile: appearance.bodyProfile, scale: scale)
        let centerX = size.width * 0.5
        let baseline = size.height - 18 * scale
        let idleLift = CGFloat(sin(breathingPhase)) * 1.1 * scale
        let faceScale = layout.headPathScale * 0.96

        drawGroundShadow(in: &context, centerX: centerX, baseline: baseline, scale: scale)

        let legVisualHeight = layout.legHeight * 0.74
        let trailLegVisualHeight = layout.trailLegHeight * 0.74
        drawPath(
            RallyAvatarGeometry.athleticLegPath(scale: scale, height: legVisualHeight, side: 1),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 21 * scale,
            y: layout.legY + 2 * scale,
            fill: appearance.skinColor,
            stroke: .clear,
            lineWidth: 0
        )
        drawPath(
            RallyAvatarGeometry.legHighlightPath(scale: scale, legVisualHeight: legVisualHeight),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 21 * scale,
            y: layout.legY + 2 * scale + legVisualHeight * 0.16,
            fill: .white.opacity(0.09),
            stroke: .clear,
            lineWidth: 0
        )
        drawPath(
            RallyAvatarGeometry.athleticLegPath(scale: scale, height: trailLegVisualHeight, side: -1),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: -21 * scale,
            y: layout.legY,
            fill: Color(uiColor: appearance.skinUIColor.rallyMixed(with: .black, ratio: 0.04)),
            stroke: .clear,
            lineWidth: 0
        )
        drawPath(
            RallyAvatarGeometry.legHighlightPath(scale: scale, legVisualHeight: trailLegVisualHeight),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: -21 * scale,
            y: layout.legY + trailLegVisualHeight * 0.16,
            fill: .white.opacity(0.05),
            stroke: .clear,
            lineWidth: 0
        )

        drawShoe(in: &context, centerX: centerX, baseline: baseline, x: 21 * scale, y: layout.legY - legVisualHeight * 0.51, scale: scale)
        drawShoe(
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: -21 * scale,
            y: layout.legY - trailLegVisualHeight * 0.51,
            scale: scale,
            upperUIColorOverride: appearance.shoesUIColor.rallyMixed(with: .black, ratio: 0.06),
            xFlip: true
        )

        let pelvisY = layout.torsoY - 43 * scale
        drawPath(
            RallyAvatarGeometry.athleticShortsPath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: pelvisY,
            fill: Color(uiColor: appearance.shortsUIColor.rallyBlended(withFraction: 0.10, of: appearance.topUIColor)),
            stroke: Color.white.opacity(0.04),
            lineWidth: 0.45 * scale
        )
        drawPath(
            RallyAvatarGeometry.shortsWaistbandPath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: pelvisY + 8 * scale,
            fill: Color(uiColor: appearance.shortsUIColor.rallyBlended(withFraction: 0.18, of: .white)),
            stroke: Color.white.opacity(0.08),
            lineWidth: 0.5 * scale
        )

        drawArm(
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: -36 * scale,
            y: layout.torsoY + 4 * scale,
            topWidth: 13.8,
            bottomWidth: 9.4,
            length: 62,
            rotation: 0.30,
            scale: scale,
            color: Color(uiColor: appearance.skinUIColor.rallyMixed(with: .black, ratio: 0.05))
        )
        drawArm(
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 36 * scale,
            y: layout.torsoY + 1 * scale,
            topWidth: 14.2,
            bottomWidth: 9.8,
            length: 63,
            rotation: -0.42,
            scale: scale,
            color: appearance.skinColor
        )

        drawPath(
            RallyAvatarGeometry.premiumTorsoPath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: layout.torsoY - 2 * scale,
            fill: Color(uiColor: appearance.topUIColor.rallyBlended(withFraction: 0.035, of: .white)),
            stroke: appearance.racketAccentColor.opacity(0.58),
            lineWidth: 1.55 * scale
        )
        for side in [-1.0, 1.0] {
            drawPath(
                RallyAvatarGeometry.torsoShadowPath(scale: scale, side: side),
                in: &context,
                centerX: centerX,
                baseline: baseline,
                x: 0,
                y: layout.torsoY - 2 * scale,
                fill: .black.opacity(0.11),
                stroke: .clear,
                lineWidth: 0
            )
        }
        drawPath(
            RallyAvatarGeometry.torsoHighlightPath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: layout.torsoY - 2 * scale,
            fill: .white.opacity(0.07),
            stroke: .clear,
            lineWidth: 0
        )
        drawTorsoDetails(in: &context, centerX: centerX, baseline: baseline, y: layout.torsoY, scale: scale)
        drawPath(
            RallyAvatarGeometry.shirtCollarPath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: layout.torsoY + 22 * scale,
            fill: Color(uiColor: appearance.topUIColor.rallyBlended(withFraction: 0.25, of: .black)),
            stroke: .clear,
            lineWidth: 0
        )
        drawPath(
            RallyAvatarGeometry.sleeveCapPath(scale: scale, side: -1),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: layout.torsoY + 28 * scale,
            fill: Color(uiColor: appearance.topUIColor.rallyBlended(withFraction: 0.05, of: .black)),
            stroke: .clear,
            lineWidth: 0
        )
        drawPath(
            RallyAvatarGeometry.sleeveCapPath(scale: scale, side: 1),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: layout.torsoY + 28 * scale,
            fill: Color(uiColor: appearance.topUIColor.rallyBlended(withFraction: 0.08, of: .white)),
            stroke: .clear,
            lineWidth: 0
        )

        drawNeck(in: &context, centerX: centerX, baseline: baseline, y: layout.neckY - 2 * scale + idleLift * 0.3, scale: faceScale)
        drawBackHair(in: &context, centerX: centerX, baseline: baseline, layout: layout, scale: scale, idleLift: idleLift)
        drawPath(
            RallyAvatarGeometry.earPath(side: -1, scale: faceScale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: layout.headY + idleLift,
            fill: appearance.skinColor,
            stroke: Color.black.opacity(0.06),
            lineWidth: 0.35 * scale
        )
        drawPath(
            RallyAvatarGeometry.earPath(side: 1, scale: faceScale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: layout.headY + idleLift,
            fill: appearance.skinColor,
            stroke: Color.black.opacity(0.06),
            lineWidth: 0.35 * scale
        )
        drawPath(
            RallyAvatarGeometry.premiumHeadPath(scale: faceScale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: layout.headY + idleLift,
            fill: appearance.skinColor,
            stroke: Color.black.opacity(0.10),
            lineWidth: 0.55 * scale
        )
        drawHairAndHeadwear(in: &context, centerX: centerX, baseline: baseline, layout: layout, scale: scale, idleLift: idleLift)
        drawFace(in: &context, centerX: centerX, baseline: baseline, headY: layout.headY + idleLift, scale: faceScale)

        if showsRacket {
            drawRacket(in: &context, centerX: centerX, baseline: baseline, x: 55 * scale, y: layout.torsoY - 4 * scale, scale: scale)
            drawHand(in: &context, centerX: centerX, baseline: baseline, x: 54 * scale, y: layout.torsoY - 27 * scale, scale: scale, color: appearance.skinColor)
        }
        drawHand(in: &context, centerX: centerX, baseline: baseline, x: -42 * scale, y: layout.torsoY - 29 * scale, scale: scale, color: Color(uiColor: appearance.skinUIColor.rallyBlended(withFraction: 0.035, of: .white)).opacity(0.75))
    }

    private func drawBackHair(
        in context: inout GraphicsContext,
        centerX: CGFloat,
        baseline: CGFloat,
        layout: RallyAvatarRebuildDefaults.CourtLayout,
        scale: CGFloat,
        idleLift: CGFloat
    ) {
        guard appearance.hairStyle != .bald, appearance.hairStyle != .cap else { return }
        let hairScale = layout.headPathScale * 0.96
        drawPath(
            RallyAvatarGeometry.premiumBackHairPath(scale: hairScale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: layout.headY + idleLift,
            fill: Color(uiColor: appearance.hairUIColor.rallyBlended(withFraction: 0.08, of: .white)),
            stroke: .clear,
            lineWidth: 0
        )
    }

    private func drawPath(
        _ cgPath: CGPath,
        in context: inout GraphicsContext,
        centerX: CGFloat,
        baseline: CGFloat,
        x: CGFloat,
        y: CGFloat,
        fill: Color,
        stroke: Color,
        lineWidth: CGFloat
    ) {
        var transform = CGAffineTransform(translationX: centerX + x, y: baseline - y)
            .scaledBy(x: 1, y: -1)
        guard let transformedPath = cgPath.copy(using: &transform) else { return }
        let path = Path(transformedPath)
        context.fill(path, with: .color(fill))
        if lineWidth > 0 {
            context.stroke(path, with: .color(stroke), lineWidth: lineWidth)
        }
    }

    private func point(centerX: CGFloat, baseline: CGFloat, x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: centerX + x, y: baseline - y)
    }

    private func drawGroundShadow(in context: inout GraphicsContext, centerX: CGFloat, baseline: CGFloat, scale: CGFloat) {
        let rect = CGRect(x: centerX - 60 * scale, y: baseline - 8 * scale, width: 120 * scale, height: 14 * scale)
        context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.30)))
    }

    private func drawArm(
        in context: inout GraphicsContext,
        centerX: CGFloat,
        baseline: CGFloat,
        x: CGFloat,
        y: CGFloat,
        topWidth: CGFloat,
        bottomWidth: CGFloat,
        length: CGFloat,
        rotation: CGFloat,
        scale: CGFloat,
        color: Color
    ) {
        var transform = CGAffineTransform(translationX: centerX + x, y: baseline - y)
            .rotated(by: rotation)
            .scaledBy(x: 1, y: -1)
        guard let transformedPath = RallyAvatarGeometry.armPath(
            scale: scale,
            topWidth: topWidth,
            bottomWidth: bottomWidth,
            length: length
        ).copy(using: &transform) else { return }
        context.fill(Path(transformedPath), with: .color(color))
    }

    private func drawShoe(
        in context: inout GraphicsContext,
        centerX: CGFloat,
        baseline: CGFloat,
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat,
        upperUIColorOverride: UIColor? = nil,
        xFlip: Bool = false
    ) {
        let upperUIColor = upperUIColorOverride ?? appearance.shoesUIColor
        let upper = Color(uiColor: upperUIColor)
        let accent = appearance.shoesAccentColor

        drawPath(
            RallyAvatarGeometry.shoeSolePath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: x,
            y: y - 4.8 * scale,
            fill: Color(uiColor: upperUIColor.rallyMixed(with: .black, ratio: 0.42)),
            stroke: .clear,
            lineWidth: 0
        )
        drawMirroredPath(
            RallyAvatarGeometry.shoeBodyPath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: x,
            y: y,
            xFlip: xFlip,
            fill: upper,
            stroke: accent.opacity(0.55),
            lineWidth: 1.2 * scale
        )
        drawMirroredPath(
            RallyAvatarGeometry.shoeStripePath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: x,
            y: y,
            xFlip: xFlip,
            fill: accent.opacity(0.82),
            stroke: .clear,
            lineWidth: 0
        )
        drawMirroredPath(
            RallyAvatarGeometry.shoeTonguePath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: x,
            y: y,
            xFlip: xFlip,
            fill: Color(uiColor: upperUIColor.rallyBlended(withFraction: 0.20, of: .white)),
            stroke: .clear,
            lineWidth: 0
        )
        drawMirroredPath(
            RallyAvatarGeometry.shoeLacePath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: x,
            y: y,
            xFlip: xFlip,
            fill: .white.opacity(0.72),
            stroke: .clear,
            lineWidth: 0
        )
    }

    private func drawMirroredPath(
        _ cgPath: CGPath,
        in context: inout GraphicsContext,
        centerX: CGFloat,
        baseline: CGFloat,
        x: CGFloat,
        y: CGFloat,
        xFlip: Bool,
        fill: Color,
        stroke: Color,
        lineWidth: CGFloat
    ) {
        var transform = CGAffineTransform(translationX: centerX + x, y: baseline - y)
            .scaledBy(x: xFlip ? -1 : 1, y: -1)
        guard let transformedPath = cgPath.copy(using: &transform) else { return }
        let path = Path(transformedPath)
        context.fill(path, with: .color(fill))
        if lineWidth > 0 {
            context.stroke(path, with: .color(stroke), lineWidth: lineWidth)
        }
    }

    private func drawNeck(in context: inout GraphicsContext, centerX: CGFloat, baseline: CGFloat, y: CGFloat, scale: CGFloat) {
        let size = RallyAvatarGeometry.neckSize(scale: scale)
        let rect = CGRect(x: centerX - size.width * 0.5, y: baseline - y - size.height * 0.5, width: size.width, height: size.height)
        context.fill(Path(roundedRect: rect, cornerRadius: 4 * scale), with: .color(appearance.skinColor))

        let shadowHeight = max(2.0 * scale, 1.6)
        let shadowRect = CGRect(x: rect.minX + 1.5 * scale, y: rect.minY, width: rect.width - 3.0 * scale, height: shadowHeight)
        context.fill(
            Path(roundedRect: shadowRect, cornerRadius: shadowHeight * 0.5),
            with: .color(Color(uiColor: appearance.skinUIColor.rallyBlended(withFraction: 0.14, of: .black)).opacity(0.42))
        )
    }

    private func drawTorsoDetails(in context: inout GraphicsContext, centerX: CGFloat, baseline: CGFloat, y: CGFloat, scale: CGFloat) {
        let chest = CGRect(x: centerX - 15 * scale, y: baseline - y - 17 * scale, width: 30 * scale, height: 5 * scale)
        context.fill(Path(roundedRect: chest, cornerRadius: 2.5 * scale), with: .color(.white.opacity(0.20)))

        let accent = CGRect(x: centerX - 14 * scale, y: baseline - y - 28 * scale, width: 28 * scale, height: 4 * scale)
        context.fill(Path(roundedRect: accent, cornerRadius: 2 * scale), with: .color(appearance.racketAccentColor.opacity(0.90)))
    }

    private func drawHairAndHeadwear(
        in context: inout GraphicsContext,
        centerX: CGFloat,
        baseline: CGFloat,
        layout: RallyAvatarRebuildDefaults.CourtLayout,
        scale: CGFloat,
        idleLift: CGFloat
    ) {
        // IDENTITY LOCK: hair shares the head's exact anchor + scale. The head,
        // ears, and face are drawn at (headY, faceScale = headPathScale * 0.96);
        // the hair paths are authored in the same local frame (crown at headTop,
        // fringe at browY), so co-anchoring is what keeps the crown attached and
        // the fringe off the eyes. Any per-part Y nudge or scale split re-opens
        // the "disconnected hair / black over the face" bug. Mirrors GameScene.
        let hairScale = layout.headPathScale * 0.96
        let headY = layout.headY + idleLift
        // Front hair gets a small lift (in head-scale units, so Home and GameScene
        // match) to raise the authored fringe off the eyes without detaching the
        // crown — the back hair stays at headY to keep the scalp filled behind it.
        let hairFringeLift = RallyAvatarGeometry.hairFringeLift(scale: hairScale)
        let hairY = headY + hairFringeLift
        let shouldDrawHair = appearance.hairStyle != .bald && appearance.hairStyle != .cap

        if shouldDrawHair {
            drawPath(
                RallyAvatarGeometry.premiumHairPath(scale: hairScale),
                in: &context,
                centerX: centerX,
                baseline: baseline,
                x: 0,
                y: hairY,
                fill: appearance.hairColor,
                stroke: Color.white.opacity(0.06),
                lineWidth: 0.5 * scale
            )
            drawPath(
                RallyAvatarGeometry.hairHighlightPath(scale: hairScale),
                in: &context,
                centerX: centerX,
                baseline: baseline,
                x: 0,
                y: hairY,
                fill: .clear,
                stroke: Color(red: 0.22, green: 0.22, blue: 0.25).opacity(0.58),
                lineWidth: 1.25 * scale
            )
        }

        switch appearance.hairStyle {
        case .headband:
            drawPath(
                RallyAvatarGeometry.tiedHeadbandPath(scale: hairScale),
                in: &context,
                centerX: centerX,
                baseline: baseline,
                x: 0,
                y: headY + 1.5 * scale,
                fill: appearance.headbandColor,
                stroke: Color.black.opacity(0.10),
                lineWidth: 0.45 * scale
            )
            drawPath(
                RallyAvatarGeometry.tiedHeadbandTailsPath(scale: hairScale),
                in: &context,
                centerX: centerX,
                baseline: baseline,
                x: 0,
                y: headY + 1.5 * scale,
                fill: appearance.headbandColor.opacity(0.95),
                stroke: Color.black.opacity(0.08),
                lineWidth: 0.35 * scale
            )
        case .cap:
            drawPath(
                RallyAvatarGeometry.premiumBackHairPath(scale: hairScale * 0.76),
                in: &context,
                centerX: centerX,
                baseline: baseline,
                x: 0,
                y: layout.headY + idleLift * 0.42 - 1.0 * scale,
                fill: appearance.hairColor.opacity(0.92),
                stroke: .clear,
                lineWidth: 0
            )
            drawPath(
                RallyAvatarGeometry.courtCapCrownPath(scale: hairScale),
                in: &context,
                centerX: centerX,
                baseline: baseline,
                x: 0,
                y: headY + 1.2 * scale,
                fill: appearance.headbandColor,
                stroke: Color.white.opacity(0.16),
                lineWidth: 0.55 * scale
            )
            drawPath(
                RallyAvatarGeometry.courtCapBrimPath(scale: hairScale),
                in: &context,
                centerX: centerX,
                baseline: baseline,
                x: 0,
                y: headY + 1.2 * scale,
                fill: Color(uiColor: appearance.headbandUIColor.rallyMixed(with: .black, ratio: 0.10)),
                stroke: Color.black.opacity(0.12),
                lineWidth: 0.42 * scale
            )
        default:
            break
        }
    }

    private func drawFace(in context: inout GraphicsContext, centerX: CGFloat, baseline: CGFloat, headY: CGFloat, scale: CGFloat) {
        let faceInk = Color(red: 0.11, green: 0.11, blue: 0.118)
        for side in [-1.0, 1.0] {
            drawPath(
                RallyAvatarGeometry.eyePath(side: side, scale: scale),
                in: &context,
                centerX: centerX,
                baseline: baseline,
                x: 0,
                y: headY,
                fill: faceInk,
                stroke: Color.white.opacity(0.10),
                lineWidth: 0.35 * scale
            )
            drawPath(
                RallyAvatarGeometry.eyeSpecularPath(side: side, scale: scale),
                in: &context,
                centerX: centerX,
                baseline: baseline,
                x: 0,
                y: headY,
                fill: .white.opacity(0.76),
                stroke: .clear,
                lineWidth: 0
            )
            drawPath(
                RallyAvatarGeometry.browPath(side: side, scale: scale),
                in: &context,
                centerX: centerX,
                baseline: baseline,
                x: 0,
                y: headY,
                fill: appearance.hairColor.opacity(0.94),
                stroke: .clear,
                lineWidth: 0
            )
        }

        drawPath(
            RallyAvatarGeometry.nosePath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: headY,
            fill: .clear,
            stroke: Color(uiColor: appearance.skinUIColor.rallyBlended(withFraction: 0.10, of: .black)).opacity(0.42),
            lineWidth: max(1.22 * scale, 0.95)
        )

        drawPath(
            RallyAvatarGeometry.friendlyMouthPath(scale: scale),
            in: &context,
            centerX: centerX,
            baseline: baseline,
            x: 0,
            y: headY + RallyAvatarGeometry.mouthCenterY(scale: scale),
            fill: .clear,
            stroke: Color.black.opacity(0.58),
            lineWidth: max(1.12 * scale, 0.92)
        )
    }

    private func drawHand(in context: inout GraphicsContext, centerX: CGFloat, baseline: CGFloat, x: CGFloat, y: CGFloat, scale: CGFloat, color: Color) {
        let radius = RallyAvatarGeometry.handRadius(scale: scale)
        let rect = CGRect(x: centerX + x - radius, y: baseline - y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color))
        context.stroke(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.08)), lineWidth: 0.8 * scale)
    }

    private func drawRacket(in context: inout GraphicsContext, centerX: CGFloat, baseline: CGFloat, x: CGFloat, y: CGFloat, scale: CGFloat) {
        let headRect = CGRect(x: centerX + x - 14 * scale, y: baseline - y - 41 * scale, width: 28 * scale, height: 42 * scale)
        let headPath = Path(ellipseIn: headRect)
        context.fill(headPath, with: .color(appearance.racketAccentColor.opacity(0.08)))
        context.stroke(headPath, with: .color(appearance.racketColor.opacity(0.92)), lineWidth: 2.4 * scale)

        for index in -2...2 {
            let vertical = Path { path in
                let offset = CGFloat(index) * 4 * scale
                path.move(to: CGPoint(x: headRect.midX + offset, y: headRect.minY + 6 * scale))
                path.addLine(to: CGPoint(x: headRect.midX + offset, y: headRect.maxY - 6 * scale))
            }
            context.stroke(vertical, with: .color(appearance.racketAccentColor.opacity(0.34)), lineWidth: 0.7 * scale)
        }

        let handle = Path { path in
            path.move(to: CGPoint(x: headRect.midX - 1.5 * scale, y: headRect.maxY - 1 * scale))
            path.addLine(to: CGPoint(x: centerX + x - 9 * scale, y: baseline - y + 38 * scale))
            path.addLine(to: CGPoint(x: centerX + x - 3 * scale, y: baseline - y + 40 * scale))
            path.addLine(to: CGPoint(x: headRect.midX + 1.5 * scale, y: headRect.maxY - 1 * scale))
        }
        context.fill(handle, with: .color(appearance.racketColor.opacity(0.90)))
    }
}

private extension UIColor {
    func rallyMixed(with other: UIColor, ratio: CGFloat) -> UIColor {
        rallyBlended(withFraction: ratio, of: other)
    }

    func rallyBlended(withFraction fraction: CGFloat, of other: UIColor) -> UIColor {
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let amount = min(1, max(0, fraction))
        return UIColor(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount,
            alpha: a1 + (a2 - a1) * amount
        )
    }
}
