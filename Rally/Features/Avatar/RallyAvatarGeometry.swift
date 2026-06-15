import CoreGraphics

// MARK: - Safe rounded-rect helper
// CGPathAddRoundedRect asserts if cornerWidth/Height > half the dimension.
// This extension clamps the radii so callers never have to think about it.
private extension CGMutablePath {
    func addSafeRoundedRect(in rect: CGRect, cornerWidth cw: CGFloat, cornerHeight ch: CGFloat) {
        let safeCW = min(cw, abs(rect.width)  * 0.5)
        let safeCH = min(ch, abs(rect.height) * 0.5)
        addRoundedRect(in: rect, cornerWidth: safeCW, cornerHeight: safeCH)
    }
}

enum RallyAvatarGeometry {
    // MARK: - Head & Hair

    static let headHeight: CGFloat = 41
    static let headWidth: CGFloat = headHeight * 0.78
    static let hairColorHex = "#0A0A0C"
    static let hairHighlightHex = "#2A2A30"
    static let faceInkHex = "#1C1C1E"
    static let eyeCenterXRatio: CGFloat = 0.20
    static let eyeCenterFromTopRatio: CGFloat = 0.535
    static let browAboveEyeRatio: CGFloat = 0.135
    static let noseFromTopRatio: CGFloat = 0.62
    static let mouthFromTopRatio: CGFloat = 0.755
    static let mouthWidthRatio: CGFloat = 0.34
    static let shoulderWidening: CGFloat = 1.30
    static let jawNarrowing: CGFloat = 0.12
    static let minGameplayEyeWidth: CGFloat = 4.8
    static let minGameplayEyeHeight: CGFloat = 3.8
    static let minGameplayBrowWidth: CGFloat = 6.4
    static let minGameplayMouthHalfWidth: CGFloat = 7.6
    static let minGameplayMouthCurve: CGFloat = 0.62

    static func headTop(scale: CGFloat) -> CGFloat { headHeight * 0.5 * scale }
    static func headBottom(scale: CGFloat) -> CGFloat { -headHeight * 0.5 * scale }
    static func headHalfWidth(scale: CGFloat) -> CGFloat { headWidth * 0.5 * scale }

    static func eyeCenterY(scale: CGFloat) -> CGFloat {
        headTop(scale: scale) - headHeight * eyeCenterFromTopRatio * scale
    }

    static func eyeCenterX(side: CGFloat, scale: CGFloat) -> CGFloat {
        side * headWidth * eyeCenterXRatio * scale
    }

    static func browCenterY(scale: CGFloat) -> CGFloat {
        eyeCenterY(scale: scale) + headHeight * browAboveEyeRatio * scale
    }

    static func noseCenterY(scale: CGFloat) -> CGFloat {
        headTop(scale: scale) - headHeight * noseFromTopRatio * scale
    }

    static func mouthCenterY(scale: CGFloat) -> CGFloat {
        headTop(scale: scale) - headHeight * mouthFromTopRatio * scale
    }

    static func neckSize(scale: CGFloat) -> CGSize {
        CGSize(width: headWidth * 0.36 * scale, height: 17 * scale)
    }

    /// Small vertical lift applied to the FRONT hair. The hair path is authored
    /// around the head ellipse, so this must stay subtle: too high reads bald /
    /// disconnected, too low covers the face. Both renderers call this value.
    static func hairFringeLift(scale: CGFloat) -> CGFloat { 1.15 * scale }

    static func handRadius(scale: CGFloat, armThickness: CGFloat = 13.2) -> CGFloat {
        armThickness * 0.58 * scale
    }

