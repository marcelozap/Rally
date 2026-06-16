import SwiftUI
import SwiftData

struct ShopView: View {
    @EnvironmentObject private var avatarAppearanceStore: RallyAvatarAppearanceStore
    @Query private var avatarConfigs: [AvatarConfig]
    @State private var selectedCategory: ShopItem.Category? = nil
    @State private var groupByVendor: Bool = false
    @ObservedObject private var unlocks = CourtUnlocks.shared
    @AppStorage("shopHasUnseenUnlock") private var shopHasUnseenUnlock = false

    // Live try-on state — updated when the player taps any item card.
    @State private var tryOnItem: ShopItem?
    @State private var stageEmote: AvatarShopEmote = .idle

    private var avatar: AvatarConfig? { avatarConfigs.first }

    private var equippedIDs: Set<String> {
        guard let a = avatar else { return [] }
        return Set([a.equippedTopID, a.equippedBottomID, a.equippedShoesID, a.equippedRacketID])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: RallyUIKit.Spacing.xl, pinnedViews: [.sectionHeaders]) {
                    shopHero
                        .padding(.top, 4)

                    categoryFilter

                    if groupByVendor {
                        ForEach(ShopCatalog.itemsGroupedByVendor(), id: \.0.id) { vendor, items in
                            let visible = filtered(items)
                            if !visible.isEmpty {
                                Section {
                                    desireGrid(items: visible)
                                } header: {
                                    vendorHeader(vendor)
                                }
                            }
                        }
                    } else {
                        ForEach(ShopItem.Category.allCases) { category in
                            let items = filtered(ShopCatalog.items(in: category))
                            if !items.isEmpty {
                                Section {
                                    desireGrid(items: items)
                                } header: {
                                    categoryHeader(category)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, RallyUIKit.Spacing.md)
                .padding(.bottom, 40)
            }
            .background(RallyUIKit.screenBackground)
            .navigationTitle("Shop")
            .onAppear { shopHasUnseenUnlock = false }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        groupByVendor.toggle()
                    } label: {
                        Image(systemName: groupByVendor ? "person.2.fill" : "square.grid.2x2.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(groupByVendor ? RallyUIKit.Palette.rose : RallyUIKit.Palette.cyan)
                    }
                    .accessibilityLabel(groupByVendor ? "Group by brand" : "Group by category")
                }
            }
        }
    }

    // MARK: - Shop Hero (full avatar stage)

    private var shopHero: some View {
        Group {
            if let avatar {
                AvatarShopStageView(
                    config: avatar,
                    preview: tryOnPreview,
                    tone: .shop,
                    emote: $stageEmote
                )
                .overlay(alignment: .bottom) {
                    if let item = tryOnItem {
                        tryOnBanner(item: item)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: tryOnItem?.id)
            } else {
                // Placeholder while SwiftData loads the avatar config.
                PremiumAvatarStageContainer(tone: .shop, accent: RallyUIKit.Palette.cyan, height: 440) {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "figure.tennis")
                            .font(.system(size: 52, weight: .ultraLight))
                            .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.35))
                        Text("Getting your player ready…")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.38))
                        Spacer()
                    }
                }
            }
        }
    }

    /// Resolves the preview tuple fed into `AvatarShopStageView`.
    /// Bags and accessories have no body slot so they can't be previewed.
    private var tryOnPreview: (slot: ShopItem.Category, item: ShopItem)? {
        guard let item = tryOnItem,
              item.category != .bag,
              item.category != .accessory else { return nil }
        return (slot: item.category, item: item)
    }

    /// Banner that floats at the bottom of the stage while a try-on is active.
    /// Shows item name, accent dot, and a Details link.
    private func tryOnBanner(item: ShopItem) -> some View {
        let accent = item.accentColor ?? categoryTint(item.category)
        return HStack(spacing: 10) {
            Circle()
                .fill(accent)
                .frame(width: 7, height: 7)
            Text(item.name)
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let avatar {
                NavigationLink {
                    ShopItemDetailView(item: item, avatar: avatar)
                } label: {
                    HStack(spacing: 5) {
                        Text("Details")
                            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(accent.opacity(0.18)))
                    .overlay(Capsule().stroke(accent.opacity(0.28), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func filtered(_ items: [ShopItem]) -> [ShopItem] {
        let visible = ShopCatalog.visibleItems(
            items,
            unlockedCourtIDs: unlocks.unlockedCourtIDs,
            equippedIDs: equippedIDs
        )
        let scoped = selectedCategory == nil ? visible : visible.filter { $0.category == selectedCategory }
        return scoped.sorted { desirabilityScore(for: $0) > desirabilityScore(for: $1) }
    }

    private var categoryFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(label: "All", selected: selectedCategory == nil, tint: RallyUIKit.Palette.champagne) {
                        selectedCategory = nil
                    }
                    ForEach(ShopItem.Category.allCases) { category in
                        filterChip(label: category.displayName, selected: selectedCategory == category, tint: categoryTint(category)) {
                            selectedCategory = (selectedCategory == category) ? nil : category
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func travelPreviewCard(_ court: IconicTennisCourt) -> some View {
        let tint = court.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(court.name)
                        .font(RallyUIKit.Typography.body(.caption, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        .lineLimit(2)
                    Text(court.subtitle)
                        .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                RallyUIKit.IconBadge(
                    systemName: court.kind == .venue ? "sportscourt.fill" : "figure.tennis",
                    tint: tint,
                    size: 26
                )
            }

            HStack(spacing: 8) {
                travelMiniChip(court.kind == .venue ? "Venue" : "Camp", tint: tint)
                travelMiniChip("Official", tint: RallyUIKit.Palette.rose)
            }

            Text(court.vibe)
                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.84))
                .lineLimit(2)
        }
        .padding(12)
        .frame(width: 198, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
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

    private func desireGrid(items: [ShopItem]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ],
            spacing: 22
        ) {
            ForEach(items) { item in
                desireTile(item)
            }
        }
        .padding(.vertical, RallyUIKit.Spacing.xs)
    }

    @ViewBuilder
    private func desireTile(_ item: ShopItem) -> some View {
        let accent = item.accentColor ?? categoryTint(item.category)
        let isTryingOn = tryOnItem?.id == item.id

        // Primary tap = live try-on in the hero stage above.
        // Details link lives inside the tile info row.
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                tryOnItem = item
                avatarAppearanceStore.tryOn(item, from: avatar)
                stageEmote = .shopLook
            }
        } label: {
            desireTileContent(item, accent: accent, isTryingOn: isTryingOn)
        }
        .buttonStyle(.plain)
    }

    private func desireTileContent(_ item: ShopItem, accent: Color, isTryingOn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(shopTileGradient(accent: accent, itemColor: item.color))
                    .frame(height: 236)

                // Soft color bloom behind the product image
                Circle()
                    .fill(item.color.opacity(isTryingOn ? 0.34 : 0.22))
                    .frame(width: 120, height: 120)
                    .blur(radius: 36)
                    .offset(x: -20, y: -10)
                    .animation(.easeInOut(duration: 0.3), value: isTryingOn)

                apparelSwatch(item, width: 148, height: 168)
                    .scaleEffect(isTryingOn ? 0.96 : 0.92)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shadow(color: accent.opacity(isTryingOn ? 0.38 : 0.24), radius: 22, y: 12)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTryingOn)

                HStack {
                    vendorDot(for: item)
                    Spacer()
                    if isTryingOn {
                        Text("ON")
                            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(accent.opacity(0.18)))
                            .overlay(Capsule().stroke(accent.opacity(0.32), lineWidth: 1))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(14)

                if isEquipped(item) && !isTryingOn {
                    HStack {
                        Spacer()
                        detailPill("Equipped", tint: RallyUIKit.Palette.cyan)
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
                Text(rowMeta(item))
                    .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.54))
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline) {
                    Text(item.priceUSD == 0 ? "Included" : item.priceDisplay)
                        .font(RallyUIKit.Typography.title(.subheadline, weight: .bold))
                        .foregroundStyle(accent)
                    Spacer()
                    // Details link — secondary action, navigates to full item sheet.
                    if let avatar {
                        NavigationLink {
                            ShopItemDetailView(item: item, avatar: avatar)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Details")
                                    .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(accent.opacity(0.78))
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(isTryingOn ? 0.06 : 0.035))
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isTryingOn
                        ? AnyShapeStyle(accent.opacity(0.55))
                        : AnyShapeStyle(LinearGradient(
                            colors: [accent.opacity(0.22), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )),
                    lineWidth: isTryingOn ? 1.5 : 1
                )
        )
        .shadow(
            color: isTryingOn ? accent.opacity(0.22) : Color.black.opacity(0.20),
            radius: isTryingOn ? 20 : 14,
            y: 8
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isTryingOn)
    }

    private func overviewStat(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, RallyUIKit.Spacing.sm)
        .padding(.horizontal, RallyUIKit.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        )
    }

    private func filterChip(label: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(selected ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.frost)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(selected ? AnyShapeStyle(RallyUIKit.accentGradient(tint)) : AnyShapeStyle(Color.white.opacity(0.06)))
                )
                .overlay(
                    Capsule()
                        .stroke(selected ? Color.clear : tint.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
        case .top: return avatar.equippedTopID == item.id
        case .bottom: return avatar.equippedBottomID == item.id
        case .shoes: return avatar.equippedShoesID == item.id
        case .racket: return avatar.equippedRacketID == item.id
        case .bag, .accessory: return false
        }
    }

    private func campaignStoryCard(edit: ShopEditorialEdit, items: [ShopItem]) -> some View {
        editorialMoodBoard(edit: edit, items: items, tint: edit.tintColor)
            .accessibilityLabel(edit.title)
    }

    private func brandVisualCard(vendorID: String, label: String, tint: Color) -> some View {
        let items = filtered(ShopCatalog.allItems.filter { $0.vendorID == vendorID })
        let heroItem = items.first

        return Group {
            if let heroItem, let avatar {
                NavigationLink {
                    ShopItemDetailView(item: heroItem, avatar: avatar)
                } label: {
                    brandVisualCardContent(label: label, tint: tint, heroItem: heroItem)
                }
            } else {
                brandVisualCardContent(label: label, tint: tint, heroItem: heroItem)
            }
        }
        .buttonStyle(.plain)
    }

    private func brandVisualCardContent(label: String, tint: Color, heroItem: ShopItem?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            RallyUIKit.Palette.obsidian,
                            (heroItem?.color ?? tint).opacity(0.46),
                            tint.opacity(0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 120)

            if let heroItem {
                // Same S-3 rule as apparelSwatch: real imagery first,
                // custom court-gear silhouette only while loading/failing.
                if let imageURL = RallyMerchImageResolver.referralItem(for: heroItem)?.productImageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                        default:
                            RallyMerchFallbackGlyph(
                                category: heroItem.category,
                                primary: RallyUIKit.Palette.frost,
                                accent: tint
                            )
                            .padding(18)
                        }
                    }
                } else {
                    RallyMerchFallbackGlyph(
                        category: heroItem.category,
                        primary: RallyUIKit.Palette.frost,
                        accent: tint
                    )
                    .padding(18)
                }
            }
        }
        .frame(width: 100, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func campaignProductChip(_ item: ShopItem, tint: Color) -> some View {
        let accent = item.accentColor ?? categoryTint(item.category)

        Group {
            if let avatar {
                NavigationLink {
                    ShopItemDetailView(item: item, avatar: avatar)
                } label: {
                    campaignChipLabel(item, accent: accent, tint: tint)
                }
            } else {
                campaignChipLabel(item, accent: accent, tint: tint)
            }
        }
        .buttonStyle(.plain)
    }

    private func campaignChipLabel(_ item: ShopItem, accent: Color, tint: Color) -> some View {
        HStack(spacing: 12) {
            apparelSwatch(item, width: 52, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(RallyUIKit.Typography.body(.caption, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                    .lineLimit(1)
                Text(item.priceUSD == 0 ? "Included" : item.priceDisplay)
                    .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                    .foregroundStyle(accent)
            }
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint.opacity(0.7))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func brandSpotlightPanel(
        vendorID: String,
        issue: String,
        headline: String,
        story: String,
        tint: Color
    ) -> some View {
        let items = filtered(ShopCatalog.allItems.filter { $0.vendorID == vendorID })
        let heroItem = items.first

        return RallyUIKit.LuxePanel(tint: tint) {
            HStack(alignment: .center, spacing: RallyUIKit.Spacing.md) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(issue)
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(tint.opacity(0.88))
                    Text(headline)
                        .font(RallyUIKit.Typography.display(24, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text(story)
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.78))
                        .lineLimit(2)
                    Text("\(items.count) pieces on floor")
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .foregroundStyle(tint)
                }

                Spacer(minLength: 8)

                if let heroItem {
                    Group {
                        if let avatar {
                            NavigationLink {
                                ShopItemDetailView(item: heroItem, avatar: avatar)
                            } label: {
                                apparelSwatch(heroItem, width: 78, height: 92)
                            }
                        } else {
                            apparelSwatch(heroItem, width: 78, height: 92)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionTitle(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RallyUIKit.EditorialEyebrow(text: eyebrow, tint: RallyUIKit.Palette.champagne)
            Text(title)
                .font(RallyUIKit.Typography.display(26, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Text(subtitle)
                .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
        }
    }

    private func editorialMoodBoard(edit: ShopEditorialEdit, items: [ShopItem], tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            RallyUIKit.Palette.obsidian,
                            Color.white.opacity(0.03),
                            tint.opacity(0.12),
                            RallyUIKit.Palette.champagne.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 160, height: 160)
                .blur(radius: 28)
                .offset(x: 94, y: -26)

            HStack(alignment: .bottom, spacing: 14) {
                if let top = items.first(where: { $0.category == .top }) {
                    tappableSwatch(top, width: 88, height: 102)
                        .offset(y: -10)
                }
                if let bottom = items.first(where: { $0.category == .bottom }) {
                    tappableSwatch(bottom, width: 84, height: 78)
                }
                if let shoes = items.first(where: { $0.category == .shoes }) {
                    tappableSwatch(shoes, width: 92, height: 68)
                        .offset(y: 6)
                }
                if let racket = items.first(where: { $0.category == .racket }) {
                    tappableSwatch(racket, width: 228, height: 120)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func tappableSwatch(_ item: ShopItem, width: CGFloat, height: CGFloat) -> some View {
        if let avatar {
            NavigationLink {
                ShopItemDetailView(item: item, avatar: avatar)
            } label: {
                apparelSwatch(item, width: width, height: height)
            }
            .buttonStyle(.plain)
        } else {
            apparelSwatch(item, width: width, height: height)
        }
    }

    private func apparelSwatch(_ item: ShopItem, width: CGFloat, height: CGFloat) -> some View {
        let accent = item.accentColor ?? categoryTint(item.category)
        // S-3 audit gate: product imagery first. `ShopItem` IDs and the
        // referral feed are not always 1:1 yet, so fall back by slot/brand
        // before using the custom drawn tennis-gear silhouette.
        let referralItem = RallyMerchImageResolver.referralItem(for: item)
        let productImageURL = referralItem?.productImageURL
        let productAccent = referralItem.flatMap { Color(hex: $0.accentColorHex) } ?? accent
        return ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            item.color.opacity(0.96),
                            productAccent.opacity(0.5),
                            RallyUIKit.Palette.obsidian.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)

            if let productImageURL {
                AsyncImage(url: productImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(min(width, height) * 0.10)
                    default:
                        swatchCategoryIcon(item, accent: productAccent, width: width, height: height)
                    }
                }
            } else {
                swatchCategoryIcon(item, accent: productAccent, width: width, height: height)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: productAccent.opacity(0.14), radius: 16, x: 0, y: 10)
    }

    /// Custom tennis-gear silhouette used as the swatch's loading/failure
    /// state. No terminal SF Symbol fallbacks on product cards.
    private func swatchCategoryIcon(_ item: ShopItem, accent: Color, width: CGFloat, height: CGFloat) -> some View {
        RallyMerchFallbackGlyph(
            category: item.category,
            primary: RallyUIKit.Palette.frost,
            accent: accent
        )
        .padding(min(width, height) * 0.20)
        .shadow(color: Color.black.opacity(0.25), radius: 8, y: 5)
    }

    private func shopTileGradient(accent: Color, itemColor: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                itemColor.opacity(0.28),
                RallyUIKit.Palette.obsidian,
                Color(red: 0.06, green: 0.07, blue: 0.10),
                accent.opacity(0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func vendorDot(for item: ShopItem) -> some View {
        Circle()
            .fill(vendorTint(item.vendorID))
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1))
            .shadow(color: vendorTint(item.vendorID).opacity(0.35), radius: 4, y: 2)
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
        case "wilson.supertour.red":
            return "TOUR SIGNAL"
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

    private func travelFact(_ label: String, tint: Color) -> some View {
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

    private func travelMiniChip(_ label: String, tint: Color) -> some View {
        Text(label)
            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
            .foregroundStyle(RallyUIKit.Palette.frost.opacity(0.86))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(
                Capsule().stroke(tint.opacity(0.18), lineWidth: 1)
            )
    }
}

private struct FloatingKitHeroCard: View {
    var body: some View {
        ZStack {
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

            Circle()
                .fill(RallyUIKit.Palette.champagne.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 26)
                .offset(x: -92, y: -82)

            Circle()
                .fill(RallyUIKit.Palette.cyan.opacity(0.14))
                .frame(width: 180, height: 180)
                .blur(radius: 24)
                .offset(x: 118, y: -38)

            FloatingKitStageOverlay(accent: RallyUIKit.Palette.champagne)
                .clipShape(RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl))

            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let floatY = sin(t * 1.35) * 8
                let sway = sin(t * 0.82) * 3.4
                let shimmer = 0.12 + ((sin(t * 1.08) + 1) * 0.06)

                FloatingKitFigure()
                    .padding(.top, 16)
                    .offset(x: sway, y: floatY - 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.white.opacity(shimmer), lineWidth: 1)
                            .blur(radius: 2)
                            .padding(.horizontal, 34)
                            .padding(.vertical, 18)
                    }
            }

            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CAMPAIGN FLOOR")
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                            .tracking(2.4)
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                        Text("Luxury sports retail")
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                    }
                    Spacer()
                }
                .padding(.horizontal, RallyUIKit.Spacing.md)
                .padding(.vertical, RallyUIKit.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                        .fill(Color.black.opacity(0.22))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                        .stroke(RallyUIKit.Palette.line.opacity(0.75), lineWidth: 1)
                )
                .padding(RallyUIKit.Spacing.md)
            }
        }
        .frame(height: 340)
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl)
                .stroke(RallyUIKit.Palette.gold.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct FloatingKitFigure: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.26))
                .frame(width: 170, height: 30)
                .blur(radius: 14)
                .offset(y: 86)

            VStack(spacing: 10) {
                FloatingKitTop()
                FloatingKitSkirt()
            }
            .shadow(color: Color.white.opacity(0.16), radius: 18, y: 6)
        }
    }
}

enum RallyMerchImageResolver {
    static func referralItem(for item: ShopItem) -> RallyGearItem? {
        if let exact = RallyReferralCatalog.referralItem(matchingShopItemID: item.id) {
            return exact
        }

        guard let slot = referralSlot(for: item.category) else { return nil }
        let candidates = RallyReferralCatalog.items(in: slot)
        guard !candidates.isEmpty else { return nil }

        let itemBrand = normalized(item.brand)
        if let brandMatch = candidates.first(where: { normalized($0.brand) == itemBrand }) {
            return brandMatch
        }

        let nameTokens = tokenSet(item.name)
        if let nameMatch = candidates.first(where: { !tokenSet($0.name).isDisjoint(with: nameTokens) }) {
            return nameMatch
        }

        return candidates.first
    }

    static func referralSlot(for category: ShopItem.Category) -> ReferralGearSlot? {
        switch category {
        case .top: return .top
        case .bottom: return .shorts
        case .shoes: return .shoes
        case .racket: return .racket
        case .accessory: return .headband
        case .bag: return nil
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func tokenSet(_ value: String) -> Set<String> {
        let separators = CharacterSet.alphanumerics.inverted
        return Set(
            value
                .lowercased()
                .components(separatedBy: separators)
                .filter { $0.count >= 4 }
        )
    }
}

struct RallyMerchFallbackGlyph: View {
    let category: ShopItem.Category
    let primary: Color
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                switch category {
                case .top:
                    RallyTopGlyphShape()
                        .fill(glyphGradient(size: size))
                    RallyTopCollarShape()
                        .stroke(accent.opacity(0.92), lineWidth: max(1.2, size.width * 0.035))
                    RallyTopHemShape()
                        .stroke(Color.black.opacity(0.22), lineWidth: max(1, size.width * 0.025))

                case .bottom:
                    RallyShortsGlyphShape()
                        .fill(glyphGradient(size: size))
                    RallyShortsWaistShape()
                        .fill(Color.black.opacity(0.26))
                    RallyShortsHemShape()
                        .stroke(primary.opacity(0.64), lineWidth: max(1.1, size.width * 0.022))
                    RallyShortsSideStripeShape()
                        .stroke(accent.opacity(0.92), lineWidth: max(1.2, size.width * 0.026))
                    RallyShortsCreaseShape()
                        .stroke(Color.white.opacity(0.30), lineWidth: max(1, size.width * 0.018))

                case .shoes:
                    RallyTennisShoePairGlyph(primary: primary, accent: accent)

                case .racket:
                    RallyRacketFallbackGlyph(primary: primary, accent: accent)

                case .bag:
                    RallyBagGlyphShape()
                        .fill(glyphGradient(size: size))
                    RallyBagHandleShape()
                        .stroke(primary.opacity(0.75), lineWidth: max(1.4, size.width * 0.040))

                case .accessory:
                    RallyHeadbandGlyphShape()
                        .fill(glyphGradient(size: size))
                    RallyHeadbandStripeShape()
                        .stroke(primary.opacity(0.82), lineWidth: max(1.2, size.width * 0.030))
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func glyphGradient(size: CGSize) -> LinearGradient {
        LinearGradient(
            colors: [
                primary.opacity(0.98),
                primary.opacity(0.78),
                accent.opacity(0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct RallyRacketFallbackGlyph: View {
    let primary: Color
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Ellipse()
                    .stroke(primary.opacity(0.95), lineWidth: max(2, w * 0.08))
                    .frame(width: w * 0.48, height: h * 0.62)
                    .offset(x: w * 0.08, y: -h * 0.13)
                Ellipse()
                    .stroke(accent.opacity(0.38), lineWidth: max(1, w * 0.025))
                    .frame(width: w * 0.35, height: h * 0.47)
                    .offset(x: w * 0.08, y: -h * 0.13)

                Capsule()
                    .fill(primary.opacity(0.94))
                    .frame(width: w * 0.12, height: h * 0.48)
                    .rotationEffect(.degrees(33))
                    .offset(x: -w * 0.15, y: h * 0.21)
                Capsule()
                    .fill(accent.opacity(0.72))
                    .frame(width: w * 0.07, height: h * 0.22)
                    .rotationEffect(.degrees(33))
                    .offset(x: -w * 0.27, y: h * 0.35)
            }
        }
    }
}

private struct RallyTopGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.30, y: rect.minY + h * 0.18))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.43, y: rect.minY + h * 0.11))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.57, y: rect.minY + h * 0.11), control: CGPoint(x: rect.midX, y: rect.minY + h * 0.22))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.70, y: rect.minY + h * 0.18))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.91, y: rect.minY + h * 0.36))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.77, y: rect.minY + h * 0.55))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.69, y: rect.minY + h * 0.44))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.68, y: rect.minY + h * 0.88))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.32, y: rect.minY + h * 0.88))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.31, y: rect.minY + h * 0.44))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.23, y: rect.minY + h * 0.55))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.09, y: rect.minY + h * 0.36))
        p.closeSubpath()
        return p
    }
}

