import SwiftUI

/// Renders a stylized tennis-player avatar from an `AvatarConfig`, applying
/// the colors of the currently-equipped shop items.
///
/// This is intentionally an SF-Symbols-and-shapes composition so the app
/// looks complete with zero authored art. Real art replaces the shapes in
/// a future commit without changing the public surface.
struct AvatarView: View {
    let config: AvatarConfig
    /// Optional override for try-on previews: temporarily replace one slot.
    var preview: (slot: ShopItem.Category, item: ShopItem)? = nil
    /// Light yaw tilt so Home reads slightly dimensional without SceneKit.
    var subtlePerspective: Bool = false

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                background

                bodyComposition(size: size)
                    .frame(width: size, height: size)
                    .rotation3DEffect(
                        .degrees(subtlePerspective ? -8 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .center,
                        perspective: 0.52
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(
                LinearGradient(
                    colors: [
                        RallyUIKit.Palette.cyan.opacity(0.18),
                        RallyUIKit.Palette.slate,
                        RallyUIKit.Palette.ink,
                        Color.black
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(RallyUIKit.Palette.cyan.opacity(0.16))
                    .blur(radius: 30)
                    .frame(width: 140, height: 140)
                    .offset(x: -10, y: -10)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(RallyUIKit.Palette.rose.opacity(0.14))
                    .blur(radius: 34)
                    .frame(width: 120, height: 120)
                    .offset(x: 12, y: 16)
            }
            .overlay(alignment: .topTrailing) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 110, height: 18)
                    .blur(radius: 10)
                    .rotationEffect(.degrees(28))
                    .offset(x: 18, y: -6)
            }
            .overlay(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(0.26))
                    .frame(width: 180, height: 28)
                    .blur(radius: 10)
                    .offset(y: 26)
            }
            .overlay {
                courtLines
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    private var courtLines: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .stroke(RallyUIKit.Palette.cyan.opacity(0.08), lineWidth: 1)
                .padding(18)

            Rectangle()
                .fill(RallyUIKit.Palette.cyan.opacity(0.05))
                .frame(width: 1)
                .padding(.vertical, 24)

            Rectangle()
                .fill(RallyUIKit.Palette.cyan.opacity(0.04))
                .frame(height: 1)
                .padding(.horizontal, 34)
                .offset(y: 24)
        }
    }

    // MARK: - Composition

