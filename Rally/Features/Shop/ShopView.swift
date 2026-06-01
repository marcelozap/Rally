import SwiftUI
import SwiftData

struct ShopView: View {
    @Query private var avatarConfigs: [AvatarConfig]
    @State private var selectedCategory: ShopItem.Category? = nil
    @State private var groupByVendor: Bool = false
    @State private var shopEmote: AvatarShopEmote = .shopLook
    @ObservedObject private var unlocks = CourtUnlocks.shared

    private var avatar: AvatarConfig? { avatarConfigs.first }

    private var equippedIDs: Set<String> {
        guard let a = avatar else { return [] }
        return Set([a.equippedTopID, a.equippedBottomID, a.equippedShoesID, a.equippedRacketID])
    }

    private var visibleItems: [ShopItem] {
        ShopCatalog.visibleItems(
            ShopCatalog.allItems,
            unlockedCourtIDs: unlocks.unlockedCourtIDs,
            equippedIDs: equippedIDs
        )
    }

    private var editorialEdits: [ShopEditorialEdit] {
        ShopCatalog.editorialEdits.filter { !filtered(ShopCatalog.editorialItems(for: $0)).isEmpty }
    }

    private var equippedCount: Int {
        guard let avatar else { return 0 }
        return [avatar.equippedTopID, avatar.equippedBottomID, avatar.equippedShoesID, avatar.equippedRacketID].count
    }

