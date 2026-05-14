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

extension ShopItem {
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
        .init(id: "wilson.pro.staff.97",     category: .racket, name: "Pro Staff 97 v14", brand: "Wilson", vendorID: "wilson",
              productURL: URL(string: "https://www.wilson.com/en-us/product/pro-staff-97-v14")!,
              priceUSD: 269, colorHex: "#1B1B1B", accentHex: "#C0392B"),
        .init(id: "babolat.pure.aero",       category: .racket, name: "Pure Aero", brand: "Babolat", vendorID: "babolat",
              productURL: URL(string: "https://www.babolat.com/us/rackets-tennis/pure-aero/")!,
              priceUSD: 279, colorHex: "#F5C518", accentHex: "#1B1B1B"),
        .init(id: "head.speed.mp",           category: .racket, name: "Speed MP", brand: "HEAD", vendorID: "head",
              productURL: URL(string: "https://www.head.com/en_US/sports/tennis/rackets/")!,
              priceUSD: 249, colorHex: "#FFFFFF", accentHex: "#000000"),
        .init(id: "yonex.ezone.98",          category: .racket, name: "EZONE 98", brand: "Yonex", vendorID: "yonex",
              productURL: URL(string: "https://www.yonex.com/tennis/rackets/")!,
              priceUSD: 249, colorHex: "#1F73C2", accentHex: "#FFFFFF"),

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
    ]

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

    static func itemsGroupedByVendor() -> [(Vendor, [ShopItem])] {
        let byVendor = Dictionary(grouping: allItems, by: { $0.vendorID })
        return vendors.compactMap { v in
            guard let items = byVendor[v.id], !items.isEmpty else { return nil }
            return (v, items)
        }
    }
}

// MARK: - Color hex helper

extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8)  & 0xFF) / 255.0
        let b = Double( value        & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
