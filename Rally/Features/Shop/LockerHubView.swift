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
                            AvatarShopStageView(config: avatar, preview: nil, emote: $shopEmote)
                                .padding(.horizontal, 16)
                                .padding(.top, 4)

                            playerStrip
                                .padding(.horizontal, 16)
                        }

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
        return raw.isEmpty ? "Locker" : raw
    }

    // MARK: - Play CTA

    private var playNowButton: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 44, height: 44)
                    Image(systemName: "tennis.racket")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Play Now")
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                    Text("Rhythm rally · pick court in-game")
                        .font(.caption.weight(.medium))
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan,
                                Color(red: 0.2, green: 0.85, blue: 0.95),
                                Color(red: 0.55, green: 0.95, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.cyan.opacity(0.45), radius: 18, y: 8)
        }
        .buttonStyle(PlayNowButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Player strip

    @ViewBuilder
    private var playerStrip: some View {
        if let p = progress {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.9), Color(red: 0, green: 0.45, blue: 0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)
                    Text("\(p.level)")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Level \(p.level)")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(LinearGradient(colors: [.cyan, .pink], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(max(0.02, p.levelProgress)))
                        }
                    }
                    .frame(height: 4)
                }
                Spacer()
                statPill("\(p.coins)", icon: "circle.hexagongrid.fill", tint: .yellow)
                statPill("\(p.bestScore)", icon: "star.fill", tint: .cyan)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func statPill(_ value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(tint)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }

    private var guestOfflineBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.title3)
                .foregroundStyle(.orange.opacity(0.95))
            Text("Offline — data stays on this device. Account → Leave offline mode to sync.")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.35), lineWidth: 1))
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
                .foregroundStyle(.cyan)
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
        guard let cat = selectedCategory else { return visible }
        return visible.filter { $0.category == cat }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(label: "All", selected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ShopItem.Category.allCases) { c in
                    Chip(label: c.displayName, selected: selectedCategory == c) {
                        selectedCategory = (selectedCategory == c) ? nil : c
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func categoryHeader(_ category: ShopItem.Category) -> some View {
        HStack {
            Image(systemName: category.iconSystemName)
            Text(category.displayName)
                .font(.system(.title3, design: .rounded).weight(.bold))
            Spacer()
        }
        .padding(.vertical, 6)
        .foregroundStyle(.white)
        .background(Color(red: 0.03, green: 0.04, blue: 0.07))
    }

    private func vendorHeader(_ vendor: Vendor) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vendor.displayName)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Link(destination: vendor.websiteURL) {
                    HStack(spacing: 4) {
                        Text("Store")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.caption)
                    .foregroundStyle(.cyan)
                }
            }
            if let loyalty = vendor.loyaltyProgramURL {
                Link(destination: loyalty) {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.circle.fill")
                            .foregroundStyle(.yellow.opacity(0.9))
                        Text("Official member / referral hub")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow.opacity(0.95))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .background(Color(red: 0.03, green: 0.04, blue: 0.07))
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
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12)
                .fill(item.color)
                .frame(width: 64, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(item.accentColor ?? .clear, lineWidth: 2)
                )
                .overlay(
                    Image(systemName: item.category.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text(item.brand)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Text(item.priceUSD == 0 ? "Included" : item.priceDisplay)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
            }
            Spacer()
            if isEquipped(item) {
                Text("EQUIPPED")
                    .font(.caption2.weight(.bold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(Color.cyan))
                    .foregroundStyle(.black)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
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
