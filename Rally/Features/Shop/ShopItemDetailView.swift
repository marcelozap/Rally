import SwiftUI
import SwiftData
import UIKit
import SafariServices

enum ShopItemDetailContext {
    case shop
    case locker
}

struct ShopItemDetailView: View {
    let item: ShopItem
    let avatar: AvatarConfig
    var context: ShopItemDetailContext = .shop

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var avatarAppearanceStore: RallyAvatarAppearanceStore
    @State private var tryingOn: Bool = true
    @State private var stageEmote: AvatarShopEmote = .shopLook

    private var vendor: Vendor? { ShopCatalog.vendor(id: item.vendorID) }
    private var racketProfile: RacketProfile? { ShopCatalog.racketProfile(id: item.id) }
    /// Live commerce data from the referral catalog, if this item has an entry.
    private var referralItem: RallyGearItem? { RallyReferralCatalog.referralItem(matchingShopItemID: item.id) }
    private var relatedItems: [ShopItem] {
        ShopCatalog.allItems.filter {
            $0.id != item.id &&
            $0.vendorID == item.vendorID &&
            $0.category != item.category
        }
        .sorted { companionScore(for: $0) > companionScore(for: $1) }
    }
    private var editorialEdit: ShopEditorialEdit? {
        ShopCatalog.editorialEdits.first { $0.itemIDs.contains(item.id) }
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

    init(item: ShopItem, avatar: AvatarConfig, context: ShopItemDetailContext = .shop) {
        self.item = item
        self.avatar = avatar
        self.context = context
    }

    private var isLocker: Bool { context == .locker }

    var body: some View {
        ScrollView {
            VStack(spacing: RallyUIKit.Spacing.xl) {
                AvatarShopStageView(
                    config: avatar,
                    preview: tryingOn && item.category != .bag && item.category != .accessory
                        ? (slot: item.category, item: item)
                        : nil,
                    tone: isLocker ? .calm : .shop,
                    emote: $stageEmote
                )

                productVisualHero

                if let racketProfile {
                    racketSpecsSection(racketProfile)
                }

                if item.category != .bag, item.category != .accessory {
                    tryOnToggle
                }

                actionRow

                if !relatedItems.isEmpty {
                    relatedItemsRail
                }

                if !isLocker, let vendor = vendor {
                    vendorLink(vendor)
                }
            }
            .padding(.horizontal, RallyUIKit.Spacing.md)
            .padding(.top, 8)
            .padding(.bottom, 48)
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if canTryOnItem, tryingOn {
                avatarAppearanceStore.tryOn(item, from: avatar)
            }
        }
    }

    private var productVisualHero: some View {
        let accent = item.accentColor ?? RallyUIKit.Palette.cyan

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.brand.uppercased())
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .tracking(2.2)
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.52))
                    Text(item.name)
                        .font(RallyUIKit.Typography.display(28, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if isLocker {
                    Text(isEquipped ? "Wearing" : item.category.displayName)
                        .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.champagne.opacity(0.82))
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(item.priceUSD == 0 ? "Included" : item.priceDisplay)
                            .font(RallyUIKit.Typography.display(26, weight: .bold))
                            .foregroundStyle(accent)
                        Text(isEquipped ? "Equipped" : item.category.displayName)
                            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.52))
                    }
                }
            }

            // Product image — AsyncImage when the referral catalog has a URL;
            // branded gradient + icon fallback only if no image is available.
            // S-3 audit gate: SF Symbol is never the final/terminal visual state
            // when a productImageURL exists.
            ZStack {
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                item.color.opacity(0.58),
                                RallyUIKit.Palette.obsidian,
                                Color.black
                            ],
                            center: .topLeading,
                            startRadius: 24,
                            endRadius: 300
                        )
                    )
                    .frame(height: 220)

                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 180, height: 180)
                    .blur(radius: 40)
                    .offset(x: 80, y: -20)

                if let imageURL = referralItem?.productImageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 188)
                                .padding(12)
                        case .failure:
                            // Real network failure — show branded fallback,
                            // not a generic SF Symbol.
                            productIconFallback(accent: accent)
                        case .empty:
                            ProgressView()
                                .tint(accent)
                        @unknown default:
                            productIconFallback(accent: accent)
                        }
                    }
                } else {
                    productIconFallback(accent: accent)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private var relatedItemsRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isLocker ? "Style with" : "Pair with")
                .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(relatedItems.prefix(5)) { related in
                        relatedStyleCard(related)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    /// Branded gradient + category icon shown when no productImageURL is available.
    @ViewBuilder
    private func productIconFallback(accent: Color) -> some View {
        Image(systemName: item.category.iconSystemName)
            .font(.system(size: item.category == .racket ? 92 : 76, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .white.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: accent.opacity(0.36), radius: 18, y: 10)
    }

    private func vendorLink(_ vendor: Vendor) -> some View {
        Button {
            // Route through RallyReferralLinkRouter — never raw openURL.
            RallyReferralLinkRouter.shared.openVenueLink(vendor.websiteURL, venueName: vendor.displayName)
        } label: {
            HStack(spacing: 12) {
                Text(vendor.displayName)
                    .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Spacer()
                Label("Open", systemImage: "arrow.up.right")
                    .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                    .foregroundStyle(item.accentColor ?? RallyUIKit.Palette.cyan)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke((item.accentColor ?? RallyUIKit.Palette.cyan).opacity(0.16), lineWidth: 1)
            )
        }
    }

    private var campaignHeroBand: some View {
        let accent = item.accentColor ?? RallyUIKit.Palette.cyan

        return ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    RallyUIKit.Palette.obsidian,
                    item.color.opacity(0.32),
                    accent.opacity(0.22),
                    RallyUIKit.Palette.ink
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(item.color.opacity(0.28))
                .frame(width: 240, height: 240)
                .blur(radius: 40)
                .offset(x: -80, y: -60)

            Circle()
                .fill(accent.opacity(0.24))
                .frame(width: 200, height: 200)
                .blur(radius: 36)
                .offset(x: 120, y: -20)

            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        RallyUIKit.EditorialEyebrow(
                            text: editorialEdit?.eyebrow ?? "\(item.brand) · SS26",
                            tint: accent
                        )
                        Text(item.name)
                            .font(RallyUIKit.Typography.display(34, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(campaignPullQuote)
                            .font(RallyUIKit.Typography.title(.title3, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.88))
                            .italic()
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(item.priceUSD == 0 ? "Included" : item.priceDisplay)
                            .font(RallyUIKit.Typography.display(28, weight: .bold))
                            .foregroundStyle(accent)
                        Text(isEquipped ? "In kit" : "On floor")
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                    }
                }

                HStack(spacing: 8) {
                    detailChip(item.brand, tint: accent)
                    detailChip(item.category.displayName, tint: item.color)
                    if isEquipped { detailChip("Equipped", tint: RallyUIKit.Palette.cyan) }
                    if let editorialEdit {
                        detailChip(editorialEdit.title, tint: RallyUIKit.Palette.champagne)
                    }
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [
                                    item.color.opacity(0.96),
                                    accent.opacity(0.78),
                                    RallyUIKit.Palette.obsidian.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)

                    Image(systemName: item.category.iconSystemName)
                        .font(.system(size: item.category == .racket ? 72 : 56, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 14, y: 8)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .frame(minHeight: 420)
    }

    private var productStoryBlock: some View {
        let accent = item.accentColor ?? RallyUIKit.Palette.cyan

        return RallyUIKit.LuxePanel(tint: accent) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
                Text("THE STORY")
                    .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(accent.opacity(0.9))

                Text(detailSummary)
                    .font(RallyUIKit.Typography.body(.body, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                Text(styleDirectionBody)
                    .font(RallyUIKit.Typography.title(.title3, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)

                Text(productManifesto)
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.smoke.opacity(0.94))

                HStack(spacing: 8) {
                    detailChip(styleDirectionTitle, tint: accent)
                    if item.category == .racket {
                        detailChip("Performance icon", tint: RallyUIKit.Palette.gold)
                    } else {
                        detailChip("Editorial hero", tint: RallyUIKit.Palette.champagne)
                    }
                }
            }
        }
    }

    private var campaignPullQuote: String {
        if let editorialEdit { return editorialEdit.subtitle }
        switch item.vendorID {
        case "newbalance": return "Quiet tournament luxury."
        case "nike": return "Sharper contrast, faster silhouette."
        case "wilson": return "Big-match frame energy."
        default: return "Curated for the Rally floor."
        }
    }

    private var productManifesto: String {
        switch item.vendorID {
        case "newbalance":
            return "Every white layer should feel intentional — premium base, clean finish, match-ready pace."
        case "nike":
            return "Contrast is the story: deep color up top, grounded base below, crisp white underfoot."
        case "wilson":
            return "The racket leads the look. Shape, balance, and presence before utility copy."
        default:
            return "Headline product energy — shape and color justify its place in the kit."
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
                        Text("Style direction")
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.7))
                        Text(styleDirectionTitle)
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

                Text(styleDirectionBody)
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))

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
        Button {
            setTryingOn(!tryingOn)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tryingOn ? "tshirt.fill" : "tshirt")
                    .font(.body.weight(.bold))
                Text(tryOnToggleLabel)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
            }
            .foregroundStyle(tryingOn ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.frost)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(tryingOn ? (item.accentColor ?? RallyUIKit.Palette.cyan) : Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var tryOnToggleLabel: String {
        if isLocker {
            return tryingOn ? "Wearing" : "Wear"
        }
        return tryingOn ? "Trying on" : "Try on"
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            if item.category == .bag || item.category == .accessory {
                EmptyView()
            } else if isEquipped {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.bold))
                    Text("Equipped")
                        .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                }
                .foregroundStyle(item.accentColor ?? RallyUIKit.Palette.cyan)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill((item.accentColor ?? RallyUIKit.Palette.cyan).opacity(0.12))
                )
            } else {
                Button {
                    equip()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isLocker ? "tshirt.fill" : "checkmark.circle.fill")
                            .font(.title3.weight(.bold))
                        Text(isLocker ? "Wear" : "Equip")
                            .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: item.accentColor ?? RallyUIKit.Palette.cyan))
            }

            if !isLocker {
                // Route through RallyReferralLinkRouter — S-5 audit gate.
                // Prefer the referral catalog URL (has {REFERRAL_CODE} injection);
                // fall back to the ShopItem trackingProductURL.
                let shopURL = referralItem?.referralURL ?? item.trackingProductURL
                Button {
                    if let gearItem = referralItem {
                        RallyReferralLinkRouter.shared.openProduct(gearItem)
                    } else {
                        RallyReferralLinkRouter.shared.open(shopURL, context: "shop:\(item.id)")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cart.fill")
                            .font(.title3.weight(.bold))
                        Text(item.priceUSD == 0 ? "View product" : "Buy · \(item.priceDisplay)")
                            .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
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
                        Text(styleItWithCopy)
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
                        Button {
                            RallyReferralLinkRouter.shared.openVenueLink(loyalty, venueName: vendor.displayName + " loyalty")
                        } label: {
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
            ShopItemDetailView(item: related, avatar: avatar, context: context)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    RallyUIKit.Palette.obsidian,
                                    related.color.opacity(0.52),
                                    accent.opacity(0.34)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: related.category.iconSystemName)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.25), radius: 8, y: 5)
                }

                Text(related.name)
                    .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                    .lineLimit(2)
                    .frame(width: 120, alignment: .leading)

                if !isLocker {
                    Text(related.priceUSD == 0 ? "Included" : related.priceDisplay)
                        .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
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
        Button {
            RallyReferralLinkRouter.shared.openVenueLink(vendor.websiteURL, venueName: vendor.displayName)
        } label: {
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
        .buttonStyle(.plain)
    }

    private var detailSummary: String {
        if let editorialEdit {
            return editorialEdit.body
        }
        if let racketProfile {
            return "\(racketProfile.performanceFocus) frame for \(racketProfile.playerFit.lowercased())."
        }
        return "\(item.category.displayName) by \(item.brand)."
    }

    private var styleDirectionTitle: String {
        switch item.vendorID {
        case "newbalance":
            return "Quiet tournament luxury"
        case "nike":
            return "Night-session sharpness"
        case "wilson":
            return "Center-court statement"
        default:
            return item.category.displayName
        }
    }

    private var styleDirectionBody: String {
        switch item.id {
        case "newbalance.tournament.tank.white":
            return "A clean white base that makes the whole fit feel premium immediately."
        case "newbalance.tournament.skort.white":
            return "Keeps the silhouette polished without losing match-ready pace."
        case "newbalance.coco.cg2.sea.salt":
            return "The finishing shoe that gives the whites edit real presence."
        case "nike.dri-fit.tee.cobalt":
            return "Deep cobalt pulls the eye up and gives the outfit sharper contrast."
        case "nike.court.short.black":
            return "A grounded base layer that makes the Nike top and shoe pop harder."
        case "nike.vapor.pro.white":
            return "Bright white underfoot keeps the darker match edit feeling crisp."
        case "wilson.pro.staff.97":
            return "Wilson's Clash 100 V3 reads premium first and competitive second."
        default:
            return "A concise piece that fits neatly into the Rally shop edit."
        }
    }

    private var styleItWithCopy: String {
        switch item.vendorID {
        case "newbalance":
            return "Build the full whites edit around it."
        case "nike":
            return "Pair it into the sharper match-night look."
        case "wilson":
            return "Keep the frame story premium with matching Wilson gear."
        default:
            return "Other pieces from \(item.brand) that keep the look intentional."
        }
    }

    private var nextStepCopy: String {
        switch item.vendorID {
        case "newbalance":
            return "Try the whites edit on, then jump to the official New Balance page."
        case "nike":
            return "Check the silhouette in Rally, then open the official Nike product path."
        case "wilson":
            return "See the frame on stage, then move to Wilson's official storefront."
        default:
            return "Try it in Rally or move straight to the official product page."
        }
    }

    private func companionScore(for candidate: ShopItem) -> Int {
        let categoryWeight: Int
        switch candidate.category {
        case .top: categoryWeight = 40
        case .bottom: categoryWeight = 35
        case .shoes: categoryWeight = 30
        case .racket: categoryWeight = 45
        case .bag: categoryWeight = 20
        case .accessory: categoryWeight = 10
        }
        return categoryWeight + Int(candidate.priceUSD)
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

    private var canTryOnItem: Bool {
        item.category != .bag && item.category != .accessory
    }

    private func setTryingOn(_ enabled: Bool) {
        guard canTryOnItem else { return }
        tryingOn = enabled
        if enabled {
            avatarAppearanceStore.tryOn(item, from: avatar)
            stageEmote = .shopLook
        } else {
            avatarAppearanceStore.clearTryOn(from: avatar)
            stageEmote = .idle
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
        // North Star law 4: gear selection writes to the shared appearance
        // store so Home, Locker, and GameScene update immediately (A-4/S-4).
        // Without this, the store stays stale until another surface's
        // onAppear happens to re-sync.
        avatarAppearanceStore.commitPersisted(from: avatar)
        RallySyncTriggers.pushAvatarAfterLocalSave(modelContext: modelContext)
    }
}
