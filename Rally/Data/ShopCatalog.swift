import Foundation
import SwiftUI

// MARK: - Vendor

struct Vendor: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    /// Vendor homepage / storefront — opened from the shop tab "Visit store".
    let websiteURL: URL
    /// Official membership / rewards hub where shoppers commonly find
    /// seasonal codes (never fabricated here — UI links out only).
    let loyaltyProgramURL: URL?
    /// One-line context shown next to partner links: sign-up offers, apps,
    /// student programs, etc.
    let referralSummary: String?

    init(
        id: String,
        displayName: String,
        websiteURL: URL,
        loyaltyProgramURL: URL? = nil,
        referralSummary: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.websiteURL = websiteURL
        self.loyaltyProgramURL = loyaltyProgramURL
        self.referralSummary = referralSummary
    }
}

// MARK: - Editorial shop stories

struct ShopEditorialEdit: Identifiable, Hashable, Codable {
    let id: String
    let vendorID: String
    let title: String
    let eyebrow: String
    let subtitle: String
    let body: String
    let tintHex: String
    let itemIDs: [String]

    var tintColor: Color { Color(hex: tintHex) ?? .white }
}

// MARK: - Shop item

/// A piece of equipment / apparel the player can equip on their avatar.
/// Items are static catalog content (not user data), so they live in code,
/// not SwiftData. Adding a new item is a one-line append in
/// `ShopCatalog.allItems`.
struct ShopItem: Identifiable, Hashable, Codable {

    enum Category: String, Codable, CaseIterable, Identifiable {
        case top, bottom, shoes, racket, bag, accessory
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .top:        return "Tops"
            case .bottom:     return "Bottoms"
            case .shoes:      return "Shoes"
            case .racket:     return "Rackets"
            case .bag:        return "Bags"
            case .accessory:  return "Accessories"
            }
        }
        var iconSystemName: String {
            switch self {
            case .top:       return "tshirt.fill"
            case .bottom:    return "rectangle.fill"
            case .shoes:     return "shoe.fill"
            case .racket:    return "tennis.racket"
            case .bag:       return "bag.fill"
            case .accessory: return "sparkles"
            }
        }
    }

    let id: String
    let category: Category
    let name: String
    let brand: String
    let vendorID: String
    /// Deep link to the product page on the vendor's website.
    let productURL: URL
    let priceUSD: Double
    /// Color the item renders as on the avatar.
    let colorHex: String
    /// Secondary accent (stripe, sole, etc.).
    let accentHex: String?
    /// Codes **must not** be invented for third-party brands. Use `nil`
    /// unless you have an authorized partner code. Rally-original SKUs may
    /// ship fictional codes for the in-app economy demo.
    let checkoutPromoCode: String?
    /// Short redemption hint — e.g. "Apply in Nike app during checkout."
    let promoNote: String?

    init(
        id: String,
        category: Category,
        name: String,
        brand: String,
        vendorID: String,
        productURL: URL,
        priceUSD: Double,
        colorHex: String,
        accentHex: String?,
        checkoutPromoCode: String? = nil,
        promoNote: String? = nil
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.brand = brand
        self.vendorID = vendorID
        self.productURL = productURL
        self.priceUSD = priceUSD
        self.colorHex = colorHex
        self.accentHex = accentHex
        self.checkoutPromoCode = checkoutPromoCode
        self.promoNote = promoNote
    }
}

extension ShopItem {
    var color: Color { Color(hex: colorHex) ?? .gray }
    var accentColor: Color? { accentHex.flatMap { Color(hex: $0) } }
    var priceDisplay: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.minimumFractionDigits = priceUSD.rounded() == priceUSD ? 0 : 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: priceUSD)) ?? "$\(Int(priceUSD))"
    }

    /// Product URL tagged so vendors can attribute Rally traffic in analytics.
    /// Codes themselves are never embedded in the query string.
    var trackingProductURL: URL {
        guard var c = URLComponents(url: productURL, resolvingAgainstBaseURL: false) else {
            return productURL
        }
        var q = c.queryItems ?? []
        q.append(URLQueryItem(name: "utm_source", value: "rally_ios"))
        q.append(URLQueryItem(name: "utm_medium", value: "partner_shop"))
        c.queryItems = q
        return c.url ?? productURL
    }
}

