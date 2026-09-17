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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [RallyUIKit.Palette.slate, RallyUIKit.Palette.ink, RallyUIKit.Palette.obsidian],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geometry in
                let width = geometry.size.width
                let floor = geometry.size.height * 0.82
                Path { path in
                    path.move(to: CGPoint(x: 0, y: floor))
                    path.addLine(to: CGPoint(x: width, y: floor))
                    for fraction in [CGFloat(0.15), 0.5, 0.85] {
                        path.move(to: CGPoint(x: width * fraction, y: floor))
                        path.addLine(to: CGPoint(x: width * (fraction - 0.5) * 1.8 + width * 0.5, y: geometry.size.height))
                    }
                }
                .stroke(RallyUIKit.Palette.champagne.opacity(0.10), lineWidth: 1)

                RoundedRectangle(cornerRadius: width * 0.44)
                    .fill(RallyUIKit.Palette.champagne.opacity(tone == .calm ? 0.035 : 0.06))
                    .frame(width: width * 0.70, height: height * 0.85)
                    .position(x: width * 0.5, y: height * 0.47)
            }
            .allowsHitTesting(false)

            RadialGradient(
                colors: [RallyUIKit.Palette.champagne.opacity(0.10), .clear],
                center: .topLeading,
                startRadius: 12,
                endRadius: height * 0.8
            )
            .allowsHitTesting(false)

            content()
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.white.opacity(0.11), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
    }
}

struct AvatarShopStageView: View {
    let config: AvatarConfig
    var preview: (slot: ShopItem.Category, item: ShopItem)?
    var tone: PremiumStageTone = .shop
    @Binding var emote: AvatarShopEmote
    @EnvironmentObject private var avatarAppearanceStore: RallyAvatarAppearanceStore

    var body: some View {
        PremiumAvatarStageContainer(tone: tone, accent: currentAccent, height: 438) {
            VStack(spacing: 0) {
                HStack {
                    Text(preview == nil ? "YOUR PLAYER" : "FITTING ROOM")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.7)
                        .foregroundStyle(RallyUIKit.Palette.champagne)
                    Spacer()
                    Text(config.athletePreset.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                RallyAvatarView(
                    appearance: avatarAppearanceStore.appearance(for: config, previewItem: preview?.item),
                    targetHeight: 340,
                    showsRacket: preview == nil || preview?.slot == .racket
                )
                .frame(maxWidth: .infinity)
                .frame(height: 340)

                VStack(spacing: 5) {
                    if usesStylePreview {
                        Text("Style preview · Garment details may differ")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.champagne)
                    }
                    Label("Drag to rotate · Pinch to zoom", systemImage: "rotate.3d")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 15)
                Spacer(minLength: 0)
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