private struct RallyTopCollarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.42, y: rect.minY + h * 0.15))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.31))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.58, y: rect.minY + h * 0.15))
        return p
    }
}

private struct RallyTopHemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.80))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.minY + rect.height * 0.80))
        return p
    }
}

private struct RallyShortsGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.17, y: rect.minY + h * 0.20))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.83, y: rect.minY + h * 0.20), control: CGPoint(x: rect.midX, y: rect.minY + h * 0.12))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.80, y: rect.minY + h * 0.72))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.60, y: rect.minY + h * 0.86), control: CGPoint(x: rect.minX + w * 0.72, y: rect.minY + h * 0.90))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.53, y: rect.minY + h * 0.55))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.47, y: rect.minY + h * 0.55), control: CGPoint(x: rect.midX, y: rect.minY + h * 0.49))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.40, y: rect.minY + h * 0.86))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.72), control: CGPoint(x: rect.minX + w * 0.28, y: rect.minY + h * 0.90))
        p.closeSubpath()
        return p
    }
}

private struct RallyShortsWaistShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: CGRect(
            x: rect.minX + rect.width * 0.20,
            y: rect.minY + rect.height * 0.14,
            width: rect.width * 0.60,
            height: rect.height * 0.13
        ), cornerRadius: rect.height * 0.06)
    }
}

