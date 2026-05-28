import SwiftUI
import SwiftData
import UIKit

struct ShopItemDetailView: View {
    let item: ShopItem
    let avatar: AvatarConfig

    @Environment(\.modelContext) private var modelContext
    @State private var tryingOn: Bool = true
    @State private var stageEmote: AvatarShopEmote = .shopLook

    private var vendor: Vendor? { ShopCatalog.vendor(id: item.vendorID) }
    private var racketProfile: RacketProfile? { ShopCatalog.racketProfile(id: item.id) }

    init(item: ShopItem, avatar: AvatarConfig) {
        self.item = item
        self.avatar = avatar
    }

    var body: some View {
        ScrollView {
            VStack(spacing: RallyUIKit.Spacing.lg) {
                AvatarShopStageView(
                    config: avatar,
                    preview: tryingOn && item.category != .bag && item.category != .accessory
                        ? (slot: item.category, item: item)
                        : nil,
                    emote: $stageEmote
                )
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
                    header
                    identityRow
                    if let racketProfile {
                        racketSpecsSection(racketProfile)
                    }
                    if item.category != .bag, item.category != .accessory {
                        tryOnToggle
                    }
                    actionRow
                    referralSection
                    if let vendor = vendor {
                        vendorCard(vendor)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        RallyUIKit.LuxePanel(tint: item.accentColor ?? RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        RallyUIKit.EditorialEyebrow(
                            text: item.brand,
                            tint: item.accentColor ?? RallyUIKit.Palette.cyan
                        )
                        Text(item.name)
                            .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(item.priceUSD == 0 ? "Included" : item.priceDisplay)
                            .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                            .foregroundStyle(item.accentColor ?? RallyUIKit.Palette.cyan)
                        Text(isEquipped ? "In your current kit" : "Available now")
                            .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
                    }
                }

                HStack(spacing: RallyUIKit.Spacing.xs) {
                    detailChip(item.category.displayName, tint: item.color)
                    if isEquipped {
                        detailChip("Equipped", tint: RallyUIKit.Palette.cyan)
                    }
                    if item.category == .racket {
                        detailChip("Performance frame", tint: item.accentColor ?? RallyUIKit.Palette.gold)
                    }
                }
            }
        }
    }

