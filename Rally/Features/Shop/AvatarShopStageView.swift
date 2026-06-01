import SwiftUI

/// Shop-centric avatar presenter: **RealityKit** figure + horizontal emote picker.
/// Keeps try-on previews (`preview`) in sync with the parent sheet/detail row.
struct AvatarShopStageView: View {
    let config: AvatarConfig
    var preview: (slot: ShopItem.Category, item: ShopItem)?
    @Binding var emote: AvatarShopEmote

    var body: some View {
        VStack(spacing: RallyUIKit.Spacing.md) {
            RallyUIKit.LuxePanel(tint: currentAccent) {
                VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xs) {
                            RallyUIKit.EditorialEyebrow(
                                text: preview == nil ? "Player Studio" : "Fitting Room",
                                tint: currentAccent
                            )
                            Text(preview == nil ? "Sibling style preview" : "Live outfit check")
                                .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                        }

                        Spacer()

                        HStack(spacing: RallyUIKit.Spacing.xs) {
                            RallyUIKit.IconBadge(
                                systemName: preview == nil ? "figure.tennis" : previewCategoryIcon,
                                tint: currentAccent,
                                size: 36
                            )
                            if preview != nil {
                                Text("Preview")
                                    .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                                    .tracking(1.3)
                                    .foregroundStyle(RallyUIKit.Palette.frost)
                                    .padding(.horizontal, RallyUIKit.Spacing.sm)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.08))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(currentAccent.opacity(0.26), lineWidth: 1)
                                    )
                            }
                        }
                    }

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        RallyUIKit.Palette.obsidian,
                                        RallyUIKit.Palette.ink,
                                        Color.black
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(alignment: .topLeading) {
                                Circle()
                                    .fill(currentAccent.opacity(0.18))
                                    .frame(width: 190, height: 190)
                                    .blur(radius: 28)
                                    .offset(x: -28, y: -26)
                            }
                            .overlay(alignment: .topTrailing) {
                                Circle()
                                    .fill(RallyUIKit.Palette.champagne.opacity(0.10))
                                    .frame(width: 150, height: 150)
                                    .blur(radius: 24)
                                    .offset(x: 18, y: -18)
                            }
                            .overlay {
                                StageCourtOverlay(accent: currentAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl))
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl)
                                    .stroke(currentAccent.opacity(0.22), lineWidth: 1)
                            )

                        AvatarRealityKitView(
                            spec: AvatarVisualSpec.from(config: config, preview: preview),
                            emote: emote
                        )
                        .frame(height: 316)
                        .padding(.top, RallyUIKit.Spacing.xs)

                        stageFooter
                            .padding(RallyUIKit.Spacing.md)
                    }
                    .frame(height: 360)

                    HStack(spacing: RallyUIKit.Spacing.xs) {
                        stageChip(preview == nil ? "Editorial fit" : "Trying on", tint: currentAccent)
                        stageChip(preview == nil ? "Ready for shop" : "Preview mode", tint: RallyUIKit.Palette.champagne)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: RallyUIKit.Spacing.sm) {
                            ForEach(AvatarShopEmote.allCases) { e in
                                emoteChip(e)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
    }

    private var stageFooter: some View {
        HStack(spacing: RallyUIKit.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preview?.item.brand ?? "Rally Edit")
                    .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.78))
                Text(preview?.item.name ?? "Current favorite look")
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: RallyUIKit.Spacing.xs) {
                Image(systemName: emote.symbolName)
                Text(emote.label)
                    .lineLimit(1)
            }
            .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
            .foregroundStyle(RallyUIKit.Palette.frost)
            .padding(.horizontal, RallyUIKit.Spacing.sm)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.26))
            )
            .overlay(
                Capsule()
                    .stroke(RallyUIKit.Palette.line.opacity(0.8), lineWidth: 1)
            )
        }
        .padding(.horizontal, RallyUIKit.Spacing.md)
        .padding(.vertical, RallyUIKit.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(Color.black.opacity(0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .stroke(RallyUIKit.Palette.line.opacity(0.7), lineWidth: 1)
        )
    }

    private var currentAccent: Color {
        preview?.item.accentColor ?? preview?.item.color ?? RallyUIKit.Palette.cyan
    }

    private var previewCategoryIcon: String {
        preview?.slot.iconSystemName ?? "figure.tennis"
    }

    private var stageSummary: String {
        if let preview {
            return "Preview \(preview.item.name)."
        }
        return "Browse the current fit."
    }

    private func emoteChip(_ e: AvatarShopEmote) -> some View {
        let selected = emote == e
        return Button {
            emote = e
        } label: {
            HStack(spacing: RallyUIKit.Spacing.xs) {
                Image(systemName: e.symbolName)
                    .font(.system(size: 13, weight: .bold))
                Text(e.label)
                    .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.frost)
            .padding(.horizontal, RallyUIKit.Spacing.sm)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        selected
                            ? AnyShapeStyle(RallyUIKit.accentGradient(currentAccent))
                            : AnyShapeStyle(Color.white.opacity(0.06))
                    )
            )
            .overlay(
                Capsule()
                    .stroke(selected ? Color.white.opacity(0.26) : currentAccent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func stageChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(RallyUIKit.Palette.frost)
            .padding(.horizontal, RallyUIKit.Spacing.sm)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().stroke(tint.opacity(0.2), lineWidth: 1))
    }
}

private struct StageCourtOverlay: View {
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.clear,
                    accent.opacity(0.08),
                    RallyUIKit.Palette.champagne.opacity(0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.02),
                                accent.opacity(0.07)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 110)
            }

            RoundedRectangle(cornerRadius: 26)
                .stroke(accent.opacity(0.08), lineWidth: 1)
                .padding(18)

            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 1)
                .padding(.vertical, 48)

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .padding(.horizontal, 58)
                .offset(y: 54)

            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: 220, height: 34)
                .blur(radius: 14)
                .offset(y: 114)
        }
    }
}