private struct RallyShortsCreaseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.30))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.78))
        return p
    }
}

private struct RallyShortsHemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.24, y: rect.minY + h * 0.70))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.42, y: rect.minY + h * 0.80), control: CGPoint(x: rect.minX + w * 0.32, y: rect.minY + h * 0.77))
        p.move(to: CGPoint(x: rect.minX + w * 0.58, y: rect.minY + h * 0.80))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.76, y: rect.minY + h * 0.70), control: CGPoint(x: rect.minX + w * 0.68, y: rect.minY + h * 0.77))
        return p
    }
}

private struct RallyShortsSideStripeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.27, y: rect.minY + h * 0.31))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.22, y: rect.minY + h * 0.66))
        p.move(to: CGPoint(x: rect.minX + w * 0.73, y: rect.minY + h * 0.31))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.78, y: rect.minY + h * 0.66))
        return p
    }
}

private struct RallyTennisShoePairGlyph: View {
    let primary: Color
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                RallySingleTennisShoe(primary: primary, accent: accent)
                    .frame(width: w * 0.58, height: h * 0.52)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -w * 0.16, y: h * 0.08)

                RallySingleTennisShoe(primary: primary, accent: accent)
                    .frame(width: w * 0.58, height: h * 0.52)
                    .rotationEffect(.degrees(10))
                    .scaleEffect(x: -1, y: 1)
                    .offset(x: w * 0.16, y: -h * 0.06)
            }
        }
    }
}

