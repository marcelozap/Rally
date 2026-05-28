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

    private var equippedCount: Int {
        guard let avatar else { return 0 }
        return [avatar.equippedTopID, avatar.equippedBottomID, avatar.equippedShoesID, avatar.equippedRacketID].count
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
                        Text("Studio kit drop")
                            .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Clean whites first. Then racquets, shoes, and branded pieces.")
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
        guard let cat = selectedCategory else { return visible }
        return visible.filter { $0.category == cat }
    }

    private var categoryFilter: some View {
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.line) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
                HStack(alignment: .center, spacing: RallyUIKit.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Filter the floor")
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text(groupByVendor ? "Grouped by brand partner" : "Grouped by gear category")
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

    private func categoryHeader(_ category: ShopItem.Category, count: Int) -> some View {
        HStack(spacing: RallyUIKit.Spacing.sm) {
            RallyUIKit.IconBadge(systemName: category.iconSystemName, tint: categoryTint(category), size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text("\(count) curated pieces")
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
                    Text("\(count) pieces live now")
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
        if let vendor = ShopCatalog.vendor(id: item.vendorID)?.displayName {
            return "\(item.category.displayName) • \(vendor)"
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

            FloatingKitFigure()
                .padding(.top, 16)
                .offset(y: -4)

            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rally Whites")
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                        Text("Floating edit")
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
        }
    }
}

private struct FloatingKitTop: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(red: 0.95, green: 0.96, blue: 0.98),
                            Color(red: 0.88, green: 0.90, blue: 0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 124, height: 112)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.96))
                    .frame(width: 28, height: 76)
                    .rotationEffect(.degrees(22))
                    .offset(x: 3, y: -6)

                Spacer()

                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.96))
                    .frame(width: 28, height: 76)
                    .rotationEffect(.degrees(-22))
                    .offset(x: -3, y: -6)
            }
            .frame(width: 170)

            VStack(spacing: 0) {
                Capsule()
                    .fill(RallyUIKit.Palette.ink.opacity(0.94))
                    .frame(width: 42, height: 18)
                    .offset(y: -14)

                Spacer()
            }
            .frame(height: 112)

            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.78), lineWidth: 1.3)
                .frame(width: 124, height: 112)

            Capsule()
                .fill(RallyUIKit.Palette.champagne.opacity(0.78))
                .frame(width: 54, height: 3)
                .offset(y: 18)
        }
    }
}

private struct FloatingKitSkirt: View {
    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.92, green: 0.94, blue: 0.97)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 24, height: 88)
                    .rotationEffect(.degrees(Double(index - 3) * 5.6))
                    .offset(x: CGFloat(index - 2) * 16, y: 6)
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(RallyUIKit.Palette.ink.opacity(0.96))
                .frame(width: 104, height: 16)
                .offset(y: -34)

            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.82), lineWidth: 1.2)
                .frame(width: 132, height: 98)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 28,
                        bottomTrailingRadius: 28,
                        topTrailingRadius: 16
                    )
                )
                .opacity(0.18)
        }
        .frame(width: 152, height: 104)
    }
}