    static func premiumHeadPath(scale: CGFloat) -> CGPath {
        let top = headTop(scale: scale)
        let bottom = headBottom(scale: scale)
        let halfWidth = headHalfWidth(scale: scale)
        let jawHalfWidth = halfWidth * (1 - jawNarrowing)
        let lowerCheekY = bottom + headHeight * 0.30 * scale
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: top))
        path.addCurve(
            to: CGPoint(x: halfWidth, y: eyeCenterY(scale: scale) - 2.5 * scale),
            control1: CGPoint(x: halfWidth * 0.60, y: top + 1.0 * scale),
            control2: CGPoint(x: halfWidth, y: top - 11.5 * scale)
        )
        path.addCurve(
            to: CGPoint(x: jawHalfWidth, y: lowerCheekY),
            control1: CGPoint(x: halfWidth * 1.02, y: -2 * scale),
            control2: CGPoint(x: jawHalfWidth * 1.08, y: -7 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: bottom),
            control1: CGPoint(x: jawHalfWidth * 0.86, y: bottom + 3.2 * scale),
            control2: CGPoint(x: 6.2 * scale, y: bottom - 0.8 * scale)
        )
        path.addCurve(
            to: CGPoint(x: -jawHalfWidth, y: lowerCheekY),
            control1: CGPoint(x: -6.2 * scale, y: bottom - 0.8 * scale),
            control2: CGPoint(x: -jawHalfWidth * 0.86, y: bottom + 3.2 * scale)
        )
        path.addCurve(
            to: CGPoint(x: -halfWidth, y: eyeCenterY(scale: scale) - 2.5 * scale),
            control1: CGPoint(x: -jawHalfWidth * 1.08, y: -7 * scale),
            control2: CGPoint(x: -halfWidth * 1.02, y: -2 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: top),
            control1: CGPoint(x: -halfWidth, y: top - 11.5 * scale),
            control2: CGPoint(x: -halfWidth * 0.60, y: top + 1.0 * scale)
        )
        path.closeSubpath()
        return path
    }

    static func friendlyMouthPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let halfWidth = max(headWidth * mouthWidthRatio * 0.5 * scale, minGameplayMouthHalfWidth)
        let baseline: CGFloat = 0
        let smileCurve = max(headHeight * 0.018 * scale, minGameplayMouthCurve)
        path.move(to: CGPoint(x: -halfWidth, y: baseline))
        path.addCurve(
            to: CGPoint(x: halfWidth, y: baseline),
            control1: CGPoint(x: -halfWidth * 0.42, y: baseline - smileCurve),
            control2: CGPoint(x: halfWidth * 0.42, y: baseline - smileCurve)
        )
        return path
    }

    static func eyePath(side: CGFloat, scale: CGFloat) -> CGPath {
        let width = max(headWidth * 0.118 * scale, minGameplayEyeWidth)
        let height = max(headWidth * 0.132 * scale, minGameplayEyeHeight)
        let rect = CGRect(
            x: eyeCenterX(side: side, scale: scale) - width * 0.5,
            y: eyeCenterY(scale: scale) - height * 0.5,
            width: width,
            height: height
        )
        let path = CGMutablePath()
        path.addEllipse(in: rect)
        return path
    }

    static func eyeSpecularPath(side: CGFloat, scale: CGFloat) -> CGPath {
        let dot = max(1.15, 1.55 * scale)
        let rect = CGRect(
            x: eyeCenterX(side: side, scale: scale) - headWidth * 0.026 * scale,
            y: eyeCenterY(scale: scale) + headWidth * 0.020 * scale,
            width: dot,
            height: dot
        )
        let path = CGMutablePath()
        path.addEllipse(in: rect)
        return path
    }

    static func browPath(side: CGFloat, scale: CGFloat) -> CGPath {
        let length = max(headWidth * 0.145 * scale, minGameplayBrowWidth)
        let thickness = max(0.68 * scale, 0.70)
        let centerX = eyeCenterX(side: side, scale: scale)
        let centerY = browCenterY(scale: scale)
        let lift = tan(0.6 * .pi / 180) * length
        let path = CGMutablePath()
        path.move(to: CGPoint(x: centerX - side * length * 0.5, y: centerY + lift * 0.5))
        path.addLine(to: CGPoint(x: centerX + side * length * 0.5, y: centerY - lift * 0.5))
        let stroked = path.copy(strokingWithWidth: thickness, lineCap: .round, lineJoin: .round, miterLimit: 2)
        return stroked
    }

    static func nosePath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let y = noseCenterY(scale: scale)
        path.move(to: CGPoint(x: 0.8 * scale, y: y + 2.1 * scale))
        path.addQuadCurve(
            to: CGPoint(x: -1.0 * scale, y: y - 2.4 * scale),
            control: CGPoint(x: -0.2 * scale, y: y - 0.2 * scale)
        )
        return path
    }

    static func earPath(side: CGFloat, scale: CGFloat) -> CGPath {
        let width = headWidth * 0.145 * scale
        let height = headHeight * 0.215 * scale
        let rect = CGRect(
            x: side * headHalfWidth(scale: scale) - (side > 0 ? width * 0.10 : width * 0.90),
            y: eyeCenterY(scale: scale) - height * 0.42,
            width: width,
            height: height
        )
        let path = CGMutablePath()
        path.addEllipse(in: rect)
        return path
    }

    static func premiumHairPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()

        let top = headTop(scale: scale)
        let halfWidth = headHalfWidth(scale: scale)
        let browY = browCenterY(scale: scale)
        let eyeY = eyeCenterY(scale: scale)
        let templeY = eyeY + 1.8 * scale
        let fringeBaseY = browY + 8.4 * scale
        let fringeTipY = browY + 5.8 * scale

        // Crown and temples are deliberately anchored around the head ellipse.
        path.move(to: CGPoint(x: -halfWidth - 5.2 * scale, y: templeY - 0.6 * scale))
        path.addQuadCurve(
            to: CGPoint(x: -halfWidth - 2.6 * scale, y: top - 3.4 * scale),
            control: CGPoint(x: -halfWidth - 7.2 * scale, y: browY + 6.6 * scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: -4.8 * scale, y: top + 12.2 * scale),
            control: CGPoint(x: -halfWidth * 0.88, y: top + 10.2 * scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: halfWidth + 3.0 * scale, y: top - 3.6 * scale),
            control: CGPoint(x: halfWidth * 0.88, y: top + 11.6 * scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: halfWidth + 2.2 * scale, y: templeY - 2.0 * scale),
            control: CGPoint(x: halfWidth + 6.2 * scale, y: browY + 5.0 * scale)
        )

        // Angular Zuko-style fringe: asymmetric points that prove this is hair,
        // not a cap, helmet, or bald stripe.
        path.addLine(to: CGPoint(x: 12.2 * scale, y: fringeBaseY + 1.0 * scale))
        path.addLine(to: CGPoint(x: 6.2 * scale, y: fringeTipY + 1.4 * scale))
        path.addLine(to: CGPoint(x: 1.0 * scale, y: fringeBaseY - 0.2 * scale))
        path.addLine(to: CGPoint(x: -5.2 * scale, y: fringeTipY + 0.8 * scale))
        path.addLine(to: CGPoint(x: -10.2 * scale, y: fringeBaseY + 1.1 * scale))
        path.addLine(to: CGPoint(x: -14.8 * scale, y: fringeTipY + 1.4 * scale))
        path.addLine(to: CGPoint(x: -halfWidth - 3.2 * scale, y: templeY - 2.4 * scale))
        path.closeSubpath()

        path.addSafeRoundedRect(in: CGRect(x: -halfWidth - 4.0 * scale, y: -4.0 * scale, width: 6.6 * scale, height: 14.8 * scale), cornerWidth: 2.9 * scale, cornerHeight: 2.9 * scale)
        path.addSafeRoundedRect(in: CGRect(x: halfWidth - 1.0 * scale, y: -3.6 * scale, width: 5.4 * scale, height: 13.2 * scale), cornerWidth: 2.5 * scale, cornerHeight: 2.5 * scale)
        return path
    }

    static func hairHighlightPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let top = headTop(scale: scale)
        path.move(to: CGPoint(x: -10.2 * scale, y: top + 4.2 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 7.2 * scale, y: top + 3.0 * scale),
            control: CGPoint(x: -1.8 * scale, y: top + 7.2 * scale)
        )
        return path.copy(strokingWithWidth: max(1.45, 1.45 * scale), lineCap: .round, lineJoin: .round, miterLimit: 2)
    }

    static func tiedHeadbandPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let halfWidth = headHalfWidth(scale: scale)
        let bandY = browCenterY(scale: scale) + 3.8 * scale
        let height = 5.4 * scale
        path.move(to: CGPoint(x: -halfWidth - 1.6 * scale, y: bandY + height * 0.45))
        path.addQuadCurve(
            to: CGPoint(x: halfWidth + 1.8 * scale, y: bandY + height * 0.32),
            control: CGPoint(x: 0, y: bandY + height * 0.92)
        )
        path.addLine(to: CGPoint(x: halfWidth + 1.1 * scale, y: bandY - height * 0.48))
        path.addQuadCurve(
            to: CGPoint(x: -halfWidth - 1.5 * scale, y: bandY - height * 0.34),
            control: CGPoint(x: 0, y: bandY - height * 0.86)
        )
        path.closeSubpath()
        return path
    }

    static func tiedHeadbandTailsPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let halfWidth = headHalfWidth(scale: scale)
        let knotX = halfWidth + 1.0 * scale
        let knotY = browCenterY(scale: scale) + 3.2 * scale
        path.addEllipse(in: CGRect(x: knotX - 1.7 * scale, y: knotY - 1.7 * scale, width: 3.4 * scale, height: 3.4 * scale))
        path.move(to: CGPoint(x: knotX + 1.2 * scale, y: knotY - 1.2 * scale))
        path.addQuadCurve(to: CGPoint(x: knotX + 9.5 * scale, y: knotY - 8.8 * scale), control: CGPoint(x: knotX + 6.0 * scale, y: knotY - 2.8 * scale))
        path.addQuadCurve(to: CGPoint(x: knotX + 4.8 * scale, y: knotY - 13.2 * scale), control: CGPoint(x: knotX + 8.4 * scale, y: knotY - 13.2 * scale))
        path.addQuadCurve(to: CGPoint(x: knotX + 0.6 * scale, y: knotY - 2.2 * scale), control: CGPoint(x: knotX + 2.0 * scale, y: knotY - 8.0 * scale))
        path.closeSubpath()
        return path
    }

    static func courtCapCrownPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let top = headTop(scale: scale)
        let halfWidth = headHalfWidth(scale: scale)
        let browY = browCenterY(scale: scale)
        path.move(to: CGPoint(x: -halfWidth - 1.6 * scale, y: browY + 2.0 * scale))
        path.addQuadCurve(to: CGPoint(x: -halfWidth * 0.62, y: top + 2.4 * scale), control: CGPoint(x: -halfWidth - 1.2 * scale, y: top - 5.5 * scale))
        path.addQuadCurve(to: CGPoint(x: halfWidth * 0.78, y: top + 0.4 * scale), control: CGPoint(x: -1.0 * scale, y: top + 8.0 * scale))
        path.addQuadCurve(to: CGPoint(x: halfWidth + 1.4 * scale, y: browY + 2.4 * scale), control: CGPoint(x: halfWidth + 3.0 * scale, y: top - 4.0 * scale))
        path.addQuadCurve(to: CGPoint(x: -halfWidth - 1.6 * scale, y: browY + 2.0 * scale), control: CGPoint(x: 0, y: browY - 0.6 * scale))
        path.closeSubpath()
        return path
    }

    static func courtCapBrimPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let browY = browCenterY(scale: scale) + 1.0 * scale
        path.move(to: CGPoint(x: -4.5 * scale, y: browY))
        path.addQuadCurve(to: CGPoint(x: 23.5 * scale, y: browY + 1.2 * scale), control: CGPoint(x: 9.0 * scale, y: browY + 5.6 * scale))
        path.addQuadCurve(to: CGPoint(x: 10.0 * scale, y: browY - 5.0 * scale), control: CGPoint(x: 22.0 * scale, y: browY - 4.8 * scale))
        path.addQuadCurve(to: CGPoint(x: -4.5 * scale, y: browY), control: CGPoint(x: 1.2 * scale, y: browY - 4.2 * scale))
        path.closeSubpath()
        return path
    }

    static func premiumBackHairPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()

        let top = headTop(scale: scale)
        let halfWidth = headHalfWidth(scale: scale)
        let eyeY = eyeCenterY(scale: scale)
        path.move(to: CGPoint(x: -halfWidth - 3.0 * scale, y: eyeY + 1.4 * scale))
        path.addQuadCurve(to: CGPoint(x: -5.4 * scale, y: top + 9.2 * scale), control: CGPoint(x: -halfWidth - 5.4 * scale, y: top + 4.8 * scale))
        path.addQuadCurve(to: CGPoint(x: halfWidth + 2.6 * scale, y: top - 3.0 * scale), control: CGPoint(x: halfWidth * 0.78, y: top + 9.6 * scale))
        path.addQuadCurve(to: CGPoint(x: 7.8 * scale, y: eyeY - 3.2 * scale), control: CGPoint(x: halfWidth + 3.5 * scale, y: 3.2 * scale))
        path.addQuadCurve(to: CGPoint(x: -7.8 * scale, y: eyeY - 3.6 * scale), control: CGPoint(x: 0, y: eyeY + 1.2 * scale))
        path.addQuadCurve(to: CGPoint(x: -halfWidth - 3.0 * scale, y: eyeY + 1.4 * scale), control: CGPoint(x: -halfWidth - 2.4 * scale, y: eyeY - 6.8 * scale))
        path.closeSubpath()

        path.addSafeRoundedRect(in: CGRect(x: -halfWidth - 3.0 * scale, y: -3.0 * scale, width: 5.4 * scale, height: 11.8 * scale), cornerWidth: 2.5 * scale, cornerHeight: 2.5 * scale)
        path.addSafeRoundedRect(in: CGRect(x: halfWidth - 1.2 * scale, y: -2.4 * scale, width: 4.7 * scale, height: 10.2 * scale), cornerWidth: 2.3 * scale, cornerHeight: 2.3 * scale)
        return path
    }

    // MARK: - Torso

    static func premiumTorsoPath(scale: CGFloat) -> CGPath {
        let width = 34 * scale
        let shoulder = width * 0.49 * shoulderWidening
        let waist = width * 0.34
        let height = 59 * scale
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -shoulder + 2.4 * scale, y: height * 0.45))
        path.addQuadCurve(to: CGPoint(x: -shoulder, y: height * 0.37), control: CGPoint(x: -shoulder - 2.2 * scale, y: height * 0.43))
        path.addQuadCurve(to: CGPoint(x: -waist, y: -height * 0.50), control: CGPoint(x: -width * 0.47, y: -height * 0.02))
        path.addLine(to: CGPoint(x: waist, y: -height * 0.50))
        path.addQuadCurve(to: CGPoint(x: shoulder, y: height * 0.37), control: CGPoint(x: width * 0.47, y: -height * 0.02))
        path.addQuadCurve(to: CGPoint(x: shoulder - 2.4 * scale, y: height * 0.45), control: CGPoint(x: shoulder + 2.2 * scale, y: height * 0.43))
        path.addQuadCurve(to: CGPoint(x: 0, y: height * 0.50), control: CGPoint(x: width * 0.22, y: height * 0.54))
        path.addQuadCurve(to: CGPoint(x: -shoulder + 2.4 * scale, y: height * 0.45), control: CGPoint(x: -width * 0.22, y: height * 0.54))
        path.closeSubpath()
        return path
    }

    // MARK: - Arms & Racket Grip

    // MARK: - Shorts

    static func athleticShortsPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -22 * scale, y: 9 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 22 * scale, y: 9 * scale),
            control: CGPoint(x: 0, y: 13 * scale)
        )
        path.addLine(to: CGPoint(x: 18 * scale, y: -8 * scale))
        path.addQuadCurve(
            to: CGPoint(x: 5 * scale, y: -9 * scale),
            control: CGPoint(x: 13 * scale, y: -11 * scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: 0, y: -5 * scale),
            control: CGPoint(x: 2.5 * scale, y: -8 * scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: -5 * scale, y: -9 * scale),
            control: CGPoint(x: -2.5 * scale, y: -8 * scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: -18 * scale, y: -8 * scale),
            control: CGPoint(x: -13 * scale, y: -11 * scale)
        )
        path.closeSubpath()
        return path
    }

    // MARK: - Legs & Feet

    static func athleticLegPath(scale: CGFloat, height: CGFloat, side: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let topY = height * 0.48
        let kneeY = -height * 0.06
        let footY = -height * 0.50
        let hipDrift = side * 1.6 * scale
        let thighOuter = 8.6 * scale
        let thighInner = 6.2 * scale
        let kneeOuter = 6.2 * scale
        let kneeInner = 4.6 * scale
        let calfOuter = 7.4 * scale
        let ankleOuter = 5.4 * scale

        path.move(to: CGPoint(x: -thighInner + hipDrift, y: topY))
        path.addQuadCurve(
            to: CGPoint(x: -kneeInner, y: kneeY),
            control: CGPoint(x: -thighOuter, y: height * 0.22)
        )
        path.addQuadCurve(
            to: CGPoint(x: -ankleOuter, y: footY),
            control: CGPoint(x: -calfOuter, y: -height * 0.30)
        )
        path.addLine(to: CGPoint(x: ankleOuter, y: footY))
        path.addQuadCurve(
            to: CGPoint(x: kneeOuter, y: kneeY),
            control: CGPoint(x: calfOuter, y: -height * 0.30)
        )
        path.addQuadCurve(
            to: CGPoint(x: thighOuter + hipDrift, y: topY),
            control: CGPoint(x: thighOuter, y: height * 0.22)
        )
        path.closeSubpath()
        return path
    }

    // MARK: - Arms (tapered: shoulder → elbow → wrist)

    /// Tapered arm silhouette. `topWidth` = shoulder end, `bottomWidth` = wrist end.
    static func armPath(scale: CGFloat, topWidth: CGFloat, bottomWidth: CGFloat, length: CGFloat) -> CGPath {
        let ht  = topWidth    * 0.5 * scale
        let hb  = bottomWidth * 0.5 * scale
        let len = length * scale
        let elbowY   = len * 0.38          // elbow at 38% down from shoulder
        let elbowOut = ht * 0.80           // slight lateral elbow bump
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -ht, y: len * 0.5))
        path.addCurve(to: CGPoint(x: -elbowOut, y: elbowY - len * 0.5),
                      control1: CGPoint(x: -ht * 1.12, y: len * 0.14),
                      control2: CGPoint(x: -elbowOut * 1.18, y: elbowY - len * 0.5 + len * 0.06))
        path.addCurve(to: CGPoint(x: -hb, y: -len * 0.5),
                      control1: CGPoint(x: -elbowOut * 0.88, y: elbowY - len * 0.5 - len * 0.04),
                      control2: CGPoint(x: -hb * 1.10, y: -len * 0.34))
        path.addLine(to: CGPoint(x: hb, y: -len * 0.5))
        path.addCurve(to: CGPoint(x: elbowOut, y: elbowY - len * 0.5),
                      control1: CGPoint(x: hb * 1.10, y: -len * 0.34),
                      control2: CGPoint(x: elbowOut * 0.88, y: elbowY - len * 0.5 - len * 0.04))
        path.addCurve(to: CGPoint(x: ht, y: len * 0.5),
                      control1: CGPoint(x: elbowOut * 1.18, y: elbowY - len * 0.5 + len * 0.06),
                      control2: CGPoint(x: ht * 1.12, y: len * 0.14))
        path.closeSubpath()
        return path
    }

    // MARK: - Shoe anatomy

    /// Full shoe upper silhouette: low toe box, slightly elevated heel.
    static func shoeBodyPath(scale: CGFloat) -> CGPath {
        let w: CGFloat = 41 * scale
        let h: CGFloat = 14.5 * scale
        let heelLift: CGFloat = 3.5 * scale
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -w * 0.48, y: heelLift))
        path.addCurve(to: CGPoint(x: -w * 0.50, y: -h * 0.50),
                      control1: CGPoint(x: -w * 0.56, y: -h * 0.05),
                      control2: CGPoint(x: -w * 0.54, y: -h * 0.40))
        path.addCurve(to: CGPoint(x: w * 0.56, y: -h * 0.42),
                      control1: CGPoint(x: -w * 0.16, y: -h * 0.62),
                      control2: CGPoint(x:  w * 0.28, y: -h * 0.58))
        path.addCurve(to: CGPoint(x: w * 0.58, y: h * 0.28),
                      control1: CGPoint(x: w * 0.66, y: -h * 0.18),
                      control2: CGPoint(x: w * 0.66, y:  h * 0.10))
        path.addCurve(to: CGPoint(x: -w * 0.48, y: heelLift),
                      control1: CGPoint(x:  w * 0.20, y: h * 0.58),
                      control2: CGPoint(x: -w * 0.18, y: h * 0.48))
        path.closeSubpath()
        return path
    }

    /// Midsole/outsole strip — slightly wider than upper, flat bottom.
    static func shoeSolePath(scale: CGFloat) -> CGPath {
        let w: CGFloat = 43 * scale
        let h: CGFloat = 5.6 * scale
        let corner = min(3 * scale, w * 0.5, h * 0.5)   // never exceed half-dimension
        let path = CGMutablePath()
        path.addSafeRoundedRect(
            in: CGRect(x: -w * 0.5, y: -h * 0.5, width: w, height: h),
            cornerWidth: corner, cornerHeight: corner
        )
        return path
    }

    /// Tongue: visible above lace area.
    static func shoeTonguePath(scale: CGFloat) -> CGPath {
        let w: CGFloat = 11 * scale
        let h: CGFloat = 9 * scale
        let path = CGMutablePath()
        path.addSafeRoundedRect(
            in: CGRect(x: -w * 0.5, y: 1.2 * scale, width: w, height: h),
            cornerWidth: 3 * scale, cornerHeight: 3 * scale
        )
        return path
    }

    /// Three horizontal lace bars rendered as a stroked fill path.
    static func shoeLacePath(scale: CGFloat) -> CGPath {
        let laceW: CGFloat = 8.2 * scale
        let path = CGMutablePath()
        for i in 0..<3 {
            let y = CGFloat(i) * 2.7 * scale + 2.2 * scale
            path.move(to: CGPoint(x: -laceW * 0.5, y: y))
            path.addLine(to: CGPoint(x: laceW * 0.5, y: y))
        }
        return path.copy(strokingWithWidth: max(0.75 * scale, 0.65),
                         lineCap: .round, lineJoin: .round, miterLimit: 2)
    }

    /// Side brand stripe — diagonal slash on lateral shoe panel.
    static func shoeStripePath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x:  4 * scale, y: -3.5 * scale))
        path.addLine(to: CGPoint(x: 13.5 * scale, y:  3.0 * scale))
        return path.copy(strokingWithWidth: max(2.4 * scale, 2.0),
                         lineCap: .round, lineJoin: .round, miterLimit: 2)
    }

    // MARK: - Clothing details

    /// V-neck collar opening on torso front.
    static func shirtCollarPath(scale: CGFloat) -> CGPath {
        let depth: CGFloat = 7.0 * scale
        let half:  CGFloat = headWidth * 0.18 * scale
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -half, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -depth))
        path.addLine(to: CGPoint(x:  half, y: 0))
        return path.copy(strokingWithWidth: max(1.5 * scale, 1.2),
                         lineCap: .round, lineJoin: .round, miterLimit: 2)
    }

    /// Sleeve cap ellipse at shoulder junction.
    static func sleeveCapPath(scale: CGFloat, side: CGFloat) -> CGPath {
        let r:  CGFloat = 9.2 * scale
        let cx: CGFloat = side * 17.5 * scale
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: cx - r, y: -r * 0.48, width: r * 2.08, height: r * 1.04))
        return path
    }

    /// Elastic waistband strip at top of shorts.
    static func shortsWaistbandPath(scale: CGFloat) -> CGPath {
        let w: CGFloat = 46 * scale
        let h: CGFloat = 5.5 * scale
        let path = CGMutablePath()
        path.addSafeRoundedRect(
            in: CGRect(x: -w * 0.5, y: -h * 0.5, width: w, height: h),
            cornerWidth: 2.5 * scale, cornerHeight: 2.5 * scale
        )
        return path
    }

    // MARK: - Body shading overlays

    /// Centre-chest highlight — bright strip down the front of the shirt.
    static func torsoHighlightPath(scale: CGFloat) -> CGPath {
        let w: CGFloat = 9 * scale
        let h: CGFloat = 32 * scale
        let path = CGMutablePath()
        path.addSafeRoundedRect(
            in: CGRect(x: -w * 0.5, y: 2 * scale, width: w, height: h),
            cornerWidth: w * 0.5, cornerHeight: w * 0.5
        )
        return path
    }

    /// Side shadow strip — darkens left or right flank of torso.
    static func torsoShadowPath(scale: CGFloat, side: CGFloat) -> CGPath {
        let w: CGFloat = 11 * scale
        let h: CGFloat = 40 * scale
        let x:  CGFloat = side * 10 * scale
        let path = CGMutablePath()
        path.addSafeRoundedRect(
            in: CGRect(x: x - w * 0.5, y: -h * 0.06, width: w, height: h),
            cornerWidth: w * 0.42, cornerHeight: w * 0.42
        )
        return path
    }

    /// Quad / shin highlight on leg — narrow bright strip.
    static func legHighlightPath(scale: CGFloat, legVisualHeight: CGFloat) -> CGPath {
        let w: CGFloat = 4.6 * scale
        let h: CGFloat = legVisualHeight * 0.33
        let path = CGMutablePath()
        path.addSafeRoundedRect(
            in: CGRect(x: -w * 0.5, y: -h * 0.08, width: w, height: h),
            cornerWidth: w * 0.5, cornerHeight: w * 0.5
        )
        return path
    }

    // MARK: - Composite Figure
}