private struct RallySingleTennisShoe: View {
    let primary: Color
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RallyTennisShoeGlyphShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                primary.opacity(0.98),
                                primary.opacity(0.78),
                                accent.opacity(0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RallyShoeSoleShape()
                    .fill(Color.white.opacity(0.94))
                RallyShoeLaceShape()
                    .stroke(accent.opacity(0.96), lineWidth: max(1.2, size.width * 0.036))
                RallyShoeToeCapShape()
                    .stroke(Color.white.opacity(0.66), lineWidth: max(1, size.width * 0.026))
                RallyShoeSpeedStripeShape()
                    .stroke(Color.black.opacity(0.24), lineWidth: max(1, size.width * 0.026))
            }
        }
    }
}

private struct RallyTennisShoeGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.58))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.36, y: rect.minY + h * 0.34), control: CGPoint(x: rect.minX + w * 0.18, y: rect.minY + h * 0.36))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.66, y: rect.minY + h * 0.38), control: CGPoint(x: rect.minX + w * 0.50, y: rect.minY + h * 0.25))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.95, y: rect.minY + h * 0.62), control: CGPoint(x: rect.minX + w * 0.88, y: rect.minY + h * 0.40))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.91, y: rect.minY + h * 0.78), control: CGPoint(x: rect.minX + w * 1.00, y: rect.minY + h * 0.74))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.13, y: rect.minY + h * 0.80))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.58), control: CGPoint(x: rect.minX + w * 0.00, y: rect.minY + h * 0.70))
        return p
    }
}