// MARK: - Racket profiles

struct RacketGameplayTuning: Hashable {
    let travelScalar: Double
    let timingAssistScalar: Double
    let horizonSpreadScalar: CGFloat
    let strikeWidthScalar: CGFloat
    let curveScalar: CGFloat
    let spawnScaleScalar: CGFloat
    let strikeScaleScalar: CGFloat
    let overrunScaleScalar: CGFloat

    static let balanced = RacketGameplayTuning(
        travelScalar: 1.0,
        timingAssistScalar: 1.0,
        horizonSpreadScalar: 1.0,
        strikeWidthScalar: 1.0,
        curveScalar: 1.0,
        spawnScaleScalar: 1.0,
        strikeScaleScalar: 1.0,
        overrunScaleScalar: 1.0
    )
}

struct RacketProfile: Hashable, Identifiable {
    let id: String
    let family: String
    let playerFit: String
    let performanceFocus: String
    let headSizeSqIn: Int
    let weightGrams: Int
    let balanceMM: Int
    let stringPattern: String
    let summary: String
    let gameplayTuning: RacketGameplayTuning
}

// MARK: - Catalog

enum ShopCatalog {

    // Default equipped items (free, ship with the app). The avatar always
    // has _something_ equipped in every slot.
    static let defaultTopID    = "rally.default.top"
    static let defaultBottomID = "rally.default.bottom"
    static let defaultShoesID  = "asics.court.ff.3.novak"
    static let defaultRacketID = "wilson.rf01.pro"

    /// Retained for saved outfits and locker lookup; their current SKU already
    /// has a canonical card in the storefront.
    static let legacyDuplicateItemIDs: Set<String> = ["newbalance.tournament.skort.white"]

    // Original digital gear. Historical IDs stay opaque so existing outfits survive.
    static let vendors: [Vendor] = [
        .init(id: "vela", displayName: "Vela Originals",
              websiteURL: URL(string: "https://apps.apple.com/app/id6822144057")!)
    ]

    static let editorialEdits: [ShopEditorialEdit] = []

