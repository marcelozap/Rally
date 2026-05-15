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

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    if let avatar = avatar {
                        AvatarShopStageView(config: avatar, preview: nil, emote: $shopEmote)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }

                    categoryFilter

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
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Shop")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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

    // MARK: - Filtering / grouping

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
        .background(Color.black)
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
        .background(Color.black)
    }

    // MARK: - Row

    private func shopRow(_ item: ShopItem) -> some View {
        NavigationLink {
            ShopItemDetailView(item: item, avatar: avatar)
        } label: {
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
        .buttonStyle(.plain)
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