    private var featuredTravelDestinations: [IconicTennisCourt] {
        let ids = ["wimbledon.cc", "indianwells", "rna.mallorca"]
        let lookup = Dictionary(uniqueKeysWithValues: IconicCourtsCatalog.allCourts.map { ($0.id, $0) })
        return ids.compactMap { lookup[$0] }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: RallyUIKit.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                    shopOverview

                    if let avatar = avatar {
                        AvatarShopStageView(config: avatar, preview: nil, emote: $shopEmote)
                            .padding(.horizontal, RallyUIKit.Spacing.md)
                    }

                    featuredFashionSection
                    worldTravelSection
                    categoryFilter

                    if groupByVendor {
                        ForEach(ShopCatalog.itemsGroupedByVendor(), id: \.0.id) { vendor, items in
                            let visible = filtered(items)
                            if !visible.isEmpty {
                                Section {
                                    ForEach(visible) { item in
                                        shopRow(item)
                                    }
                                } header: {
                                    vendorHeader(vendor, count: visible.count)
                                }
                            }
                        }
                    } else {
                        ForEach(ShopItem.Category.allCases) { category in
                            let items = filtered(ShopCatalog.items(in: category))
                            if !items.isEmpty {
                                Section {
                                    ForEach(items) { item in
                                        shopRow(item)
                                    }
                                } header: {
                                    categoryHeader(category, count: items.count)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, RallyUIKit.Spacing.md)
                .padding(.bottom, 32)
            }
            .background(RallyUIKit.screenBackground)
            .navigationTitle("Shop")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        groupByVendor.toggle()
                    } label: {
                        RallyUIKit.IconBadge(
                            systemName: groupByVendor ? "person.2.fill" : "square.grid.2x2.fill",
                            tint: groupByVendor ? RallyUIKit.Palette.rose : RallyUIKit.Palette.cyan,
                            size: 34
                        )
                    }
                }
            }
        }
    }

    private var shopOverview: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.gold) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
                RallyUIKit.EditorialEyebrow(text: "Pro Shop", tint: RallyUIKit.Palette.gold)

                FloatingKitHeroCard()

                HStack(alignment: .center, spacing: RallyUIKit.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dress the sibling star first")
                            .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Lead with New Balance whites, Nike contrast, and Wilson hero frames.")
                            .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.84))
                    }

                    Spacer(minLength: RallyUIKit.Spacing.sm)

                    RallyUIKit.IconBadge(
                        systemName: "sparkles",
                        tint: RallyUIKit.Palette.gold,
                        size: 40
                    )
                }

                HStack(spacing: RallyUIKit.Spacing.xs) {
                    heroChip("New Balance", tint: RallyUIKit.Palette.champagne)
                    heroChip("Nike", tint: RallyUIKit.Palette.cyan)
                    heroChip("Wilson", tint: RallyUIKit.Palette.gold)
                }

                HStack(spacing: RallyUIKit.Spacing.sm) {
                    overviewStat(value: "\(visibleItems.count)", label: "Visible now", tint: RallyUIKit.Palette.cyan)
                    overviewStat(value: "\(ShopCatalog.vendors.count)", label: "Brands", tint: RallyUIKit.Palette.rose)
                    overviewStat(value: "\(equippedCount)", label: "Equipped", tint: RallyUIKit.Palette.gold)
                }
            }
        }
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
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.line) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
                HStack(alignment: .center, spacing: RallyUIKit.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Edit the floor")
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text(groupByVendor ? "Grouped by brand partner" : "Grouped by wardrobe layer")
                            .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.82))
                    }

                    Spacer()

                    Button {
                        groupByVendor.toggle()
                    } label: {
                        HStack(spacing: RallyUIKit.Spacing.xs) {
                            Image(systemName: groupByVendor ? "person.2.fill" : "square.grid.2x2.fill")
                            Text(groupByVendor ? "Brands" : "Categories")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(tint: groupByVendor ? RallyUIKit.Palette.rose : RallyUIKit.Palette.cyan))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RallyUIKit.Spacing.xs) {
                        filterChip(label: "All gear", selected: selectedCategory == nil, tint: RallyUIKit.Palette.champagne) {
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
            }
        }
    }

    private var featuredFashionSection: some View {
        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
            HStack(spacing: RallyUIKit.Spacing.sm) {
                RallyUIKit.IconBadge(systemName: "sparkles", tint: RallyUIKit.Palette.champagne, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spotlight edits")
                        .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text("Three fast directions instead of one long catalog.")
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RallyUIKit.Spacing.md) {
                    ForEach(editorialEdits) { edit in
                        featuredEditCard(edit: edit, items: filtered(ShopCatalog.editorialItems(for: edit)))
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var worldTravelSection: some View {
        NavigationLink {
            CourtsMapView()
        } label: {
            RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.lime) {
                VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
                    HStack(alignment: .top, spacing: RallyUIKit.Spacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            RallyUIKit.EditorialEyebrow(text: "Courts & camps", tint: RallyUIKit.Palette.lime)
                            Text("Book the tennis world next")
                                .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text("After the fashion floor, move straight into iconic venues and global training camps with official booking and enrollment links.")
                                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.82))
                        }

                        Spacer(minLength: 8)

                        RallyUIKit.IconBadge(
                            systemName: "globe.europe.africa.fill",
                            tint: RallyUIKit.Palette.lime,
                            size: 38
                        )
                    }

                    HStack(spacing: RallyUIKit.Spacing.sm) {
                        travelFact("Venues", tint: RallyUIKit.Palette.cyan)
                        travelFact("Camps", tint: RallyUIKit.Palette.gold)
                        travelFact("Official links", tint: RallyUIKit.Palette.rose)
                    }

                    if !featuredTravelDestinations.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(featuredTravelDestinations) { court in
                                    travelPreviewCard(court)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .scrollClipDisabled()
                    }

                    HStack(spacing: 8) {
                        Text("Open atlas")
                            .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(RallyUIKit.Palette.lime)
                }
            }
        }
        .buttonStyle(.plain)
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

    private func categoryHeader(_ category: ShopItem.Category, count: Int) -> some View {
        HStack(spacing: RallyUIKit.Spacing.sm) {
            RallyUIKit.IconBadge(systemName: category.iconSystemName, tint: categoryTint(category), size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text("\(count) style-led picks")
                    .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.74))
            }
            Spacer()
        }
        .padding(.vertical, RallyUIKit.Spacing.xs)
        .background(RallyUIKit.Palette.ink)
    }

    private func vendorHeader(_ vendor: Vendor, count: Int) -> some View {
        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vendor.displayName)
                        .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text(vendorSubhead(vendor, count: count))
                        .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                }
                Spacer()
                Link(destination: vendor.websiteURL) {
                    HStack(spacing: 4) {
                        Text("Store")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.cyan)
                }
            }
            if let loyalty = vendor.loyaltyProgramURL {
                Link(destination: loyalty) {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.circle.fill")
                            .foregroundStyle(RallyUIKit.Palette.gold)
                        Text("Official member / referral hub")
                            .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.champagne)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.5))
                    }
                }
            }
        }
        .padding(.vertical, RallyUIKit.Spacing.xs)
        .background(RallyUIKit.Palette.ink)
    }

    private func shopRow(_ item: ShopItem) -> some View {
        Group {
            if let avatar {
                NavigationLink {
                    ShopItemDetailView(item: item, avatar: avatar)
                } label: {
                    rowContent(item)
                }
            } else {
                rowContent(item)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func rowContent(_ item: ShopItem) -> some View {
        let accent = item.accentColor ?? categoryTint(item.category)

        HStack(spacing: RallyUIKit.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                item.color.opacity(0.95),
                                accent.opacity(0.76),
                                RallyUIKit.Palette.obsidian.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 82)

                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    .frame(width: 76, height: 82)

                Image(systemName: item.category.iconSystemName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 6, y: 3)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.brand.uppercased())
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                    Spacer(minLength: 8)
                    Text(item.priceUSD == 0 ? "Included" : item.priceDisplay)
                        .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                        .foregroundStyle(accent)
                }

                Text(item.name)
                    .font(RallyUIKit.Typography.body(.body, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                    .lineLimit(2)

                Text(rowMeta(item))
                    .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.78))
                    .lineLimit(2)

                Text(editorialLine(for: item))
                    .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(accent.opacity(0.95))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: RallyUIKit.Spacing.xs) {
                if isEquipped(item) {
                    Text("EQUIPPED")
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(Capsule().fill(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan)))
                        .foregroundStyle(RallyUIKit.Palette.obsidian)
                }

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.45))
            }
        }
        .padding(RallyUIKit.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 10)
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
            HStack(spacing: RallyUIKit.Spacing.xs) {
                Circle()
                    .fill(selected ? RallyUIKit.Palette.obsidian : tint)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .semibold))
                    .tracking(0.2)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(selected ? AnyShapeStyle(RallyUIKit.accentGradient(tint)) : AnyShapeStyle(Color.white.opacity(0.08)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selected ? Color.white.opacity(0.16) : tint.opacity(0.18), lineWidth: 1)
            )
            .foregroundStyle(selected ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.frost)
        }
        .buttonStyle(.plain)
    }

    private func rowMeta(_ item: ShopItem) -> String {
        if let racketProfile = ShopCatalog.racketProfile(id: item.id) {
            return "\(racketProfile.performanceFocus) • \(racketProfile.headSizeSqIn) sq in • \(racketProfile.weightGrams) g"
        }

        switch item.vendorID {
        case "newbalance":
            return "Clean tournament layer"
        case "nike":
            return "Match-ready contrast"
        case "wilson":
            return "Hero frame for big points"
        default:
            if let vendor = ShopCatalog.vendor(id: item.vendorID)?.displayName {
                return "\(item.category.displayName) • \(vendor)"
            }
            return item.category.displayName
        }
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

    private func featuredEditCard(edit: ShopEditorialEdit, items: [ShopItem]) -> some View {
        let tint = edit.tintColor

        return RallyUIKit.SectionCard(stroke: tint.opacity(0.26)) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
                editorialMoodBoard(edit: edit, items: items, tint: tint)

                VStack(alignment: .leading, spacing: 6) {
                    Text(edit.eyebrow.uppercased())
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(tint.opacity(0.92))
                    Text(edit.title)
                        .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text(edit.subtitle)
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.86))
                    Text(edit.body)
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    ForEach(items.prefix(edit.vendorID == "wilson" ? 1 : 3)) { item in
                        shopRow(item)
                    }
                }
            }
        }
        .frame(width: 328)
    }

    private func editorialMoodBoard(edit: ShopEditorialEdit, items: [ShopItem], tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            RallyUIKit.Palette.obsidian,
                            Color.white.opacity(0.03),
                            tint.opacity(0.12)
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

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    detailPill(edit.vendorID == "wilson" ? "Racket first" : "Outfit edit", tint: tint)
                    Spacer()
                    Text(edit.vendorID == "wilson" ? "01" : "03")
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.58))
                }

                HStack(alignment: .bottom, spacing: 14) {
                    if let top = items.first(where: { $0.category == .top }) {
                        apparelSwatch(top, width: 88, height: 102)
                            .offset(y: -10)
                    }
                    if let bottom = items.first(where: { $0.category == .bottom }) {
                        apparelSwatch(bottom, width: 84, height: 78)
                    }
                    if let shoes = items.first(where: { $0.category == .shoes }) {
                        apparelSwatch(shoes, width: 92, height: 68)
                            .offset(y: 6)
                    }
                    if let racket = items.first(where: { $0.category == .racket }) {
                        apparelSwatch(racket, width: 228, height: 120)
                    }
                }
            }
            .padding(18)
        }
        .frame(height: 188)
        .clipShape(RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func apparelSwatch(_ item: ShopItem, width: CGFloat, height: CGFloat) -> some View {
        let accent = item.accentColor ?? categoryTint(item.category)
        return ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            item.color.opacity(0.96),
                            accent.opacity(0.5),
                            RallyUIKit.Palette.obsidian.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)

            Image(systemName: item.category.iconSystemName)
                .font(.system(size: min(width, height) * 0.28, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.25), radius: 8, y: 5)
        }
        .frame(width: width, height: height)
        .shadow(color: accent.opacity(0.14), radius: 16, x: 0, y: 10)
    }

    private func heroChip(_ label: String, tint: Color) -> some View {
        Text(label)
            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
            .foregroundStyle(RallyUIKit.Palette.frost)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 1))
    }

    private func detailPill(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
            .tracking(1.4)
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
                        Text("EDITORIAL FLOOR")
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                        Text("Sibling-ready shop edit")
                            .font(RallyUIKit.Typography.body(.subheadline, weight: .semibold))
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
        .frame(height: 310)
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