    static let allItems: [ShopItem] = [
        .init(id: defaultTopID, category: .top, name: "Court Tee 01", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#121820", accentHex: "#65D8EA"),
        .init(id: defaultBottomID, category: .bottom, name: "Court Shorts 01", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#1A1A1A", accentHex: nil),
        .init(id: "rally.default.shoes", category: .shoes, name: "Court Shoes 01", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#FFFFFF", accentHex: "#00E5FF"),
        .init(id: "rally.default.racket", category: .racket, name: "Match Racket 01", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#C0C0C0", accentHex: "#00E5FF"),
        .init(id: "nike.advantage.top.fz6910.010", category: .top, name: "Court Tee 02", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#171717", accentHex: "#FFFFFF"),
        .init(id: "newbalance.tournament.tank.white", category: .top, name: "Court Tee 03", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#F6F5F1", accentHex: "#C7CCD1"),
        .init(id: "nike.dri-fit.tee.cobalt", category: .top, name: "Court Tee 04", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#0044AA", accentHex: "#FFFFFF"),
        .init(id: "adidas.club.polo.lime", category: .top, name: "Court Tee 05", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#C8FF36", accentHex: "#000000"),
        .init(id: "uniqlo.dry.polo.white", category: .top, name: "Court Tee 06", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#F4F4F4", accentHex: "#222222"),
        .init(id: "lacoste.croc.polo.green", category: .top, name: "Court Tee 07", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#0C5E2A", accentHex: "#FFFFFF"),
        .init(id: "nike.advantage.short.fz6913.010", category: .bottom, name: "Court Shorts 02", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#171717", accentHex: "#FFFFFF"),
        .init(id: "adidas.ergo.pro.short.kv4294", category: .bottom, name: "Court Shorts 03", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#F4F4F2", accentHex: "#262626"),
        .init(id: "newbalance.tournament.skort.wb61s4jj.white", category: .bottom, name: "Court Shorts 04", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#F7F6F2", accentHex: "#C7CCD1"),
        .init(id: "newbalance.tournament.skort.white", category: .bottom, name: "Court Shorts 05", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#F7F6F2", accentHex: "#D7DADF"),
        .init(id: "nike.court.short.black", category: .bottom, name: "Court Shorts 06", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#111111", accentHex: "#FFFFFF"),
        .init(id: "adidas.gameset.short.navy", category: .bottom, name: "Court Shorts 07", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#1E2A55", accentHex: "#FFFFFF"),
        .init(id: "uniqlo.dry.short.gray", category: .bottom, name: "Court Shorts 08", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#646464", accentHex: nil),
        .init(id: "asics.court.ff.3.novak", category: .shoes, name: "Court Shoes 02", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#F3F6F4", accentHex: "#17D8E8"),
        .init(id: "nike.vapor.pro.3", category: .shoes, name: "Court Shoes 03", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#FFFFFF", accentHex: "#111111"),
        .init(id: "adidas.adizero.ubersonic.5", category: .shoes, name: "Court Shoes 04", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#FAF7EC", accentHex: "#F05A28"),
        .init(id: "newbalance.coco.cg2.sea.salt", category: .shoes, name: "Court Shoes 05", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#F2EEE7", accentHex: "#7FA9D8"),
        .init(id: "newbalance.fuelcell.996v6.white", category: .shoes, name: "Court Shoes 06", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#FFFFFF", accentHex: "#1E1E1E"),
        .init(id: "nike.vapor.pro.white", category: .shoes, name: "Court Shoes 07", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#FFFFFF", accentHex: "#FF1A55"),
        .init(id: "adidas.barricade.red", category: .shoes, name: "Court Shoes 08", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#E32B2B", accentHex: "#000000"),
        .init(id: "asics.gel.resolution", category: .shoes, name: "Court Shoes 09", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#0A2B5C", accentHex: "#FFD400"),
        .init(id: "wilson.rf01.pro", category: .racket, name: "Match Racket 02", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#161616", accentHex: "#D8C89A"),
        .init(id: "wilson.blade.98.16x19.v9", category: .racket, name: "Match Racket 03", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#10251E", accentHex: "#8AE0C0"),
        .init(id: "yonex.percept.97h", category: .racket, name: "Match Racket 04", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#253B67", accentHex: "#7FD26A"),
        .init(id: "wilson.pro.staff.97", category: .racket, name: "Match Racket 05", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#1B1B1B", accentHex: "#C0392B"),
        .init(id: "babolat.pure.aero", category: .racket, name: "Match Racket 06", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#F5C518", accentHex: "#1B1B1B"),
        .init(id: "head.speed.mp", category: .racket, name: "Match Racket 07", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#FFFFFF", accentHex: "#000000"),
        .init(id: "yonex.ezone.98", category: .racket, name: "Match Racket 08", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#1F73C2", accentHex: "#FFFFFF"),
        .init(id: "babolat.pure.drive.gen11", category: .racket, name: "Match Racket 09", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#1A61D8", accentHex: "#E53935"),
        .init(id: "yonex.percept.100", category: .racket, name: "Match Racket 10", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#253B67", accentHex: "#7FD26A"),
        .init(id: "yonex.vcore.100", category: .racket, name: "Match Racket 11", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#A41222", accentHex: "#FFFFFF"),
        .init(id: "babolat.bag.6pack", category: .bag, name: "Court Bag 01", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#F5C518", accentHex: "#1B1B1B"),
        .init(id: "nike.headband.white", category: .accessory, name: "Headband 01", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#FFFFFF", accentHex: nil),
        .init(id: "rally.wristband.neon", category: .accessory, name: "Headband 02", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#00E5FF", accentHex: "#FF1A8C"),
        .init(id: "rally.wristband.tour.wimbledon", category: .accessory, name: "Headband 03", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#1F6F3A", accentHex: "#FFFFFF"),
        .init(id: "rally.wristband.tour.roland", category: .accessory, name: "Headband 04", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#B14424", accentHex: "#FFFFFF"),
        .init(id: "rally.wristband.tour.ashe", category: .accessory, name: "Headband 05", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#13295E", accentHex: "#E8C84A"),
        .init(id: "rally.wristband.tour.laver", category: .accessory, name: "Headband 06", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#0057A8", accentHex: "#FFFFFF"),
        .init(id: "rally.wristband.tour.indianwells", category: .accessory, name: "Headband 07", brand: "Vela", vendorID: "vela",
              productURL: URL(string: "https://apps.apple.com/app/id6822144057")!,
              priceUSD: 0, colorHex: "#2E7D6B", accentHex: "#F5E6C8"),
    ]

    /// Court-atlas → shop-item gating. Items listed as a value here are
    /// hidden from `visibleItems(...)` until their court is in
    /// `CourtUnlocks.shared.unlockedCourtIDs`. The reverse-lookup is also
    /// used by `CourtDetailView` to show "Tap to unlock the Lawn Tour Band".
    static let courtUnlockToShopItem: [String: String] = [
        // Tier 1 — the original two Slam check-in rewards.
        "wimbledon.cc":    "rally.wristband.tour.wimbledon",
        "rolandgarros.pc": "rally.wristband.tour.roland",
        // Tier 2 — hard-court majors and Masters 1000 venues added in CC sprint.
        "usopen.ashe":     "rally.wristband.tour.ashe",
        "ausopen.rl":      "rally.wristband.tour.laver",
        "indianwells":     "rally.wristband.tour.indianwells",
    ]

    /// Set of shop item IDs that are court-gated. Cheap precomputed lookup.
    static let courtGatedItemIDs: Set<String> = Set(courtUnlockToShopItem.values)

    // MARK: - Lookup

    static func item(id: String) -> ShopItem? {
        allItems.first { $0.id == id }
    }

    static func items(in category: ShopItem.Category) -> [ShopItem] {
        allItems.filter { $0.category == category }
    }

    static func vendor(id: String) -> Vendor? {
        vendors.first { $0.id == id }
    }

    static func racketProfile(id: String) -> RacketProfile? {
        racketProfiles[id]
    }

    static func editorialItems(for edit: ShopEditorialEdit) -> [ShopItem] {
        edit.itemIDs.compactMap(item)
    }

    static func itemsGroupedByVendor() -> [(Vendor, [ShopItem])] {
        let byVendor = Dictionary(grouping: allItems, by: { $0.vendorID })
        return vendors.sorted { vendorPriority($0.id) < vendorPriority($1.id) }.compactMap { v in
            guard let items = byVendor[v.id], !items.isEmpty else { return nil }
            return (v, items)
        }
    }

    /// Filters `items` down to whatever the player can currently see,
    /// hiding court-gated tour cosmetics until their corresponding court
    /// is unlocked. Equipped items always pass through so a snapshot pull
    /// that already lists a tour item doesn't suddenly disappear.
    static func visibleItems(_ items: [ShopItem], unlockedCourtIDs: Set<String>, equippedIDs: Set<String> = []) -> [ShopItem] {
        let unlockedItemIDs: Set<String> = Set(
            unlockedCourtIDs.compactMap { courtUnlockToShopItem[$0] }
        )
        return items.filter { item in
            if !courtGatedItemIDs.contains(item.id) { return true }
            if unlockedItemIDs.contains(item.id) { return true }
            if equippedIDs.contains(item.id) { return true }
            return false
        }
    }

    private static let racketProfiles: [String: RacketProfile] = [
        defaultRacketID: .init(
            id: defaultRacketID,
            family: "Vela Match",
            playerFit: "Advanced players who want controlled weight",
            performanceFocus: "Precision + plow",
            headSizeSqIn: 100,
            weightGrams: 320,
            balanceMM: 315,
            stringPattern: "16x19",
            summary: "Original Vela racket tuning for this digital court setup.",
            gameplayTuning: .init(
                travelScalar: 0.985,
                timingAssistScalar: 1.02,
                horizonSpreadScalar: 0.96,
                strikeWidthScalar: 0.98,
                curveScalar: 0.94,
                spawnScaleScalar: 1.0,
                strikeScaleScalar: 1.08,
                overrunScaleScalar: 1.04
            )
        ),
        "wilson.blade.98.16x19.v9": .init(
            id: "wilson.blade.98.16x19.v9",
            family: "Vela Match",
            playerFit: "All-court players who want feel and shape",
            performanceFocus: "Control + feel",
            headSizeSqIn: 98,
            weightGrams: 305,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "Original Vela racket tuning for this digital court setup.",
            gameplayTuning: .init(
                travelScalar: 1.0,
                timingAssistScalar: 1.03,
                horizonSpreadScalar: 0.98,
                strikeWidthScalar: 0.99,
                curveScalar: 1.03,
                spawnScaleScalar: 1.0,
                strikeScaleScalar: 1.02,
                overrunScaleScalar: 1.0
            )
        ),
        "yonex.percept.97h": .init(
            id: "yonex.percept.97h",
            family: "Vela Match",
            playerFit: "Strong control players who create their own pace",
            performanceFocus: "Feel + stability",
            headSizeSqIn: 97,
            weightGrams: 330,
            balanceMM: 310,
            stringPattern: "16x19",
            summary: "Original Vela racket tuning for this digital court setup.",
            gameplayTuning: .init(
                travelScalar: 1.01,
                timingAssistScalar: 0.99,
                horizonSpreadScalar: 0.96,
                strikeWidthScalar: 0.96,
                curveScalar: 1.08,
                spawnScaleScalar: 0.98,
                strikeScaleScalar: 1.0,
                overrunScaleScalar: 0.98
            )
        ),
        "wilson.pro.staff.97": .init(
            id: "wilson.pro.staff.97",
            family: "Vela Match",
            playerFit: "Club players wanting comfort and easy power",
            performanceFocus: "Comfort + power",
            headSizeSqIn: 100,
            weightGrams: 295,
            balanceMM: 310,
            stringPattern: "16x19",
            summary: "Original Vela racket tuning for this digital court setup.",
            gameplayTuning: .init(
                travelScalar: 0.99,
                timingAssistScalar: 1.03,
                horizonSpreadScalar: 0.98,
                strikeWidthScalar: 1.0,
                curveScalar: 0.95,
                spawnScaleScalar: 1.02,
                strikeScaleScalar: 1.03,
                overrunScaleScalar: 1.02
            )
        ),
        "babolat.pure.aero": .init(
            id: "babolat.pure.aero",
            family: "Vela Match",
            playerFit: "Fast modern attackers",
            performanceFocus: "Spin + precision",
            headSizeSqIn: 98,
            weightGrams: 305,
            balanceMM: 315,
            stringPattern: "16x20",
            summary: "Original Vela racket tuning for this digital court setup.",
            gameplayTuning: .init(
                travelScalar: 1.0,
                timingAssistScalar: 0.98,
                horizonSpreadScalar: 1.05,
                strikeWidthScalar: 0.99,
                curveScalar: 1.28,
                spawnScaleScalar: 0.98,
                strikeScaleScalar: 1.05,
                overrunScaleScalar: 1.04
            )
        ),
        "head.speed.mp": .init(
            id: "head.speed.mp",
            family: "Vela Match",
            playerFit: "Balanced tournament baseliners",
            performanceFocus: "Speed + control",
            headSizeSqIn: 100,
            weightGrams: 300,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "Original Vela racket tuning for this digital court setup.",
            gameplayTuning: .init(
                travelScalar: 0.99,
                timingAssistScalar: 1.0,
                horizonSpreadScalar: 1.0,
                strikeWidthScalar: 1.0,
                curveScalar: 1.02,
                spawnScaleScalar: 1.0,
                strikeScaleScalar: 1.01,
                overrunScaleScalar: 1.0
            )
        ),
        "yonex.ezone.98": .init(
            id: "yonex.ezone.98",
            family: "Vela Match",
            playerFit: "Intermediate to advanced all-around hitters",
            performanceFocus: "Power + comfort",
            headSizeSqIn: 100,
            weightGrams: 300,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "Original Vela racket tuning for this digital court setup.",
            gameplayTuning: .init(
                travelScalar: 0.98,
                timingAssistScalar: 1.01,
                horizonSpreadScalar: 1.01,
                strikeWidthScalar: 1.02,
                curveScalar: 0.96,
                spawnScaleScalar: 1.0,
                strikeScaleScalar: 1.08,
                overrunScaleScalar: 1.08
            )
        ),
        "babolat.pure.drive.gen11": .init(
            id: "babolat.pure.drive.gen11",
            family: "Vela Match",
            playerFit: "Aggressive players chasing easy depth",
            performanceFocus: "Power + versatility",
            headSizeSqIn: 100,
            weightGrams: 300,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "Original Vela racket tuning for this digital court setup.",
            gameplayTuning: .init(
                travelScalar: 0.97,
                timingAssistScalar: 0.99,
                horizonSpreadScalar: 1.0,
                strikeWidthScalar: 1.03,
                curveScalar: 0.92,
                spawnScaleScalar: 1.0,
                strikeScaleScalar: 1.1,
                overrunScaleScalar: 1.1
            )
        ),
        "yonex.percept.100": .init(
            id: "yonex.percept.100",
            family: "Vela Match",
            playerFit: "Intermediate to advanced control players",
            performanceFocus: "Control + feel",
            headSizeSqIn: 100,
            weightGrams: 300,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "Original Vela racket tuning for this digital court setup.",
            gameplayTuning: .init(
                travelScalar: 1.01,
                timingAssistScalar: 1.04,
                horizonSpreadScalar: 0.97,
                strikeWidthScalar: 0.99,
                curveScalar: 1.04,
                spawnScaleScalar: 1.02,
                strikeScaleScalar: 0.99,
                overrunScaleScalar: 0.98
            )
        ),
        "yonex.vcore.100": .init(
            id: "yonex.vcore.100",
            family: "Vela Match",
            playerFit: "All-around players who want heavier spin action",
            performanceFocus: "Spin",
            headSizeSqIn: 100,
            weightGrams: 300,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "Original Vela racket tuning for this digital court setup.",
            gameplayTuning: .init(
                travelScalar: 0.99,
                timingAssistScalar: 0.98,
                horizonSpreadScalar: 1.06,
                strikeWidthScalar: 1.0,
                curveScalar: 1.3,
                spawnScaleScalar: 0.99,
                strikeScaleScalar: 1.06,
                overrunScaleScalar: 1.05
            )
        )
    ]

    private static func vendorPriority(_ id: String) -> Int {
        switch id {
        case "newbalance": return 0
        case "nike": return 1
        case "wilson": return 2
        default: return 10
        }
    }
}

/// Exact, reviewed product photography. Asset names are explicit so saved outfit
/// identifiers never depend on product names or a fuzzy brand/category search.
struct ShopProductPhotograph {
    let category: ShopItem.Category
    let assetName: String
    let styleID: String
    let colorway: String
    let productURL: URL
    let sourceURL: URL
    let imageURL: URL
}

extension ShopCatalog {
    static func photograph(for item: ShopItem) -> ShopProductPhotograph? {
        guard let photo = productPhotography[item.id], photo.category == item.category,
              photo.productURL == item.productURL else { return nil }
        return photo
    }

    /// Reviewed 2026-09-17; provenance and legacy-ID mappings are recorded in
    /// Docs/SHOP_PHOTOGRAPHY.md. Retailer prices and availability may change.
    static let productPhotography: [String: ShopProductPhotograph] = [:]
}
