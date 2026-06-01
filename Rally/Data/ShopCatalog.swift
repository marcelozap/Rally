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
        f.maximumFractionDigits = 0
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
    static let defaultShoesID  = "rally.default.shoes"
    static let defaultRacketID = "rally.default.racket"

    static let vendors: [Vendor] = [
        .init(
            id: "nike",
            displayName: "Nike Tennis",
            websiteURL: URL(string: "https://www.nike.com/w/tennis-1320s")!,
            loyaltyProgramURL: URL(string: "https://www.nike.com/membership")!,
            referralSummary: "Nike Membership & the Nike app — official source for member promos and early access."
        ),
        .init(
            id: "newbalance",
            displayName: "New Balance Tennis",
            websiteURL: URL(string: "https://www.newbalance.com/tennis/")!,
            loyaltyProgramURL: nil,
            referralSummary: "Official New Balance tennis footwear and apparel — seasonal pricing and account perks vary on newbalance.com."
        ),
        .init(
            id: "adidas",
            displayName: "adidas Tennis",
            websiteURL: URL(string: "https://www.adidas.com/us/tennis")!,
            loyaltyProgramURL: URL(string: "https://www.adidas.com/us/creators-club")!,
            referralSummary: "adidas Creators Club — points and member offers; verify any code at checkout on adidas.com."
        ),
        .init(
            id: "uniqlo",
            displayName: "UNIQLO Tennis",
            websiteURL: URL(string: "https://www.uniqlo.com/us/en/feature/lifewear/sports/tennis.html")!,
            loyaltyProgramURL: URL(string: "https://www.uniqlo.com/us/en/special-feature/app")!,
            referralSummary: "UNIQLO app & mailers — limited-time coupons vary by region and season."
        ),
        .init(
            id: "wilson",
            displayName: "Wilson",
            websiteURL: URL(string: "https://www.wilson.com/en-us/tennis")!,
            loyaltyProgramURL: URL(string: "https://www.wilson.com/en-us/account")!,
            referralSummary: "Create a Wilson account for alerts; promotions rotate on wilson.com."
        ),
        .init(
            id: "babolat",
            displayName: "Babolat",
            websiteURL: URL(string: "https://www.babolat.com/us/tennis")!,
            loyaltyProgramURL: URL(string: "https://www.babolat.com/us/account/login")!,
            referralSummary: "Subscribe at Babolat — seasonal sales & bundles vary by region."
        ),
        .init(
            id: "head",
            displayName: "HEAD",
            websiteURL: URL(string: "https://www.head.com/en_US/sports/tennis/")!,
            loyaltyProgramURL: URL(string: "https://www.head.com/en_US/customer/account/login")!,
            referralSummary: "HEAD newsletter & account — regional promos announced on head.com."
        ),
        .init(
            id: "yonex",
            displayName: "Yonex",
            websiteURL: URL(string: "https://www.yonex.com/tennis")!,
            loyaltyProgramURL: URL(string: "https://www.yonex.com/account/register")!,
            referralSummary: "Yonex USA promotions — follow official channels for authorized discounts."
        ),
        .init(
            id: "lacoste",
            displayName: "Lacoste",
            websiteURL: URL(string: "https://www.lacoste.com/us/lacoste/men/clothing/sport/tennis/")!,
            loyaltyProgramURL: URL(string: "https://www.lacoste.com/us/account-login")!,
            referralSummary: "Lacoste Le Club — rewards & exclusive offers when logged in."
        ),
        .init(
            id: "asics",
            displayName: "ASICS Tennis",
            websiteURL: URL(string: "https://www.asics.com/us/en-us/c/tennis/")!,
            loyaltyProgramURL: URL(string: "https://www.asics.com/us/en-us/mk/oneasics/rewards-program")!,
            referralSummary: "OneASICS Rewards — official loyalty perks on asics.com."
        ),
        .init(
            id: "rally-co",
            displayName: "Rally Originals",
            websiteURL: URL(string: "https://rally.app")!,
            loyaltyProgramURL: nil,
            referralSummary: "In-app cosmetics — fictional promo codes below demo the UX until live commerce ships."
        )
    ]

    static let editorialEdits: [ShopEditorialEdit] = [
        .init(
            id: "nb-club-whites",
            vendorID: "newbalance",
            title: "New Balance Club Whites",
            eyebrow: "Featured fit",
            subtitle: "Quiet luxury for first ball",
            body: "Tournament whites with Coco CG2 finish the look fast.",
            tintHex: "#E8D9B8",
            itemIDs: [
                "newbalance.tournament.tank.white",
                "newbalance.tournament.skort.white",
                "newbalance.coco.cg2.sea.salt"
            ]
        ),
        .init(
            id: "nike-night-session",
            vendorID: "nike",
            title: "Nike Night Session",
            eyebrow: "Match edit",
            subtitle: "Sharper contrast, faster silhouette",
            body: "Cobalt up top, black below, clean white Vapor Pro finish.",
            tintHex: "#00E5FF",
            itemIDs: [
                "nike.dri-fit.tee.cobalt",
                "nike.court.short.black",
                "nike.vapor.pro.white"
            ]
        ),
        .init(
            id: "wilson-center-court",
            vendorID: "wilson",
            title: "Wilson Center Court",
            eyebrow: "Hero frame",
            subtitle: "Big-match racket energy",
            body: "Clash 100 V3 leads the floor with premium match-point presence.",
            tintHex: "#F2C14E",
            itemIDs: [
                "wilson.pro.staff.97"
            ]
        )
    ]

    static let allItems: [ShopItem] = [
        // Default kit (free) ---------------------------------------------
        .init(id: defaultTopID,    category: .top,    name: "Rally Tee",      brand: "Rally", vendorID: "rally-co",
              productURL: URL(string: "https://rally.app/shop/default-top")!,
              priceUSD: 0, colorHex: "#FFFFFF", accentHex: nil,
              checkoutPromoCode: "RALLYKIT",
              promoNote: "Rally-original — demo code for in-app cosmetics."),
        .init(id: defaultBottomID, category: .bottom, name: "Court Shorts",   brand: "Rally", vendorID: "rally-co",
              productURL: URL(string: "https://rally.app/shop/default-bottom")!,
              priceUSD: 0, colorHex: "#1A1A1A", accentHex: nil,
              checkoutPromoCode: "RALLYKIT",
              promoNote: "Rally-original — demo code for in-app cosmetics."),
        .init(id: defaultShoesID,  category: .shoes,  name: "Baseliners",     brand: "Rally", vendorID: "rally-co",
              productURL: URL(string: "https://rally.app/shop/default-shoes")!,
              priceUSD: 0, colorHex: "#FFFFFF", accentHex: "#00E5FF",
              checkoutPromoCode: "RALLYKIT",
              promoNote: "Rally-original — demo code for in-app cosmetics."),
        .init(id: defaultRacketID, category: .racket, name: "Rally R-1",      brand: "Rally", vendorID: "rally-co",
              productURL: URL(string: "https://rally.app/shop/default-racket")!,
              priceUSD: 0, colorHex: "#C0C0C0", accentHex: "#00E5FF",
              checkoutPromoCode: "RALLYKIT",
              promoNote: "Rally-original — demo code for in-app cosmetics."),

        // Tops -----------------------------------------------------------
        .init(id: "newbalance.tournament.tank.white", category: .top, name: "Tournament Tank", brand: "New Balance", vendorID: "newbalance",
              productURL: URL(string: "https://www.newbalance.com/pd/tournament-tank/WT61K74K.html")!,
              priceUSD: 60, colorHex: "#F6F5F1", accentHex: "#C7CCD1"),
        .init(id: "nike.dri-fit.tee.cobalt", category: .top, name: "Dri-FIT Slam Tee", brand: "Nike", vendorID: "nike",
              productURL: URL(string: "https://www.nike.com/w/tennis-tops-tshirts")!,
              priceUSD: 55, colorHex: "#0044AA", accentHex: "#FFFFFF",
              promoNote: "Third-party SKU — only use codes issued by Nike; none are bundled here."),
        .init(id: "adidas.club.polo.lime",   category: .top, name: "Club 3-Stripes Polo", brand: "adidas", vendorID: "adidas",
              productURL: URL(string: "https://www.adidas.com/us/men-tennis-tops")!,
              priceUSD: 60, colorHex: "#C8FF36", accentHex: "#000000"),
        .init(id: "uniqlo.dry.polo.white",   category: .top, name: "DRY-EX Polo", brand: "UNIQLO", vendorID: "uniqlo",
              productURL: URL(string: "https://www.uniqlo.com/us/en/men/tops/polo-shirts")!,
              priceUSD: 30, colorHex: "#F4F4F4", accentHex: "#222222"),
        .init(id: "lacoste.croc.polo.green", category: .top, name: "Sport Croc Polo", brand: "Lacoste", vendorID: "lacoste",
              productURL: URL(string: "https://www.lacoste.com/us/lacoste/men/clothing/sport/tennis/")!,
              priceUSD: 125, colorHex: "#0C5E2A", accentHex: "#FFFFFF"),

        // Bottoms --------------------------------------------------------
        .init(id: "newbalance.tournament.skort.white", category: .bottom, name: "Tournament Skort", brand: "New Balance", vendorID: "newbalance",
              productURL: URL(string: "https://www.newbalance.com/pd/tournament-skort/WK21434.html")!,
              priceUSD: 55, colorHex: "#F7F6F2", accentHex: "#D7DADF"),
        .init(id: "nike.court.short.black",  category: .bottom, name: "NikeCourt 9″ Short", brand: "Nike", vendorID: "nike",
              productURL: URL(string: "https://www.nike.com/w/tennis-shorts")!,
              priceUSD: 60, colorHex: "#111111", accentHex: "#FFFFFF"),
        .init(id: "adidas.gameset.short.navy", category: .bottom, name: "Game-Set Short", brand: "adidas", vendorID: "adidas",
              productURL: URL(string: "https://www.adidas.com/us/men-tennis-shorts")!,
              priceUSD: 50, colorHex: "#1E2A55", accentHex: "#FFFFFF"),
        .init(id: "uniqlo.dry.short.gray",   category: .bottom, name: "DRY Stretch Short", brand: "UNIQLO", vendorID: "uniqlo",
              productURL: URL(string: "https://www.uniqlo.com/us/en/men/bottoms/shorts")!,
              priceUSD: 30, colorHex: "#646464", accentHex: nil),

        // Shoes ----------------------------------------------------------
        .init(id: "newbalance.coco.cg2.sea.salt", category: .shoes, name: "Coco CG2", brand: "New Balance", vendorID: "newbalance",
              productURL: URL(string: "https://www.newbalance.com/pd/coco-cg2/WCOC9AL-D-11.html")!,
              priceUSD: 160, colorHex: "#F2EEE7", accentHex: "#7FA9D8"),
        .init(id: "newbalance.fuelcell.996v6.white", category: .shoes, name: "FuelCell 996v6", brand: "New Balance", vendorID: "newbalance",
              productURL: URL(string: "https://www.newbalance.com/pd/fuelcell-996v6/WCH996W6-B-09.html")!,
              priceUSD: 135, colorHex: "#FFFFFF", accentHex: "#1E1E1E"),
        .init(id: "nike.vapor.pro.white",    category: .shoes, name: "Court Vapor Pro", brand: "Nike", vendorID: "nike",
              productURL: URL(string: "https://www.nike.com/w/tennis-shoes")!,
              priceUSD: 130, colorHex: "#FFFFFF", accentHex: "#FF1A55"),
        .init(id: "adidas.barricade.red",    category: .shoes, name: "Barricade 13", brand: "adidas", vendorID: "adidas",
              productURL: URL(string: "https://www.adidas.com/us/tennis-shoes")!,
              priceUSD: 140, colorHex: "#E32B2B", accentHex: "#000000"),
        .init(id: "asics.gel.resolution",    category: .shoes, name: "GEL-Resolution 9", brand: "ASICS", vendorID: "asics",
              productURL: URL(string: "https://www.asics.com/us/en-us/mens-tennis-shoes/c/aa10000000/")!,
              priceUSD: 150, colorHex: "#0A2B5C", accentHex: "#FFD400"),

        // Rackets --------------------------------------------------------
        .init(id: "wilson.pro.staff.97",     category: .racket, name: "Clash 100 V3", brand: "Wilson", vendorID: "wilson",
              productURL: URL(string: "https://www.wilson.com/en-us/product/clash-100-v3-0-frm-wr17280")!,
              priceUSD: 269, colorHex: "#1B1B1B", accentHex: "#C0392B"),
        .init(id: "babolat.pure.aero",       category: .racket, name: "Pure Aero 98", brand: "Babolat", vendorID: "babolat",
              productURL: URL(string: "https://www.babolat.com/us/pure-aero-98-unstrung/101499.html")!,
              priceUSD: 299, colorHex: "#F5C518", accentHex: "#1B1B1B"),
        .init(id: "head.speed.mp",           category: .racket, name: "Speed MP", brand: "HEAD", vendorID: "head",
              productURL: URL(string: "https://www.head.com/en_US/sports/tennis/rackets/")!,
              priceUSD: 249, colorHex: "#FFFFFF", accentHex: "#000000"),
        .init(id: "yonex.ezone.98",          category: .racket, name: "EZONE 100", brand: "Yonex", vendorID: "yonex",
              productURL: URL(string: "https://us.yonex.com/products/ezone-100")!,
              priceUSD: 305, colorHex: "#1F73C2", accentHex: "#FFFFFF"),
        .init(id: "babolat.pure.drive.gen11", category: .racket, name: "Pure Drive Gen11", brand: "Babolat", vendorID: "babolat",
              productURL: URL(string: "https://www.babolat.com/us/pure-drive-gen11-unstrung/3324922165546.html")!,
              priceUSD: 299, colorHex: "#1A61D8", accentHex: "#E53935"),
        .init(id: "yonex.percept.100",        category: .racket, name: "PERCEPT 100", brand: "Yonex", vendorID: "yonex",
              productURL: URL(string: "https://us.yonex.com/products/percept-100")!,
              priceUSD: 305, colorHex: "#253B67", accentHex: "#7FD26A"),
        .init(id: "yonex.vcore.100",          category: .racket, name: "VCORE 100", brand: "Yonex", vendorID: "yonex",
              productURL: URL(string: "https://us.yonex.com/products/08vcore-100")!,
              priceUSD: 305, colorHex: "#A41222", accentHex: "#FFFFFF"),

        // Bags / accessories ---------------------------------------------
        .init(id: "babolat.bag.6pack",       category: .bag, name: "Pure 6-Pack Bag", brand: "Babolat", vendorID: "babolat",
              productURL: URL(string: "https://www.babolat.com/us/bags-tennis/")!,
              priceUSD: 100, colorHex: "#F5C518", accentHex: "#1B1B1B"),
        .init(id: "nike.headband.white",     category: .accessory, name: "Dri-FIT Headband", brand: "Nike", vendorID: "nike",
              productURL: URL(string: "https://www.nike.com/w/tennis-accessories")!,
              priceUSD: 18, colorHex: "#FFFFFF", accentHex: nil),
        .init(id: "rally.wristband.neon",    category: .accessory, name: "Neon Wristband", brand: "Rally", vendorID: "rally-co",
              productURL: URL(string: "https://rally.app/shop/neon-wristband")!,
              priceUSD: 12, colorHex: "#00E5FF", accentHex: "#FF1A8C",
              checkoutPromoCode: "NEON10",
              promoNote: "Rally-original accessory — demo promo field."),

        // Tour-edition cosmetics — gated by court-atlas check-ins. Hidden
        // until `CourtUnlocks` reports the matching `courtID` is unlocked.
        .init(id: "rally.wristband.tour.wimbledon", category: .accessory, name: "Lawn Tour Band", brand: "Rally", vendorID: "rally-co",
              productURL: URL(string: "https://rally.app/shop/tour-wimbledon")!,
              priceUSD: 18, colorHex: "#1F6F3A", accentHex: "#FFFFFF",
              checkoutPromoCode: "TOURGRASS",
              promoNote: "Tour edition — unlocked by checking in at Centre Court."),
        .init(id: "rally.wristband.tour.roland",    category: .accessory, name: "Terre Battue Band", brand: "Rally", vendorID: "rally-co",
              productURL: URL(string: "https://rally.app/shop/tour-roland")!,
              priceUSD: 18, colorHex: "#B14424", accentHex: "#FFFFFF",
              checkoutPromoCode: "TOURCLAY",
              promoNote: "Tour edition — unlocked by checking in at Philippe Chatrier."),
    ]

    /// Court-atlas → shop-item gating. Items listed as a value here are
    /// hidden from `visibleItems(...)` until their court is in
    /// `CourtUnlocks.shared.unlockedCourtIDs`. The reverse-lookup is also
    /// used by `CourtDetailView` to show "Tap to unlock the Lawn Tour Band".
    static let courtUnlockToShopItem: [String: String] = [
        "wimbledon.cc":   "rally.wristband.tour.wimbledon",
        "rolandgarros.pc": "rally.wristband.tour.roland"
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
            family: "Rally Originals",
            playerFit: "All-around starter",
            performanceFocus: "Balanced",
            headSizeSqIn: 100,
            weightGrams: 300,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "Neutral demo frame used as Rally's baseline tuning.",
            gameplayTuning: .balanced
        ),
        "wilson.pro.staff.97": .init(
            id: "wilson.pro.staff.97",
            family: "Clash",
            playerFit: "Club players wanting comfort and easy power",
            performanceFocus: "Comfort + power",
            headSizeSqIn: 100,
            weightGrams: 295,
            balanceMM: 310,
            stringPattern: "16x19",
            summary: "Wilson positions Clash 100 V3 as the versatile club-player option for power, comfort, and control.",
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
            family: "Pure Aero",
            playerFit: "Fast modern attackers",
            performanceFocus: "Spin + precision",
            headSizeSqIn: 98,
            weightGrams: 305,
            balanceMM: 315,
            stringPattern: "16x20",
            summary: "Babolat describes the Pure Aero 98 as a spin-friendly 98 with tighter pattern control for aggressive hitters.",
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
            family: "Speed",
            playerFit: "Balanced tournament baseliners",
            performanceFocus: "Speed + control",
            headSizeSqIn: 100,
            weightGrams: 300,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "HEAD's Speed family sits in the quick, modern all-court lane with balanced pace and control.",
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
            family: "EZONE",
            playerFit: "Intermediate to advanced all-around hitters",
            performanceFocus: "Power + comfort",
            headSizeSqIn: 100,
            weightGrams: 300,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "Yonex positions EZONE 100 as effortless power with a bigger sweet spot and plush comfort.",
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
            family: "Pure Drive",
            playerFit: "Aggressive players chasing easy depth",
            performanceFocus: "Power + versatility",
            headSizeSqIn: 100,
            weightGrams: 300,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "Babolat sells Pure Drive Gen11 around explosive baseline power with enough feel to shape deep heavy shots.",
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
            family: "PERCEPT",
            playerFit: "Intermediate to advanced control players",
            performanceFocus: "Control + feel",
            headSizeSqIn: 100,
            weightGrams: 300,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "Yonex frames PERCEPT 100 as control and feel with flex and snapback for players who create their own game.",
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
            family: "VCORE",
            playerFit: "All-around players who want heavier spin action",
            performanceFocus: "Spin",
            headSizeSqIn: 100,
            weightGrams: 300,
            balanceMM: 320,
            stringPattern: "16x19",
            summary: "Yonex markets VCORE 100 around spin, snapback, speed, and stability for all-around competitors.",
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