    private func bodyComposition(size: CGFloat) -> some View {
        let topColor = equippedItem(.top)?.color ?? .white
        let topAccent = equippedItem(.top)?.accentColor ?? .clear
        let bottomColor = equippedItem(.bottom)?.color ?? .black
        let bottomAccent = equippedItem(.bottom)?.accentColor ?? .clear
        let shoesColor = equippedItem(.shoes)?.color ?? .white
        let shoesAccent = equippedItem(.shoes)?.accentColor
        let racketColor = equippedItem(.racket)?.color ?? Color(white: 0.7)
        let racketAccent = equippedItem(.racket)?.accentColor ?? .cyan
        let torsoWidth: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.42
            case .athletic: return size * 0.47
            case .strong: return size * 0.56
            }
        }()
        let topHeight: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.32
            case .athletic: return size * 0.335
            case .strong: return size * 0.35
            }
        }()
        let bottomWidth: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.31
            case .athletic: return size * 0.35
            case .strong: return size * 0.44
            }
        }()
        let shoulderGlowWidth: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.30
            case .athletic: return size * 0.38
            case .strong: return size * 0.40
            }
        }()
        let neckWidth: CGFloat = config.bodyType == .strong ? size * 0.08 : size * 0.066
        let legSpacing: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.033
            case .athletic: return size * 0.028
            case .strong: return size * 0.03
            }
        }()
        let legWidth: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.22
            case .athletic: return size * 0.25
            case .strong: return size * 0.34
            }
        }()
        let armWidth: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.055
            case .athletic: return size * 0.060
            case .strong: return size * 0.078
            }
        }()
        let shoulderWidth: CGFloat = {
            switch config.bodyType {
            case .slim: return torsoWidth * 1.14
            case .athletic: return torsoWidth * 1.18
            case .strong: return torsoWidth * 1.20
            }
        }()
        let headSize: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.168
            case .athletic: return size * 0.164
            case .strong: return size * 0.188
            }
        }()
        let auraTint = topAccent == .clear ? RallyUIKit.Palette.cyan : topAccent
        let racketHalo = racketAccent.opacity(0.42)

        return ZStack {
            Ellipse()
                .fill(RallyUIKit.Palette.champagne.opacity(0.08))
                .frame(width: size * 0.42, height: size * 0.68)
                .blur(radius: 18)
                .offset(y: size * 0.01)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [auraTint.opacity(0.22), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.32, height: size * 0.62)
                .blur(radius: 16)
                .offset(y: -size * 0.04)

            Capsule()
                .fill(RallyUIKit.Palette.frost.opacity(0.06))
                .frame(width: shoulderGlowWidth, height: size * 0.13)
                .blur(radius: 10)
                .offset(y: -size * 0.145)

            Ellipse()
                .fill(racketHalo)
                .frame(width: size * 0.18, height: size * 0.30)
                .blur(radius: 22)
                .offset(x: size * 0.30, y: -size * 0.07)

            // Racket — behind the body, off to the side.
            ZStack {
                RacketShape(accent: racketAccent)
                    .fill(racketColor)
                    .overlay(
                        RacketShape(accent: racketAccent)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                RacketStrings()
                    .stroke(racketAccent.opacity(0.4), lineWidth: 1)
                    .padding(.top, size * 0.04)
                    .padding(.horizontal, size * 0.035)
                    .padding(.bottom, size * 0.23)
            }
            .frame(width: size * 0.24, height: size * 0.68)
            .rotationEffect(.degrees(10))
            .offset(x: size * 0.30, y: -size * 0.04)
            .shadow(color: racketAccent.opacity(0.5), radius: 12, y: 5)

            // Legs (skin + shoes)
            HStack(spacing: legSpacing) {
                LegShape(skin: skinColor, shoe: shoesColor, accent: shoesAccent)
                LegShape(skin: skinColor, shoe: shoesColor, accent: shoesAccent)
            }
            .frame(width: legWidth, height: size * 0.45)
            .offset(y: size * 0.245)

            Capsule()
                .fill(Color.black.opacity(0.16))
                .frame(width: size * 0.26, height: size * 0.05)
                .offset(y: size * 0.04)
                .blur(radius: 6)

            // Bottoms (shorts/skirt)
            RoundedRectangle(cornerRadius: 6)
                .fill(bottomColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .frame(width: bottomWidth * bodyScale, height: size * 0.17)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(bottomAccent, lineWidth: 1.5)
                )
                .frame(width: bottomWidth * bodyScale, height: size * 0.18)
                .offset(y: size * 0.07)

            Capsule()
                .fill(skinColor.opacity(0.92))
                .frame(width: neckWidth, height: size * 0.11)
                .offset(y: -size * 0.18)

            // Back arm for fuller silhouette.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [skinColor.opacity(0.88), skinColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: armWidth, height: size * 0.24)
                .rotationEffect(.degrees(21))
                .offset(x: -size * 0.205, y: -size * 0.085)

            Capsule()
                .fill(auraTint.opacity(0.16))
                .frame(width: shoulderWidth, height: size * 0.11)
                .blur(radius: 12)
                .offset(y: -size * 0.155)

            // Top (shirt)
            TopShape()
                .fill(topColor)
                .overlay(
                    TopShape()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    TopShape().stroke(topAccent, lineWidth: 2)
                )
                .frame(width: torsoWidth * bodyScale, height: topHeight)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: torsoWidth * 0.46, height: size * 0.02)
                        .offset(y: size * 0.02)
                }
                .offset(y: -size * 0.11)
                .shadow(color: auraTint.opacity(0.18), radius: 10, y: 4)

            RoundedRectangle(cornerRadius: 5)
                .fill(topAccent.opacity(0.88))
                .frame(width: torsoWidth * 0.38, height: 4)
                .offset(y: -size * 0.18)

            // Lead arm with clearer extension toward the racquet.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [skinColor, skinColor.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: armWidth, height: size * 0.29)
                .rotationEffect(.degrees(-18))
                .offset(x: size * 0.195, y: -size * 0.082)

            // Head
            HeadShape()
                .fill(skinColor)
                .frame(width: headSize * 1.02, height: headSize * 1.12)
                .overlay(hair(size: size))
                .overlay(alignment: .center) {
                    faceDetails(size: size)
                }
                .overlay(alignment: .top) {
                    if config.hairStyle != .bald {
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: size * 0.15, height: size * 0.018)
                            .offset(y: -size * 0.005)
                    }
                }
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: size * 0.08, height: size * 0.025)
                        .offset(y: size * 0.028)
                }
                .offset(y: -size * 0.315)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        }
    }

    // MARK: - Sub-shapes

    private func hair(size: CGFloat) -> some View {
        let style = config.hairStyle
        let color = Color(hex: config.hairColorHex) ?? Color(white: 0.25)
        return ZStack {
            switch style {
            case .bald:
                EmptyView()
            case .short:
                ZStack {
                    Ellipse()
                        .fill(color)
                        .frame(width: size * 0.23, height: size * 0.095)
                        .offset(x: size * 0.006, y: -size * 0.066)
                    RoundedRectangle(cornerRadius: size * 0.026)
                        .fill(color)
                        .frame(width: size * 0.15, height: size * 0.095)
                        .offset(x: -size * 0.028, y: -size * 0.018)
                    Capsule()
                        .fill(color)
                        .frame(width: size * 0.09, height: size * 0.036)
                        .rotationEffect(.degrees(-28))
                        .offset(x: -size * 0.030, y: -size * 0.004)
                    Capsule()
                        .fill(color.opacity(0.94))
                        .frame(width: size * 0.052, height: size * 0.11)
                        .offset(x: -size * 0.092, y: -size * 0.002)
                    Capsule()
                        .fill(color.opacity(0.94))
                        .frame(width: size * 0.046, height: size * 0.072)
                        .offset(x: size * 0.086, y: -size * 0.010)
                }
            case .medium:
                ZStack {
                    Ellipse()
                        .fill(color)
                        .frame(width: size * 0.245, height: size * 0.13)
                        .offset(y: -size * 0.05)
                    Capsule()
                        .fill(color)
                        .frame(width: size * 0.18, height: size * 0.14)
                        .offset(y: size * 0.005)
                }
            case .long:
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.22, height: size * 0.30)
                    .offset(y: size * 0.05)
            case .ponytail:
                ZStack {
                    Ellipse()
                        .fill(color)
                        .frame(width: size * 0.22, height: size * 0.095)
                        .offset(y: -size * 0.055)
                    Capsule()
                        .fill(color)
                        .frame(width: size * 0.05, height: size * 0.17)
                        .offset(x: -size * 0.10, y: size * 0.035)
                }
            case .bun:
                ZStack {
                    Ellipse()
                        .fill(color)
                        .frame(width: size * 0.19, height: size * 0.078)
                        .offset(y: -size * 0.04)
                    Circle()
                        .fill(color)
                        .frame(width: size * 0.08, height: size * 0.08)
                        .offset(y: -size * 0.095)
                }
            }
        }
    }

    @ViewBuilder
    private func faceDetails(size: CGFloat) -> some View {
        VStack(spacing: size * 0.015) {
            HStack(spacing: size * 0.04) {
                Capsule()
                    .fill(Color.black.opacity(0.24))
                    .frame(width: size * 0.024, height: size * 0.004)
                Capsule()
                    .fill(Color.black.opacity(0.24))
                    .frame(width: size * 0.024, height: size * 0.004)
            }
            HStack(spacing: size * 0.04) {
                eyeDetail(size: size)
                eyeDetail(size: size)
            }
            .overlay {
                if usesMarcySignatureLook {
                    glasses(size: size)
                }
            }
            RoundedRectangle(cornerRadius: size * 0.007)
                .fill(skinColor.opacity(0.94))
                .frame(width: size * 0.010, height: size * 0.017)
            Capsule()
                .fill(Color(red: 0.70, green: 0.49, blue: 0.42).opacity(0.35))
                .frame(width: size * 0.018, height: size * 0.003)
            ArcSmile()
                .stroke(Color(red: 0.56, green: 0.34, blue: 0.30).opacity(0.54), style: StrokeStyle(lineWidth: size * 0.0055, lineCap: .round))
                .frame(width: size * 0.048, height: size * 0.018)
        }
        .offset(y: size * 0.010)
    }

    @ViewBuilder
    private func eyeDetail(size: CGFloat) -> some View {
        VStack(spacing: size * 0.005) {
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.98))
                    .frame(width: size * 0.026, height: size * 0.015)
                Circle()
                    .fill(Color(red: 0.18, green: 0.12, blue: 0.1))
                    .frame(width: size * 0.007, height: size * 0.007)
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: size * 0.0025, height: size * 0.0025)
                    .offset(x: size * 0.002, y: -size * 0.002)
            }
        }
    }

    @ViewBuilder
    private func glasses(size: CGFloat) -> some View {
        ZStack {
            HStack(spacing: size * 0.028) {
                Circle()
                    .stroke(Color.black.opacity(0.72), lineWidth: size * 0.0048)
                    .frame(width: size * 0.040, height: size * 0.040)
                Circle()
                    .stroke(Color.black.opacity(0.72), lineWidth: size * 0.0048)
                    .frame(width: size * 0.040, height: size * 0.040)
            }

            Capsule()
                .fill(Color.black.opacity(0.72))
                .frame(width: size * 0.022, height: size * 0.003)
                .offset(y: -size * 0.002)

            Capsule()
                .fill(Color.black.opacity(0.54))
                .frame(width: size * 0.020, height: size * 0.0028)
                .rotationEffect(.degrees(18))
                .offset(x: -size * 0.048, y: -size * 0.002)

            Capsule()
                .fill(Color.black.opacity(0.54))
                .frame(width: size * 0.020, height: size * 0.0028)
                .rotationEffect(.degrees(-18))
                .offset(x: size * 0.048, y: -size * 0.002)
        }
        .offset(y: size * 0.002)
    }

    private var skinColor: Color {
        Color(hex: config.skinTone.hex) ?? .pink
    }

    private var usesMarcySignatureLook: Bool {
        let trimmed = config.playerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed == "marcy" || (!config.hasCompletedSetup && config.isUsingStarterLoadout)
    }

    private var bodyScale: CGFloat {
        switch config.bodyType {
        case .slim: return 0.92
        case .athletic: return 0.96
        case .strong: return 1.08
        }
    }

    private func equippedItem(_ category: ShopItem.Category) -> ShopItem? {
        if let preview = preview, preview.slot == category {
            return preview.item
        }
        switch category {
        case .top:    return ShopCatalog.item(id: config.equippedTopID)
        case .bottom: return ShopCatalog.item(id: config.equippedBottomID)
        case .shoes:  return ShopCatalog.item(id: config.equippedShoesID)
        case .racket: return ShopCatalog.item(id: config.equippedRacketID)
        case .bag, .accessory: return nil  // not visualized on the avatar (yet)
        }
    }
}