    private var identityRow: some View {
        RallyUIKit.SectionCard(stroke: (item.accentColor ?? RallyUIKit.Palette.cyan).opacity(0.34)) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                HStack(spacing: RallyUIKit.Spacing.sm) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Color direction")
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.7))
                        Text(item.category.displayName)
                            .font(RallyUIKit.Typography.body(.subheadline, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                    }

                    Spacer()

                    if let vendor {
                        Text(vendor.displayName)
                            .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.82))
                    }
                }

                if let accent = item.accentColor {
                    Divider()
                        .overlay(RallyUIKit.Palette.line)

                    HStack(spacing: RallyUIKit.Spacing.sm) {
                        Circle()
                            .fill(accent)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                        Text("Accent trim")
                            .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.78))
                        Spacer()
                    }
                }
            }
        }
    }

    private var tryOnToggle: some View {
        Toggle(isOn: $tryingOn) {
            HStack(spacing: 8) {
                RallyUIKit.IconBadge(
                    systemName: tryingOn ? "tshirt.fill" : "tshirt",
                    tint: item.accentColor ?? RallyUIKit.Palette.cyan,
                    size: 26
                )
                Text(tryingOn ? "Trying it on" : "Try it on")
            }
            .foregroundStyle(.white)
        }
        .tint(item.accentColor ?? RallyUIKit.Palette.cyan)
        .padding(.vertical, 4)
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            if item.category == .bag || item.category == .accessory {
                Text("Bag & accessory previews coming soon.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            } else if isEquipped {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Equipped")
                }
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(item.accentColor ?? RallyUIKit.Palette.cyan)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill((item.accentColor ?? RallyUIKit.Palette.cyan).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke((item.accentColor ?? RallyUIKit.Palette.cyan).opacity(0.35), lineWidth: 1)
                )
            } else {
                Button {
                    equip()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Equip")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: item.accentColor ?? RallyUIKit.Palette.cyan))
            }

            Link(destination: item.trackingProductURL) {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                    Text(item.priceUSD == 0 ? "View on rally.app" : "Buy at \(item.brand)")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
            }
            .buttonStyle(SecondaryButtonStyle(tint: item.accentColor ?? RallyUIKit.Palette.cyan))
        }
    }

    private var referralSection: some View {
        RallyUIKit.SectionCard(stroke: (item.accentColor ?? RallyUIKit.Palette.cyan).opacity(0.24)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Codes & referrals")
                    .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)

                if let code = item.checkoutPromoCode, !code.isEmpty {
                    HStack {
                        Text(code)
                            .font(.title3.monospaced().weight(.bold))
                            .foregroundStyle(.yellow)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = code
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(SecondaryButtonStyle(tint: item.accentColor ?? RallyUIKit.Palette.cyan))
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                }

                if let note = item.promoNote, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }

                if item.checkoutPromoCode == nil || item.checkoutPromoCode?.isEmpty == true {
                    Text("No bundled code for this item.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                if let vendor = vendor {
                    if let summary = vendor.referralSummary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.cyan.opacity(0.85))
                    }
                    if let loyalty = vendor.loyaltyProgramURL {
                        Link(destination: loyalty) {
                            HStack {
                                Image(systemName: "gift.fill")
                                Text("Official loyalty & member offers")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.cyan))
                    }
                }

                Text("Verify offers at checkout.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private func racketSpecsSection(_ profile: RacketProfile) -> some View {
        RallyUIKit.SectionCard(stroke: (item.accentColor ?? RallyUIKit.Palette.gold).opacity(0.28)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Racquet profile")
                    .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)

                Text(profile.summary)
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    racketStat("Family", profile.family)
                    racketStat("Best for", profile.playerFit)
                    racketStat("Focus", profile.performanceFocus)
                    racketStat("Head size", "\(profile.headSizeSqIn) sq in")
                    racketStat("Weight", "\(profile.weightGrams) g")
                    racketStat("Balance", "\(profile.balanceMM) mm")
                    racketStat("Pattern", profile.stringPattern)
                }
            }
        }
    }

    private func racketStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.42))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func vendorCard(_ vendor: Vendor) -> some View {
        Link(destination: vendor.websiteURL) {
            RallyUIKit.SectionCard(stroke: (item.accentColor ?? RallyUIKit.Palette.cyan).opacity(0.26)) {
                HStack(spacing: 12) {
                    RallyUIKit.IconBadge(
                        systemName: "storefront.fill",
                        tint: item.accentColor ?? RallyUIKit.Palette.cyan,
                        size: 42
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sold by")
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                        Text(vendor.displayName)
                            .font(RallyUIKit.Typography.body(.body, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Official storefront")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.4))
                }
            }
        }
    }

    private var detailSummary: String {
        if let racketProfile {
            return "\(racketProfile.performanceFocus) frame for \(racketProfile.playerFit.lowercased())."
        }
        return "\(item.category.displayName) by \(item.brand)."
    }

    private func detailChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
            .foregroundStyle(RallyUIKit.Palette.frost)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
    }

    private var isEquipped: Bool {
        switch item.category {
        case .top:    return avatar.equippedTopID    == item.id
        case .bottom: return avatar.equippedBottomID == item.id
        case .shoes:  return avatar.equippedShoesID  == item.id
        case .racket: return avatar.equippedRacketID == item.id
        case .bag, .accessory: return false
        }
    }

    private func equip() {
        switch item.category {
        case .top:    avatar.equippedTopID    = item.id
        case .bottom: avatar.equippedBottomID = item.id
        case .shoes:  avatar.equippedShoesID  = item.id
        case .racket: avatar.equippedRacketID = item.id
        case .bag, .accessory: return
        }
        try? modelContext.save()
        RallySyncTriggers.pushAfterLocalSave(modelContext: modelContext)
    }
}
