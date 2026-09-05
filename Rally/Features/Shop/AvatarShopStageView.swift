import SwiftUI

enum PremiumStageTone {
    case calm
    case shop
}

/// Shared stage shell for avatar presentation across Home, Shop, and Locker.
struct PremiumAvatarStageContainer<Content: View>: View {
    var tone: PremiumStageTone = .shop
    var accent: Color = RallyUIKit.Palette.cyan
    var height: CGFloat = 480
    @ViewBuilder var content: () -> Content

    private var stageGradient: [Color] {
        switch tone {
        case .calm:
            return [
                Color(red: 0.13, green: 0.12, blue: 0.15),
                Color(red: 0.06, green: 0.06, blue: 0.09),
                Color(red: 0.02, green: 0.02, blue: 0.04),
                Color.black
            ]
        case .shop:
            return [
                Color(red: 0.12, green: 0.13, blue: 0.17),
                Color(red: 0.07, green: 0.08, blue: 0.12),
                Color(red: 0.03, green: 0.03, blue: 0.06),
                Color.black
            ]
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: stageGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Top light wash — editorial studio key
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(tone == .calm ? 0.07 : 0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            Circle()
                .fill((tone == .calm ? RallyUIKit.Palette.champagne : accent).opacity(tone == .calm ? 0.20 : 0.22))
                .frame(width: height * 0.72, height: height * 0.72)
                .blur(radius: 54)
                .offset(x: -height * 0.14, y: -height * 0.20)

            Circle()
                .fill(accent.opacity(tone == .calm ? 0.10 : 0.18))
                .frame(width: height * 0.88, height: height * 0.88)
                .blur(radius: 64)
                .offset(x: height * 0.24, y: -height * 0.02)

            Ellipse()
                .fill((tone == .calm ? RallyUIKit.Palette.cyan : accent).opacity(tone == .calm ? 0.07 : 0.11))
                .frame(width: height * 0.86, height: height * 0.20)
                .blur(radius: 34)
                .offset(y: height * 0.36)

            // Floor reflection pool
            Ellipse()
                .fill(accent.opacity(tone == .calm ? 0.05 : 0.08))
                .frame(width: height * 0.52, height: height * 0.06)
                .blur(radius: 18)
                .offset(y: height * 0.42)

            content()

            // Soft vignette
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [.clear, Color.black.opacity(tone == .calm ? 0.38 : 0.32)],
                        center: .center,
                        startRadius: height * 0.18,
                        endRadius: height * 0.72
                    )
                )
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 28)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                accent.opacity(tone == .calm ? 0.06 : 0.10),
                                Color.black.opacity(0.36)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: height * 0.14)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(tone == .calm ? 0.10 : 0.12),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.32), radius: 32, y: 20)
    }
}

struct AvatarShopStageView: View {
    let config: AvatarConfig
    var preview: (slot: ShopItem.Category, item: ShopItem)?
    var tone: PremiumStageTone = .shop
    @Binding var emote: AvatarShopEmote
    @EnvironmentObject private var avatarAppearanceStore: RallyAvatarAppearanceStore

    var body: some View {
        VStack(spacing: 0) {
            PremiumAvatarStageContainer(
                tone: tone,
                accent: currentAccent,
                height: preview == nil ? 540 : 520
            ) {
                VStack(spacing: 8) {
                    RallyAvatarView(
                        appearance: avatarAppearanceStore.appearance(for: config, previewItem: preview?.item),
                        targetHeight: preview == nil ? 420 : 400,
                        showsRacket: preview?.slot == .racket
                    )
                    .frame(maxWidth: .infinity)
                    if usesStylePreview {
                        Text("Style preview · Garment details may differ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    Text("Drag to rotate · Pinch to zoom")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            }
        }
        .onAppear {
            avatarAppearanceStore.sync(from: config)
        }
    }

    private var currentAccent: Color {
        preview?.item.accentColor ?? preview?.item.color ?? RallyUIKit.Palette.cyan
    }

    private var usesStylePreview: Bool {
        guard let preview, preview.slot == .top || preview.slot == .bottom else { return false }
        let slot: RallyGearSlot = preview.slot == .top ? .top : .shorts
        let representation = RallyGarmentCatalog.shared.reference(for: preview.item.id, slot: slot)?
            .effectiveRepresentation(for: config.athletePreset.athleteModel) ?? .referenceOnly
        return representation == .referenceOnly
    }

    private var emoteScale: CGFloat {
        switch emote {
        case .idle:
            return 1.0
        case .wave:
            return 1.015
        case .celebrate:
            return 1.035
        case .shopLook:
            return 1.02
        }
    }
}
