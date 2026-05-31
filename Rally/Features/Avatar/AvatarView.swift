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
            case .slim: return size * 0.48
            case .athletic: return size * 0.55
            case .strong: return size * 0.60
            }
        }()
        let topHeight: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.30
            case .athletic: return size * 0.32
            case .strong: return size * 0.33
            }
        }()
        let bottomWidth: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.36
            case .athletic: return size * 0.42
            case .strong: return size * 0.46
            }
        }()
        let shoulderGlowWidth: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.28
            case .athletic: return size * 0.32
            case .strong: return size * 0.37
            }
        }()
        let neckWidth: CGFloat = config.bodyType == .strong ? size * 0.085 : size * 0.07
        let legSpacing: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.05
            case .athletic: return size * 0.04
            case .strong: return size * 0.03
            }
        }()
        let legWidth: CGFloat = {
            switch config.bodyType {
            case .slim: return size * 0.28
            case .athletic: return size * 0.32
            case .strong: return size * 0.35
            }
        }()

        return ZStack {
            Ellipse()
                .fill(RallyUIKit.Palette.champagne.opacity(0.08))
                .frame(width: size * 0.42, height: size * 0.68)
                .blur(radius: 18)
                .offset(y: size * 0.02)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [RallyUIKit.Palette.cyan.opacity(0.18), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.28, height: size * 0.54)
                .blur(radius: 12)
                .offset(y: -size * 0.02)

            Capsule()
                .fill(RallyUIKit.Palette.frost.opacity(0.06))
                .frame(width: shoulderGlowWidth, height: size * 0.13)
                .blur(radius: 10)
                .offset(y: -size * 0.145)

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
            .offset(x: size * 0.29, y: -size * 0.02)
            .shadow(color: racketAccent.opacity(0.5), radius: 10, y: 4)

            // Legs (skin + shoes)
            HStack(spacing: legSpacing) {
                LegShape(skin: skinColor, shoe: shoesColor, accent: shoesAccent)
                LegShape(skin: skinColor, shoe: shoesColor, accent: shoesAccent)
            }
            .frame(width: legWidth, height: size * 0.42)
            .offset(y: size * 0.22)

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
                .offset(y: size * 0.06)

            Capsule()
                .fill(skinColor.opacity(0.92))
                .frame(width: neckWidth, height: size * 0.10)
                .offset(y: -size * 0.17)

            // Back arm for fuller silhouette.
            Capsule()
                .fill(skinColor.opacity(0.92))
                .frame(
                    width: config.bodyType == .strong ? size * 0.074 : size * 0.065,
                    height: size * 0.22
                )
                .rotationEffect(.degrees(18))
                .offset(x: -size * 0.18, y: -size * 0.07)

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
                .offset(y: -size * 0.10)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

            RoundedRectangle(cornerRadius: 5)
                .fill(topAccent.opacity(0.88))
                .frame(width: torsoWidth * 0.34, height: 3)
                .offset(y: -size * 0.18)

            Capsule()
                .fill(Color.black.opacity(0.14))
                .frame(width: size * 0.20, height: size * 0.04)
                .offset(y: size * 0.02)
                .blur(radius: 4)

            // Lead arm with clearer extension toward the racquet.
            Capsule()
                .fill(skinColor)
                .frame(
                    width: config.bodyType == .strong ? size * 0.076 : size * 0.07,
                    height: size * 0.26
                )
                .rotationEffect(.degrees(-16))
                .offset(x: size * 0.17, y: -size * 0.07)

            // Head
            Circle()
                .fill(skinColor)
                .frame(width: size * 0.22, height: size * 0.22)
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
                .offset(y: -size * 0.30)
                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
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
                Ellipse()
                    .fill(color)
                    .frame(width: size * 0.24, height: size * 0.13)
                    .offset(y: -size * 0.055)
            case .medium:
                Ellipse()
                    .fill(color)
                    .frame(width: size * 0.26, height: size * 0.15)
                    .offset(y: -size * 0.045)
            case .long:
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.23, height: size * 0.31)
                    .offset(y: size * 0.045)
            case .ponytail:
                Ellipse()
                    .fill(color)
                    .frame(width: size * 0.24, height: size * 0.10)
                    .offset(y: -size * 0.05)
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.05, height: size * 0.18)
                    .offset(x: -size * 0.11, y: size * 0.03)
            case .bun:
                Ellipse()
                    .fill(color)
                    .frame(width: size * 0.20, height: size * 0.08)
                    .offset(y: -size * 0.04)
                Circle()
                    .fill(color)
                    .frame(width: size * 0.09, height: size * 0.09)
                    .offset(y: -size * 0.10)
            }
        }
    }

    @ViewBuilder
    private func faceDetails(size: CGFloat) -> some View {
        VStack(spacing: size * 0.018) {
            HStack(spacing: size * 0.045) {
                Circle()
                    .fill(Color.black.opacity(0.34))
                    .frame(width: size * 0.012, height: size * 0.012)
                Circle()
                    .fill(Color.black.opacity(0.34))
                    .frame(width: size * 0.012, height: size * 0.012)
            }
            Capsule()
                .fill(Color.white.opacity(0.14))
                .frame(width: size * 0.05, height: size * 0.008)
            Capsule()
                .fill(Color.black.opacity(0.10))
                .frame(width: size * 0.065, height: size * 0.012)
        }
        .offset(y: size * 0.006)
    }

    private var skinColor: Color {
        Color(hex: config.skinTone.hex) ?? .pink
    }

    private var bodyScale: CGFloat {
        switch config.bodyType {
        case .slim:     return 0.92
        case .athletic: return 1.0
        case .strong:   return 1.10
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
                .fill(skin)
                .frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: 4)
                .fill(shoe)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(accent ?? .clear, lineWidth: 1.5)
                )
                .frame(height: 14)
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