private struct RallyShoeSoleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: CGRect(
            x: rect.minX + rect.width * 0.12,
            y: rect.minY + rect.height * 0.72,
            width: rect.width * 0.82,
            height: rect.height * 0.12
        ), cornerRadius: rect.height * 0.06)
    }
}

private struct RallyShoeLaceShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        for i in 0..<3 {
            let x = rect.minX + w * (0.43 + CGFloat(i) * 0.09)
            p.move(to: CGPoint(x: x, y: rect.minY + h * 0.48))
            p.addLine(to: CGPoint(x: x + w * 0.08, y: rect.minY + h * 0.59))
        }
        return p
    }
}

private struct RallyShoeToeCapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.73, y: rect.minY + h * 0.49))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.90, y: rect.minY + h * 0.65), control: CGPoint(x: rect.minX + w * 0.91, y: rect.minY + h * 0.49))
        return p
    }
}

private struct RallyShoeSpeedStripeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.27, y: rect.minY + h * 0.62))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.49, y: rect.minY + h * 0.52))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.70, y: rect.minY + h * 0.62))
        return p
    }
}

private struct RallyBagGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: CGRect(
            x: rect.minX + rect.width * 0.18,
            y: rect.minY + rect.height * 0.30,
            width: rect.width * 0.64,
            height: rect.height * 0.52
        ), cornerRadius: rect.width * 0.12)
    }
}