private struct ArcSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY - rect.height * 0.06))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY - rect.height * 0.06),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

private struct HeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let foreheadInset = rect.width * 0.14
        let jawInset = rect.width * 0.13
        let chinHeight = rect.height * 0.14

        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - foreheadInset, y: rect.minY + rect.height * 0.16),
            control: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - jawInset, y: rect.maxY - chinHeight),
            control: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - rect.width * 0.20, y: rect.maxY - rect.height * 0.015)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + jawInset, y: rect.maxY - chinHeight),
            control: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.maxY - rect.height * 0.015)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + foreheadInset, y: rect.minY + rect.height * 0.16),
            control: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY)
        )
        return path
    }
}

// MARK: - Custom shapes

private struct TopShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 8
        // Trapezoidal jersey silhouette: wider at the shoulders.
        let shoulderInset = rect.width * 0.06
        let waistInset    = rect.width * 0.02

        p.move(to: CGPoint(x: rect.minX + shoulderInset, y: rect.minY + r))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + shoulderInset + 12, y: rect.minY),
            control: CGPoint(x: rect.minX + shoulderInset, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX - shoulderInset - 12, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - shoulderInset, y: rect.minY + r),
            control: CGPoint(x: rect.maxX - shoulderInset, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX - waistInset, y: rect.maxY - r))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - waistInset - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX - waistInset, y: rect.maxY)
        )
        p.addLine(to: CGPoint(x: rect.minX + waistInset + r, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + waistInset, y: rect.maxY - r),
            control: CGPoint(x: rect.minX + waistInset, y: rect.maxY)
        )
        p.closeSubpath()
        return p
    }
}

