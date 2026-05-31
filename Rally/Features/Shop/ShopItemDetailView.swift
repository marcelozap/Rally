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
    private var relatedItems: [ShopItem] {
        ShopCatalog.allItems.filter {
            $0.id != item.id &&
            $0.vendorID == item.vendorID &&
            $0.category != item.category
        }
    }
    private var travelEditDestinations: [IconicTennisCourt] {
        let ids: [String]

        switch item.vendorID {
        case "newbalance":
            ids = ["wimbledon.cc", "usopen.ashe", "img.bradenton"]
        case "nike":
            ids = ["indianwells", "usopen.ashe", "mouratoglou.fr"]
        case "wilson":
            ids = ["wimbledon.cc", "newport.hof", "rna.mallorca"]
        case "babolat":
            ids = ["rolandgarros.pc", "mouratoglou.fr", "rna.costamujeres"]
        case "yonex":
            ids = ["ausopen.rl", "shanghai.qizhong", "tennis360.dubai"]
        default:
            switch item.category {
            case .top, .bottom, .shoes:
                ids = ["wimbledon.cc", "indianwells", "rna.mallorca"]
            case .racket:
                ids = ["usopen.ashe", "mouratoglou.fr", "img.bradenton"]
            case .bag, .accessory:
                ids = ["montecarlo.mccc", "rome.foro", "barcelona.rctb"]
            }
        }

        let lookup = Dictionary(uniqueKeysWithValues: IconicCourtsCatalog.allCourts.map { ($0.id, $0) })
        return ids.compactMap { lookup[$0] }
    }

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
                    productVisual
                    identityRow
                    if let racketProfile {
                        racketSpecsSection(racketProfile)
                    }
                    if !relatedItems.isEmpty {
                        styleItWithSection
                    }
                    if !travelEditDestinations.isEmpty {
                        wearItToSection
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

    private var productVisual: some View {
        let accent = item.accentColor ?? RallyUIKit.Palette.cyan

        return RallyUIKit.SectionCard(stroke: accent.opacity(0.28)) {
            ZStack {
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                    .fill(
                        LinearGradient(
                            colors: [
                                RallyUIKit.Palette.obsidian,
                                item.color.opacity(0.22),
                                accent.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(item.color.opacity(0.24))
                    .frame(width: 170, height: 170)
                    .blur(radius: 26)
                    .offset(x: -86, y: -44)

                Circle()
                    .fill(accent.opacity(0.22))
                    .frame(width: 150, height: 150)
                    .blur(radius: 24)
                    .offset(x: 112, y: -12)

                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        item.color.opacity(0.96),
                                        accent.opacity(0.74),
                                        RallyUIKit.Palette.obsidian.opacity(0.92)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 128, height: 138)

                        RoundedRectangle(cornerRadius: 26)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            .frame(width: 128, height: 138)

                        Image(systemName: item.category.iconSystemName)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: Color.black.opacity(0.22), radius: 10, y: 6)
                    }

                    HStack(spacing: 10) {
                        detailChip(item.brand, tint: accent)
                        detailChip(item.category.displayName, tint: item.color)
                    }
                }
                .padding(.vertical, 18)
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg))
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
        RallyUIKit.SectionCard(stroke: (item.accentColor ?? RallyUIKit.Palette.cyan).opacity(0.24)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    RallyUIKit.IconBadge(
                        systemName: "checkmark.circle.badge.questionmark",
                        tint: item.accentColor ?? RallyUIKit.Palette.cyan,
                        size: 26
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next step")
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Try it in Rally or move straight to the official product page.")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                    }
                }

                if item.category == .bag || item.category == .accessory {
                    Text("Bag and accessory preview motion is still lighter than apparel and racquets.")
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.58))
                } else if isEquipped {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Equipped")
                    }
                    .font(RallyUIKit.Typography.label(.headline, weight: .bold))
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
    }

    private var styleItWithSection: some View {
        RallyUIKit.SectionCard(stroke: (item.accentColor ?? RallyUIKit.Palette.gold).opacity(0.22)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    RallyUIKit.IconBadge(
                        systemName: "sparkles",
                        tint: item.accentColor ?? RallyUIKit.Palette.gold,
                        size: 26
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Style it with")
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Other pieces from \(item.brand) that keep the look feeling intentional.")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(relatedItems.prefix(4)) { related in
                            relatedStyleCard(related)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var wearItToSection: some View {
        let accent = item.accentColor ?? RallyUIKit.Palette.lime

        return RallyUIKit.SectionCard(stroke: accent.opacity(0.22)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    RallyUIKit.IconBadge(
                        systemName: "globe.europe.africa.fill",
                        tint: RallyUIKit.Palette.lime,
                        size: 26
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wear it to")
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("A few real venues and camps that match this look, all backed by official atlas links.")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(travelEditDestinations) { court in
                            travelEditCard(court)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var referralSection: some View {
        RallyUIKit.LuxePanel(tint: item.accentColor ?? RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    RallyUIKit.IconBadge(
                        systemName: "bag.badge.plus",
                        tint: item.accentColor ?? RallyUIKit.Palette.cyan,
                        size: 26
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Official buy path")
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Rally points to official brand and loyalty pages only.")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                    }
                }

                if let code = item.checkoutPromoCode, !code.isEmpty {
                    HStack {
                        Text(code)
                            .font(RallyUIKit.Typography.title(.title3, weight: .bold).monospaced())
                            .foregroundStyle(RallyUIKit.Palette.gold)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((item.accentColor ?? RallyUIKit.Palette.cyan).opacity(0.18), lineWidth: 1)
                    )
                }

                if let note = item.promoNote, !note.isEmpty {
                    Text(note)
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.68))
                }

                if item.checkoutPromoCode == nil || item.checkoutPromoCode?.isEmpty == true {
                    Text("No bundled code is attached to this item. The official product page is still available below.")
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.58))
                }

                if let vendor = vendor {
                    if let summary = vendor.referralSummary {
                        Text(summary)
                            .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.88))
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
            }
        }
    }

    private func relatedStyleCard(_ related: ShopItem) -> some View {
        let accent = related.accentColor ?? related.color

        return NavigationLink {
            ShopItemDetailView(item: related, avatar: avatar)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    related.color.opacity(0.96),
                                    accent.opacity(0.7),
                                    RallyUIKit.Palette.obsidian.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 108)

                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        .frame(height: 108)

                    Image(systemName: related.category.iconSystemName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.24), radius: 8, y: 5)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(related.name)
                        .font(RallyUIKit.Typography.body(.caption, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        .lineLimit(2)
                    Text(related.priceUSD == 0 ? "Included" : related.priceDisplay)
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
            .padding(12)
            .frame(width: 154, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(accent.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func travelEditCard(_ court: IconicTennisCourt) -> some View {
        NavigationLink {
            CourtDetailView(court: court)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    RallyUIKit.Palette.obsidian,
                                    court.kind == .venue ? RallyUIKit.Palette.cyan.opacity(0.42) : RallyUIKit.Palette.lime.opacity(0.38),
                                    RallyUIKit.Palette.champagne.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 116)

                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        .frame(height: 116)

                    VStack(alignment: .leading, spacing: 8) {
                        detailChip(court.kind.rawValue, tint: court.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.lime)
                        Spacer()
                        Text(court.region)
                            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.78))
                    }
                    .padding(12)

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: court.kind == .venue ? "trophy.fill" : "figure.tennis")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(14)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(court.name)
                        .font(RallyUIKit.Typography.body(.caption, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        .lineLimit(2)
                    Text(court.subtitle)
                        .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.7))
                    Text(court.vibe)
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.84))
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(width: 194, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke((item.accentColor ?? RallyUIKit.Palette.lime).opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
