import SwiftUI
import SwiftData

struct ShopItemDetailView: View {
    let item: ShopItem
    @Bindable var avatar: AvatarConfig

    @Environment(\.modelContext) private var modelContext
    @State private var tryingOn: Bool = true

    private var vendor: Vendor? { ShopCatalog.vendor(id: item.vendorID) }

    init(item: ShopItem, avatar: AvatarConfig?) {
        self.item = item
        // If no avatar exists, this view shouldn't be reachable, but provide a
        // safety net so the UI doesn't crash. We create a transient one — it
        // won't be persisted unless explicitly saved.
        self._avatar = Bindable(avatar ?? AvatarConfig())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                AvatarView(
                    config: avatar,
                    preview: tryingOn && item.category != .bag && item.category != .accessory
                        ? (slot: item.category, item: item)
                        : nil
                )
                .frame(height: 320)
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    header
                    swatchRow
                    if item.category != .bag, item.category != .accessory {
                        tryOnToggle
                    }
                    actionRow
                    if let vendor = vendor {
                        vendorCard(vendor)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.brand)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.5))
            HStack(alignment: .firstTextBaseline) {
                Text(item.name)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(item.priceUSD == 0 ? "Included" : item.priceDisplay)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.cyan)
            }
        }
    }

    private var swatchRow: some View {
        HStack(spacing: 8) {
            Circle().fill(item.color).frame(width: 30, height: 30)
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            if let accent = item.accentColor {
                Circle().fill(accent).frame(width: 30, height: 30)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            Text(item.category.displayName)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.leading, 6)
            Spacer()
        }
    }

    private var tryOnToggle: some View {
        Toggle(isOn: $tryingOn) {
            HStack(spacing: 8) {
                Image(systemName: tryingOn ? "tshirt.fill" : "tshirt")
                Text(tryingOn ? "Trying it on" : "Try it on")
            }
            .foregroundStyle(.white)
        }
        .tint(.cyan)
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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.cyan.opacity(0.18))
                )
                .foregroundStyle(.cyan)
            } else {
                Button {
                    equip()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Equip")
                    }
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.cyan)
                    )
                    .foregroundStyle(.black)
                }
            }

            Link(destination: item.productURL) {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                    Text(item.priceUSD == 0 ? "View on rally.app" : "Buy at \(item.brand)")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(.headline, design: .rounded))
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cyan, lineWidth: 1.5)
                )
                .foregroundStyle(.cyan)
            }
        }
    }

    private func vendorCard(_ vendor: Vendor) -> some View {
        Link(destination: vendor.websiteURL) {
            HStack(spacing: 12) {
                Image(systemName: "storefront.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading) {
                    Text("Sold by")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(vendor.displayName)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
            )
        }
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
    }
}
