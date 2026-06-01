import SwiftUI
import SwiftData

/// Default landing: avatar stage, gear shop, and a hero **Play Now** CTA.
struct LockerHubView: View {
    @EnvironmentObject private var auth: AuthSession
    @Query private var avatarConfigs: [AvatarConfig]
    @Query private var progressRecords: [PlayerProgress]

    @State private var selectedCategory: ShopItem.Category? = nil
    @State private var groupByVendor: Bool = false
    @State private var shopEmote: AvatarShopEmote = .shopLook
    @ObservedObject private var unlocks = CourtUnlocks.shared

    var onPlay: () -> Void

    private var avatar: AvatarConfig? { avatarConfigs.first }
    private var progress: PlayerProgress? { progressRecords.first }

    private var equippedIDs: Set<String> {
        guard let a = avatar else { return [] }
        return Set([a.equippedTopID, a.equippedBottomID, a.equippedShoesID, a.equippedRacketID])
    }

    private var editorialEdits: [ShopEditorialEdit] {
        ShopCatalog.editorialEdits.filter { !filtered(ShopCatalog.editorialItems(for: $0)).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        if auth.isGuestMode {
                            guestOfflineBanner
                                .padding(.horizontal, 16)
                        }

                        if let avatar = avatar {
                            if usesReferenceAvatarArt(avatar) {
                                referenceAvatarPanel
                                    .padding(.horizontal, 16)
                                    .padding(.top, 4)
                            } else {
                                AvatarShopStageView(config: avatar, preview: nil, emote: $shopEmote)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 4)
                            }

                            playerStrip
                                .padding(.horizontal, 16)
                        }

                        featuredStyleRail
                            .padding(.horizontal, 16)

                        worldAtlasBridge
                            .padding(.horizontal, 16)

                        categoryFilter
                            .padding(.horizontal, 16)

                        if groupByVendor {
                            ForEach(ShopCatalog.itemsGroupedByVendor(), id: \.0.id) { vendor, items in
                                Section {
                                    ForEach(filtered(items)) { item in
                                        shopRow(item)
                                    }
                                } header: {
                                    vendorHeader(vendor)
                                }
                            }
                            .padding(.horizontal, 16)
                        } else {
                            ForEach(ShopItem.Category.allCases) { category in
                                let items = filtered(ShopCatalog.items(in: category))
                                if !items.isEmpty {
                                    Section {
                                        ForEach(items) { item in
                                            shopRow(item)
                                        }
                                    } header: {
                                        categoryHeader(category)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
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

    private var lockerTitle: String {
        let raw = avatar?.playerName.trimmingCharacters(in: .whitespaces) ?? ""
        return raw.isEmpty ? "Marcy" : raw
    }

    private func usesReferenceAvatarArt(_ avatar: AvatarConfig) -> Bool {
        let raw = avatar.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty || raw.caseInsensitiveCompare("Marcy") == .orderedSame
    }

    private var referenceAvatarPanel: some View {
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.cyan.opacity(0.18)) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        RallyUIKit.Palette.ink,
                        RallyUIKit.Palette.slate,
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Image("MarcyAvatarReference")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 4) {
                    RallyUIKit.EditorialEyebrow(text: "Profile look", tint: RallyUIKit.Palette.cyan)
                    Text("Marcy")
                        .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text("Using your reference look while the live avatar model catches up.")
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                }
                .padding(18)
            }
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl))
        }
    }

    // MARK: - Play CTA

    private var playNowButton: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                RallyUIKit.IconBadge(systemName: "tennis.racket", tint: RallyUIKit.Palette.obsidian, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Play now")
                        .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    Text("Wall rally · loadout ready")
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
            }
            .foregroundStyle(RallyUIKit.Palette.obsidian)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                    .fill(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: RallyUIKit.Palette.cyan.opacity(0.36), radius: 18, y: 8)
        }
        .buttonStyle(PlayNowButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous))
    }

    // MARK: - Player strip

    @ViewBuilder
    private var playerStrip: some View {
        if let p = progress {
            RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.cyan.opacity(0.18)) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan))
                            .frame(width: 42, height: 42)
                        Text("\(p.level)")
                            .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.obsidian)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Level \(p.level)")
                            .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [RallyUIKit.Palette.cyan, RallyUIKit.Palette.rose],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(max(0.02, p.levelProgress)))
                            }
                        }
                        .frame(height: 4)
                    }
                    Spacer()
                    statPill("\(p.coins)", icon: "circle.hexagongrid.fill", tint: RallyUIKit.Palette.gold)
                    statPill("\(p.bestScore)", icon: "star.fill", tint: RallyUIKit.Palette.cyan)
                }
            }
        }
    }

    private func statPill(_ value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(tint)
            Text(value)
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 1))
    }

    private var guestOfflineBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.title3)
                .foregroundStyle(RallyUIKit.Palette.gold)
            Text("You're browsing offline for now. Everything stays on this device until you sign in and sync.")
                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).fill(RallyUIKit.Palette.gold.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).stroke(RallyUIKit.Palette.gold.opacity(0.28), lineWidth: 1))
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
            Image(systemName: "person.text.rectangle")
                .font(.body.weight(.semibold))
                .foregroundStyle(RallyUIKit.Palette.cyan)
        }
        .accessibilityLabel("Account")
    }

    private var featuredStyleRail: some View {
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.champagne.opacity(0.18)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    RallyUIKit.IconBadge(systemName: "sparkles", tint: RallyUIKit.Palette.champagne, size: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Style edits")
                            .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Lead with New Balance, Nike, and Wilson instead of a flat catalog.")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(editorialEdits) { edit in
                            lockerStyleCard(edit: edit, items: filtered(ShopCatalog.editorialItems(for: edit)))
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var worldAtlasBridge: some View {
        NavigationLink {
            CourtsMapView()
        } label: {
            RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.lime) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            RallyUIKit.EditorialEyebrow(text: "Travel next", tint: RallyUIKit.Palette.lime)
                            Text("Courts and camps around the world")
                                .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text("After the kit comes the destination: iconic venues, global camps, and official booking or enrollment links only.")
                                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                        }

                        Spacer(minLength: 8)

                        RallyUIKit.IconBadge(
                            systemName: "globe.europe.africa.fill",
                            tint: RallyUIKit.Palette.lime,
                            size: 36
                        )
                    }

                    HStack(spacing: 8) {
                        hubChip("Venues", tint: RallyUIKit.Palette.cyan)
                        hubChip("Camps", tint: RallyUIKit.Palette.gold)
                        hubChip("Official links", tint: RallyUIKit.Palette.rose)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shop rows (from ShopView)

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
                        lockerFilterChip(label: "All gear", selected: selectedCategory == nil, tint: RallyUIKit.Palette.champagne) {
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
            }
        }
    }

    private func categoryHeader(_ category: ShopItem.Category) -> some View {
        HStack(spacing: RallyUIKit.Spacing.sm) {
            RallyUIKit.IconBadge(systemName: category.iconSystemName, tint: categoryTint(category), size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text("\(filtered(ShopCatalog.items(in: category)).count) style-led picks")
                    .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
            }
            Spacer()
        }
        .padding(.vertical, RallyUIKit.Spacing.xs)
        .background(RallyUIKit.Palette.ink)
    }

    private func vendorHeader(_ vendor: Vendor) -> some View {
        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vendor.displayName)
                        .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text(vendorSubhead(vendor, count: filtered(ShopCatalog.itemsGroupedByVendor().first(where: { $0.0.id == vendor.id })?.1 ?? []).count))
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
                    shopRowLabel(item)
                }
                .buttonStyle(.plain)
            } else {
                shopRowLabel(item)
            }
        }
    }

    private func shopRowLabel(_ item: ShopItem) -> some View {
        let accent = item.accentColor ?? categoryTint(item.category)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
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
                    .frame(width: 72, height: 78)

                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    .frame(width: 72, height: 78)

                Image(systemName: item.category.iconSystemName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.22), radius: 6, y: 3)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.brand.uppercased())
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                    Spacer(minLength: 8)
                    Text(item.priceUSD == 0 ? "Included" : item.priceDisplay)
                        .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                        .foregroundStyle(accent)
                }
                Text(item.name)
                    .font(RallyUIKit.Typography.body(.body, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(rowMeta(item))
                    .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.78))
                    .lineLimit(2)
                Text(editorialLine(for: item))
                    .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(accent.opacity(0.95))
                    .lineLimit(1)
            }
            Spacer()
            if isEquipped(item) {
                Text("EQUIPPED")
                    .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan)))
                    .foregroundStyle(RallyUIKit.Palette.obsidian)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.3))
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
    }

    private func lockerFilterChip(label: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: RallyUIKit.Spacing.xs) {
                Circle()
                    .fill(selected ? RallyUIKit.Palette.obsidian : tint)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .semibold))
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

    private func lockerStyleCard(edit: ShopEditorialEdit, items: [ShopItem]) -> some View {
        let tint = edit.tintColor

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(items.prefix(edit.vendorID == "wilson" ? 1 : 3)) { item in
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        item.color.opacity(0.96),
                                        (item.accentColor ?? tint).opacity(0.68),
                                        RallyUIKit.Palette.obsidian.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        Image(systemName: item.category.iconSystemName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(
                        width: edit.vendorID == "wilson" ? 210 : 68,
                        height: edit.vendorID == "wilson" ? 96 : (item.category == .shoes ? 54 : 82)
                    )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(edit.title)
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(edit.subtitle.uppercased())
                    .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(tint)
            }
        }
        .padding(12)
        .frame(width: edit.vendorID == "wilson" ? 266 : 244, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
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