private struct RallyBagHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.35))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + rect.height * 0.35),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12)
        )
        return p
    }
}

private struct RallyHeadbandGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: CGRect(
            x: rect.minX + rect.width * 0.13,
            y: rect.minY + rect.height * 0.42,
            width: rect.width * 0.74,
            height: rect.height * 0.20
        ), cornerRadius: rect.height * 0.10)
    }
}

private struct RallyHeadbandStripeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.midY))
        return p
    }
}

private struct FloatingKitStageOverlay: View {
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.clear,
                    accent.opacity(0.08),
                    RallyUIKit.Palette.cyan.opacity(0.06)
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
                                accent.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 104)
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
        }
    }
}

private struct FloatingKitTop: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 26)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.98),
                        RallyUIKit.Palette.champagne.opacity(0.84),
                        Color(red: 0.85, green: 0.87, blue: 0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 118, height: 118)
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.66))
                    .frame(width: 58, height: 16)
                    .offset(y: -8)
            }
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(Color(red: 0.62, green: 0.68, blue: 0.74).opacity(0.85))
                    .frame(width: 76, height: 10)
                    .offset(y: 10)
            }
    }
}

private struct FloatingKitSkirt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            Color(red: 0.93, green: 0.94, blue: 0.96),
                            RallyUIKit.Palette.champagne.opacity(0.72)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 136, height: 82)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                )

            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 18, height: 54)
                }
            }
            .offset(y: 6)
        }
    }
}
