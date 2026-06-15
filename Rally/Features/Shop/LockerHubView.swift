import SwiftUI
import SwiftData

struct LockerHubView: View {
    @EnvironmentObject private var auth: AuthSession
    @Query private var avatarConfigs: [AvatarConfig]

    @State private var selectedCategory: ShopItem.Category? = nil
    @State private var groupByVendor: Bool = false
    @ObservedObject private var unlocks = CourtUnlocks.shared

    var onPlay: () -> Void

    private var avatar: AvatarConfig? { avatarConfigs.first }

    private var lockerTitle: String {
        let raw = avatar?.playerName.trimmingCharacters(in: .whitespaces) ?? ""
        return raw.isEmpty ? "Player" : raw
    }

    private var equippedIDs: Set<String> {
        guard let a = avatar else { return [] }
        return Set([a.equippedTopID, a.equippedBottomID, a.equippedShoesID, a.equippedRacketID])
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: RallyUIKit.Spacing.xl, pinnedViews: [.sectionHeaders]) {
                        lockerHero
                            .padding(.horizontal, RallyUIKit.Spacing.md)
                            .padding(.top, 4)

                        categoryFilter
                            .padding(.horizontal, RallyUIKit.Spacing.md)

                        if groupByVendor {
                            ForEach(ShopCatalog.itemsGroupedByVendor(), id: \.0.id) { vendor, items in
                                let visible = filtered(items)
                                if !visible.isEmpty {
                                    Section {
                                        lockerDesireGridContent(items: visible)
                                    } header: {
                                        vendorHeader(vendor)
                                    }
                                }
                            }
                            .padding(.horizontal, RallyUIKit.Spacing.md)
                        } else {
                            ForEach(ShopItem.Category.allCases) { category in
                                let items = filtered(ShopCatalog.items(in: category))
                                if !items.isEmpty {
                                    Section {
                                        lockerDesireGridContent(items: items)
                                    } header: {
                                        categoryHeader(category)
                                    }
                                }
                            }
                            .padding(.horizontal, RallyUIKit.Spacing.md)
                        }
                    }
                    .padding(.bottom, 120)
                }

                playNowButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.03, green: 0.04, blue: 0.07), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(lockerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    accountMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        SoundToggleButton()
                        if let avatar = avatar {
                            NavigationLink {
                                AvatarCustomizerView(config: avatar)
                            } label: {
                                Image(systemName: "person.crop.circle")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.cyan)
                            }
                        }
                        Button {
                            groupByVendor.toggle()
                        } label: {
                            Image(systemName: groupByVendor ? "square.grid.2x2.fill" : "person.2.fill")
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
        }
    }

    private var lockerHero: some View {
        PremiumAvatarStageContainer(tone: .calm, accent: RallyUIKit.Palette.champagne, height: 176) {
            ZStack {
                LinearGradient(
                    colors: [
                        RallyUIKit.Palette.obsidian.opacity(0.98),
                        RallyUIKit.Palette.ink.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 0) {
                    Spacer(minLength: 18)

                    ZStack {
                        Ellipse()
                            .fill(RallyUIKit.Palette.champagne.opacity(0.12))
                            .frame(width: 148, height: 42)
                            .blur(radius: 16)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        RallyUIKit.Palette.champagne.opacity(0.80),
                                        RallyUIKit.Palette.gold.opacity(0.42)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 168, height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .overlay {
                                HStack(spacing: 16) {
                                    Image(systemName: "shoe.fill")
                                    Image(systemName: "tshirt.fill")
                                    Image(systemName: "rectangle.fill")
                                }
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                            }
                    }

                    Spacer(minLength: 14)

                    HStack {
                        Text("Locker")
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private var playNowButton: some View {
        Button(action: onPlay) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.title3.weight(.bold))
                Text("Play")
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                        .fill(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                        .stroke(Color.white.opacity(0.30), lineWidth: 1)
                )
                .shadow(color: RallyUIKit.Palette.cyan.opacity(0.32), radius: 16, y: 6)
        }
        .buttonStyle(PlayNowButtonStyle())
        .accessibilityLabel("Play")
    }

    private var accountMenu: some View {
        Menu {
            if auth.isGuestMode {
                Label("Offline on this device", systemImage: "wifi.slash")
            }
            if let email = auth.userEmail {
                Label(email, systemImage: "envelope.fill")
            }
            Button(auth.isGuestMode ? "Leave offline mode…" : "Sign out", role: .destructive) {
                auth.logout()
            }
        } label: {
            Image(systemName: auth.isGuestMode ? "icloud.slash" : "person.text.rectangle")
                .font(.body.weight(.semibold))
                .foregroundStyle(RallyUIKit.Palette.cyan)
        }
        .accessibilityLabel("Account")
    }

    // MARK: - Shop rows (from ShopView)

    private func filtered(_ items: [ShopItem]) -> [ShopItem] {
        let visible = ShopCatalog.visibleItems(
            items,
            unlockedCourtIDs: unlocks.unlockedCourtIDs,
            equippedIDs: equippedIDs
        )
        let owned = visible.filter { isOwned($0) }
        let scoped = selectedCategory == nil ? owned : owned.filter { $0.category == selectedCategory }
        return scoped.sorted { desirabilityScore(for: $0) > desirabilityScore(for: $1) }
    }

    private func isOwned(_ item: ShopItem) -> Bool {
        if equippedIDs.contains(item.id) { return true }
        if item.priceUSD == 0 { return true }
        if ShopCatalog.courtGatedItemIDs.contains(item.id) {
            let unlockedItemIDs = Set(
                unlocks.unlockedCourtIDs.compactMap { ShopCatalog.courtUnlockToShopItem[$0] }
            )
            return unlockedItemIDs.contains(item.id)
        }
        return false
    }

    private var categoryFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    lockerFilterChip(label: "All", selected: selectedCategory == nil, tint: RallyUIKit.Palette.champagne) {
                        selectedCategory = nil
                    }
                    ForEach(ShopItem.Category.allCases) { c in
                        lockerFilterChip(label: c.displayName, selected: selectedCategory == c, tint: categoryTint(c)) {
                            selectedCategory = (selectedCategory == c) ? nil : c
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func categoryHeader(_ category: ShopItem.Category) -> some View {
        HStack(spacing: 10) {
            RallyUIKit.IconBadge(systemName: category.iconSystemName, tint: categoryTint(category), size: 26)
            Text(category.displayName)
                .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private func vendorHeader(_ vendor: Vendor) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vendorTint(vendor.id))
                .frame(width: 8, height: 8)
            Text(vendor.displayName)
                .font(RallyUIKit.Typography.title(.subheadline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Spacer()
            Button {
                RallyReferralLinkRouter.shared.openVenueLink(vendor.websiteURL, venueName: vendor.displayName)
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.7))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.04)))
    }

    private func vendorTint(_ vendorID: String) -> Color {
        switch vendorID {
        case "newbalance": return RallyUIKit.Palette.champagne
        case "nike": return RallyUIKit.Palette.cyan
        case "wilson": return RallyUIKit.Palette.gold
        default: return RallyUIKit.Palette.cloud
        }
    }

    private func lockerDesireGridContent(items: [ShopItem]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 18
        ) {
            ForEach(items) { item in
                lockerDesireTile(item)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func lockerDesireTile(_ item: ShopItem) -> some View {
        let accent = item.accentColor ?? categoryTint(item.category)

        Group {
            if let avatar {
                NavigationLink {
                    ShopItemDetailView(item: item, avatar: avatar, context: .locker)
                } label: {
                    lockerDesireTileContent(item, accent: accent)
                }
            } else {
                lockerDesireTileContent(item, accent: accent)
            }
        }
        .buttonStyle(.plain)
    }

    private func lockerDesireTileContent(_ item: ShopItem, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(lockerTileGradient(accent: accent, itemColor: item.color))
                    .frame(height: 236)

                Circle()
                    .fill(item.color.opacity(0.20))
                    .frame(width: 110, height: 110)
                    .blur(radius: 32)
                    .offset(x: -16, y: -8)

                lockerApparelSwatch(item, tint: accent, width: 156, height: 172)
                    .scaleEffect(item.category == .racket ? 1.02 : 1.08)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isEquipped(item) {
                    HStack {
                        Spacer()
                        detailPill("Wearing", tint: RallyUIKit.Palette.champagne)
                    }
                    .padding(14)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                HStack {
                    Text(rowMeta(item))
                        .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.52))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent.opacity(0.58))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isEquipped(item)
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [RallyUIKit.Palette.champagne, RallyUIKit.Palette.gold.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                          )
                        : AnyShapeStyle(accent.opacity(0.28)),
                    lineWidth: isEquipped(item) ? 2 : 1
                )
        )
        .shadow(
            color: isEquipped(item)
                ? RallyUIKit.Palette.champagne.opacity(0.22)
                : Color.black.opacity(0.18),
            radius: isEquipped(item) ? 18 : 12,
            y: 6
        )
    }

    private func lockerTileGradient(accent: Color, itemColor: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                itemColor.opacity(0.24),
                Color(red: 0.08, green: 0.08, blue: 0.11),
                RallyUIKit.Palette.obsidian,
                accent.opacity(0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func lockerFilterChip(label: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(selected ? Color.white : RallyUIKit.Palette.cloud.opacity(0.72))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(selected ? AnyShapeStyle(RallyUIKit.accentGradient(tint)) : AnyShapeStyle(Color.white.opacity(0.06)))
                )
                .overlay(
                    Capsule()
                        .stroke(selected ? tint : tint.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func lockerCampaignCard(edit: ShopEditorialEdit, items: [ShopItem]) -> some View {
        let tint = edit.tintColor

        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(items.prefix(edit.vendorID == "wilson" ? 1 : 3)) { item in
                lockerTappableSwatch(item, tint: tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            RallyUIKit.Palette.obsidian,
                            tint.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.12), lineWidth: 1))
        .accessibilityLabel(edit.title)
    }

    @ViewBuilder
    private func lockerTappableSwatch(_ item: ShopItem, tint: Color) -> some View {
        if let avatar {
            NavigationLink {
                ShopItemDetailView(item: item, avatar: avatar, context: .locker)
            } label: {
                lockerApparelSwatch(item, tint: tint)
            }
            .buttonStyle(.plain)
        } else {
            lockerApparelSwatch(item, tint: tint)
        }
    }

    private func lockerApparelSwatch(_ item: ShopItem, tint: Color, width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        let accent = item.accentColor ?? tint
        let referralItem = RallyMerchImageResolver.referralItem(for: item)
        let productImageURL = referralItem?.productImageURL
        let productAccent = referralItem.flatMap { Color(hex: $0.accentColorHex) } ?? accent
        let resolvedWidth = width ?? (item.category == .racket ? 220 : 72)
        let resolvedHeight = height ?? (item.category == .racket ? 100 : (item.category == .shoes ? 56 : 84))

        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            item.color.opacity(0.96),
                            productAccent.opacity(0.65),
                            RallyUIKit.Palette.obsidian.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let productImageURL {
                AsyncImage(url: productImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(min(resolvedWidth, resolvedHeight) * 0.10)
                    default:
                        RallyMerchFallbackGlyph(
                            category: item.category,
                            primary: RallyUIKit.Palette.frost,
                            accent: productAccent
                        )
                        .padding(min(resolvedWidth, resolvedHeight) * 0.20)
                    }
                }
            } else {
                RallyMerchFallbackGlyph(
                    category: item.category,
                    primary: RallyUIKit.Palette.frost,
                    accent: productAccent
                )
                .padding(min(resolvedWidth, resolvedHeight) * 0.20)
            }
        }
        .frame(width: resolvedWidth, height: resolvedHeight)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    @ViewBuilder
    private func lockerCampaignChip(_ item: ShopItem, tint: Color) -> some View {
        let accent = item.accentColor ?? categoryTint(item.category)

        Group {
            if let avatar {
                NavigationLink {
                    ShopItemDetailView(item: item, avatar: avatar, context: .locker)
                } label: {
                    lockerChipLabel(item, accent: accent)
                }
            } else {
                lockerChipLabel(item, accent: accent)
            }
        }
        .buttonStyle(.plain)
    }

    private func lockerChipLabel(_ item: ShopItem, accent: Color) -> some View {
        HStack(spacing: 8) {
            Text(item.brand)
                .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
                .lineLimit(1)
            Text(item.category.displayName)
                .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.26)))
        .overlay(Capsule().stroke(accent.opacity(0.16), lineWidth: 1))
    }

    private func hubChip(_ label: String, tint: Color) -> some View {
        Text(label)
            .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(
                Capsule().stroke(tint.opacity(0.18), lineWidth: 1)
            )
    }

    private func rowMeta(_ item: ShopItem) -> String {
        if let racketProfile = ShopCatalog.racketProfile(id: item.id) {
            return "\(racketProfile.headSizeSqIn) sq in · \(racketProfile.weightGrams) g"
        }
        if let vendor = ShopCatalog.vendor(id: item.vendorID)?.displayName {
            return "\(item.category.displayName) · \(vendor)"
        }
        return item.category.displayName
    }

    private func detailPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
            .foregroundStyle(RallyUIKit.Palette.frost)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().stroke(tint.opacity(0.2), lineWidth: 1))
    }

    private func categoryTint(_ category: ShopItem.Category) -> Color {
        switch category {
        case .top: return RallyUIKit.Palette.cyan
        case .bottom: return RallyUIKit.Palette.rose
        case .shoes: return RallyUIKit.Palette.lime
        case .racket: return RallyUIKit.Palette.gold
        case .bag: return RallyUIKit.Palette.coral
        case .accessory: return RallyUIKit.Palette.cloud
        }
    }

    private func isEquipped(_ item: ShopItem) -> Bool {
        guard let avatar = avatar else { return false }
        switch item.category {
        case .top:    return avatar.equippedTopID    == item.id
        case .bottom: return avatar.equippedBottomID == item.id
        case .shoes:  return avatar.equippedShoesID  == item.id
        case .racket: return avatar.equippedRacketID == item.id
        case .bag, .accessory: return false
        }
    }

    private func desirabilityScore(for item: ShopItem) -> Int {
        let vendorWeight: Int
        switch item.vendorID {
        case "newbalance": vendorWeight = 400
        case "nike": vendorWeight = 320
        case "wilson": vendorWeight = 280
        default: vendorWeight = 100
        }

        let categoryWeight: Int
        switch item.category {
        case .top: categoryWeight = 60
        case .bottom: categoryWeight = 50
        case .shoes: categoryWeight = 40
        case .racket: categoryWeight = 55
        case .bag: categoryWeight = 20
        case .accessory: categoryWeight = 10
        }

        return vendorWeight + categoryWeight + Int(item.priceUSD)
    }

    private func editorialLine(for item: ShopItem) -> String {
        switch item.id {
        case "newbalance.tournament.tank.white":
            return "FOUNDATION PIECE"
        case "newbalance.tournament.skort.white":
            return "CLEAN FINISH"
        case "newbalance.coco.cg2.sea.salt":
            return "COCO CG2 HERO"
        case "nike.dri-fit.tee.cobalt":
            return "NIGHT-SESSION TOP"
        case "nike.court.short.black":
            return "MATCH-DAY BASE"
        case "nike.vapor.pro.white":
            return "FAST FINISH"
        case "wilson.pro.staff.97":
            return "CENTER-COURT FRAME"
        default:
            return "CURATED PICK"
        }
    }

    private func vendorSubhead(_ vendor: Vendor, count: Int) -> String {
        switch vendor.id {
        case "newbalance":
            return "\(count) crisp whites and elevated court pieces"
        case "nike":
            return "\(count) sharper match-day layers"
        case "wilson":
            return "\(count) premium frames and hero gear"
        default:
            return "\(count) pieces live now"
        }
    }
}

// MARK: - Play Now press feedback

private struct PlayNowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
