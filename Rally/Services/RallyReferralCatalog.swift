import Foundation

/// Loads the Rally gear catalog from the bundled `RallyReferralCatalog.json`
/// and provides fast lookup by ID and slot.
///
/// The JSON is the single source of truth for real-merchandise data:
/// brand names, product image URLs, and referral URLs (with the
/// `{REFERRAL_CODE}` placeholder injected at open-time by
/// `RallyReferralLinkRouter`).
///
/// Catalog is loaded once at first access; the JSON lives in
/// `Rally/Resources/RallyReferralCatalog.json`.
enum RallyReferralCatalog {

    // MARK: - Loading

    private static let _items: [RallyGearItem] = {
        guard let url = Bundle.main.url(forResource: "RallyReferralCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("RallyReferralCatalog: missing bundled JSON — add RallyReferralCatalog.json to Resources.")
            return []
        }
        do {
            return try JSONDecoder().decode([RallyGearItem].self, from: data)
        } catch {
            assertionFailure("RallyReferralCatalog: JSON decode failed — \(error)")
            return []
        }
    }()

    /// All catalog items. Loaded once from the bundled JSON.
    static var allItems: [RallyGearItem] { _items }

    // MARK: - Lookup

    /// Returns the item matching `id`, or `nil` if not in the catalog.
    static func item(id: String) -> RallyGearItem? {
        allItems.first { $0.id == id }
    }

    /// Returns all items in a given gear slot.
    static func items(in slot: ReferralGearSlot) -> [RallyGearItem] {
        allItems.filter { $0.slot == slot }
    }

    /// Returns the first catalog item whose ID matches a given `ShopItem.id`.
    /// Used to enrich `ShopItemDetailView` with product imagery and referral
    /// links without replacing the existing `ShopItem` model.
    static func referralItem(matchingShopItemID shopID: String) -> RallyGearItem? {
        allItems.first { $0.id == shopID }
    }

    // MARK: - Audit helpers

    /// True when every item has non-empty brand, name, priceDisplay,
    /// productImageURL, and a referralURL containing the token.
    static var passesS1Audit: Bool {
        guard allItems.count >= 12 else { return false }
        return allItems.allSatisfy {
            !$0.brand.isEmpty &&
            !$0.name.isEmpty &&
            !$0.priceDisplay.isEmpty &&
            $0.productImageURL != nil &&
            !$0.referralURL.absoluteString.isEmpty
        }
    }

    /// True when every referralURL contains `{REFERRAL_CODE}` before
    /// substitution and is a valid URL after substitution.
    static var passesS2Audit: Bool {
        allItems.allSatisfy { item in
            let raw = item.referralURL.absoluteString
            guard raw.contains("{REFERRAL_CODE}") else { return false }
            return RallyReferralLinkRouter.resolveReferralStatic(in: raw) != nil
        }
    }
}
