import Foundation

/// A real-merchandise product in the Rally referral catalog.
///
/// `RallyGearItem` is the commerce-facing counterpart to the in-app
/// `ShopItem`. Where `ShopItem` drives avatar coloring and equip logic,
/// `RallyGearItem` carries everything needed to present an editorial
/// product card and route the player to the vendor's page:
/// a product image URL, a real-brand referral URL with a `{REFERRAL_CODE}`
/// token, and a display price string.
///
/// Loaded by `RallyReferralCatalog` from the bundled JSON file.
/// Use `RallyReferralLinkRouter` to open any `referralURL`.

// MARK: - Gear Slot

/// Mirrors `RallyGearSlot` from `RallyAvatarAppearance` so the referral
/// catalog can drive the avatar's Try-On system without importing the
/// full appearance model.
enum ReferralGearSlot: String, Codable, CaseIterable {
    case racket
    case top
    case shorts
    case shoes
    case socks
    case headband

    /// Maps back to the canonical `RallyGearSlot` used by the appearance store.
    var avatarSlot: RallyGearSlot {
        switch self {
        case .racket:   return .racket
        case .top:      return .top
        case .shorts:   return .shorts
        case .shoes:    return .shoes
        case .socks:    return .socks
        case .headband: return .headband
        }
    }
}

// MARK: - RallyGearItem

struct RallyGearItem: Identifiable, Codable, Hashable {
    /// Stable ID — matches a `ShopItem.id` where a coloring entry exists.
    let id: String
    /// Brand display name (e.g. "Nike", "Wilson").
    let brand: String
    /// Product display name (e.g. "Air Zoom Vapor 11").
    let name: String
    /// Which avatar slot this item occupies.
    let slot: ReferralGearSlot
    /// Human-readable colorway (e.g. "White / Black").
    let colorwayName: String
    /// Pre-formatted price string — never computed math on price here.
    let priceDisplay: String
    /// Remote product image URL for `AsyncImage`. May be nil if the brand
    /// does not surface a stable CDN image URL.
    let productImageURL: URL?
    /// Vendor product page URL containing the `{REFERRAL_CODE}` token.
    /// Always route through `RallyReferralLinkRouter` — never open raw.
    let referralURL: URL
    /// Hex color of the item's primary colorway for avatar preview fallback.
    let accentColorHex: String

    /// Try-on is always free; purchase happens on the vendor's site.
    var isOwnedForTryOn: Bool { true }

    enum CodingKeys: String, CodingKey {
        case id, brand, name, slot, colorwayName, priceDisplay
        case productImageURL, referralURL, accentColorHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(String.self, forKey: .id)
        brand          = try c.decode(String.self, forKey: .brand)
        name           = try c.decode(String.self, forKey: .name)
        slot           = try c.decode(ReferralGearSlot.self, forKey: .slot)
        colorwayName   = try c.decode(String.self, forKey: .colorwayName)
        priceDisplay   = try c.decode(String.self, forKey: .priceDisplay)
        accentColorHex = try c.decode(String.self, forKey: .accentColorHex)

        if let rawImage = try c.decodeIfPresent(String.self, forKey: .productImageURL) {
            productImageURL = URL(string: rawImage)
        } else {
            productImageURL = nil
        }

        let rawReferral = try c.decode(String.self, forKey: .referralURL)
        guard let parsed = URL(string: rawReferral) else {
            throw DecodingError.dataCorruptedError(
                forKey: .referralURL,
                in: c,
                debugDescription: "referralURL is not a valid URL: \(rawReferral)"
            )
        }
        referralURL = parsed
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,             forKey: .id)
        try c.encode(brand,          forKey: .brand)
        try c.encode(name,           forKey: .name)
        try c.encode(slot,           forKey: .slot)
        try c.encode(colorwayName,   forKey: .colorwayName)
        try c.encode(priceDisplay,   forKey: .priceDisplay)
        try c.encode(accentColorHex, forKey: .accentColorHex)
        try c.encodeIfPresent(productImageURL?.absoluteString, forKey: .productImageURL)
        try c.encode(referralURL.absoluteString, forKey: .referralURL)
    }
}