private struct LegShape: View {
    let skin: Color
    let shoe: Color
    let accent: Color?

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [skin.opacity(0.94), skin],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: 4)
                .fill(shoe)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(accent ?? .clear, lineWidth: 1.5)
                )
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 3)
                        .padding(.horizontal, 3)
                        .offset(y: 2)
                }
                .frame(height: 16)
        }
    }
}

private struct RacketShape: Shape {
    let accent: Color
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Handle.
        let handleWidth = rect.width * 0.18
        let handleRect = CGRect(
            x: rect.midX - handleWidth / 2,
            y: rect.midY,
            width: handleWidth,
            height: rect.height * 0.45
        )
        p.addRoundedRect(in: handleRect, cornerSize: CGSize(width: 4, height: 4))
        // Head (oval).
        let headRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height * 0.55
        )
        p.addEllipse(in: headRect)
        return p
    }
}

private struct RacketStrings: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inner = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.12)
        for xFrac in stride(from: 0.18, through: 0.82, by: 0.16) {
            let x = inner.minX + inner.width * xFrac
            p.move(to: CGPoint(x: x, y: inner.minY))
            p.addLine(to: CGPoint(x: x, y: inner.maxY))
        }
        for yFrac in stride(from: 0.2, through: 0.8, by: 0.18) {
            let y = inner.minY + inner.height * yFrac
            p.move(to: CGPoint(x: inner.minX, y: y))
            p.addLine(to: CGPoint(x: inner.maxX, y: y))
        }
        return p
    }
}
