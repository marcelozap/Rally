import CoreLocation
import Foundation

/// Curated iconic tennis venues for the **Court atlas** map. Data is static (like
/// `ShopCatalog`) — only tennis-specific pins appear on the map.
struct IconicTennisCourt: Identifiable, Hashable {
    let id: String
    let name: String
    /// City · Country
    let subtitle: String
    let latitude: Double
    let longitude: Double
    /// One-line hook for the card.
    let vibe: String
    /// Longer copy for the detail screen.
    let detail: String
    /// Official venue / tournament site — opens in Safari (tagged like shop URLs).
    let venueWebsiteURL: URL?
    /// Booking, hospitality, or official membership portal when applicable.
    let bookingOrMembershipURL: URL?
    /// Same spirit as `Vendor.referralSummary`: points users to **official** channels only.
    let referralSummary: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Opens Apple Maps at the pin.
    var appleMapsURL: URL {
        var c = URLComponents(string: "https://maps.apple.com/")!
        c.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: name),
            URLQueryItem(name: "utm_source", value: "rally_ios"),
            URLQueryItem(name: "utm_medium", value: "court_atlas"),
        ]
        return c.url!
    }

    /// Satellite-friendly browsing in the browser (closest universal “Earth-like” deep link without SDKs).
    var googleMapsSatelliteURL: URL {
        // ll + z triggers satellite-style web client for many regions.
        URL(string: "https://www.google.com/maps/@\(latitude),\(longitude),16z/data=!3m1!1e3")!
    }

    func trackingURL(for base: URL) -> URL {
        guard var c = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }
        var q = c.queryItems ?? []
        q.append(URLQueryItem(name: "utm_source", value: "rally_ios"))
        q.append(URLQueryItem(name: "utm_medium", value: "court_atlas"))
        c.queryItems = q
        return c.url ?? base
    }
}

enum IconicCourtsCatalog {
    static let allCourts: [IconicTennisCourt] = [
        IconicTennisCourt(
            id: "wimbledon.cc",
            name: "Centre Court · Wimbledon",
            subtitle: "London · UK",
            latitude: 51.43484,
            longitude: -0.21462,
            vibe: "Grass cathedral · strawberries & silence between points.",
            detail: "The sport’s most famous lawn. If you ever walk the grounds, book ahead for tours or public ballot insight via the official site — demand is extreme.",
            venueWebsiteURL: URL(string: "https://www.wimbledon.com/"),
            bookingOrMembershipURL: URL(string: "https://www.wimbledon.com/en_GB/tickets-and-hospitality"),
            referralSummary: "Tickets & hospitality only through official Wimbledon channels — avoid resale scams."
        ),
        IconicTennisCourt(
            id: "rolandgarros.pc",
            name: "Philippe Chatrier · Roland-Garros",
            subtitle: "Paris · France",
            latitude: 48.8473,
            longitude: 2.2469,
            vibe: "Red clay drama · sliding Sundays.",
            detail: "Stade Roland-Garros hosts the French Open’s showcourt. Combine with spring Paris trips; priority draws sell via FFT-affiliated sales.",
            venueWebsiteURL: URL(string: "https://www.rolandgarros.com/"),
            bookingOrMembershipURL: URL(string: "https://tickets.rolandgarros.com/"),
            referralSummary: "Verify purchases through FFT / Roland-Garros ticketing — bundles and resale rules change yearly."
        ),
        IconicTennisCourt(
            id: "usopen.ashe",
            name: "Arthur Ashe Stadium",
            subtitle: "New York · USA",
            latitude: 40.7499,
            longitude: -73.8468,
            vibe: "Lights-on majors energy · biggest tennis arena on Earth.",
            detail: "USTA Billie Jean King National Tennis Center during the US Open feels like a festival. Night sessions are legendary.",
            venueWebsiteURL: URL(string: "https://www.usopen.org/"),
            bookingOrMembershipURL: URL(string: "https://www.usopen.org/en_US/tickets/"),
            referralSummary: "US Open tickets & passes via usopen.org — third-party listings should be cross-checked."
        ),
        IconicTennisCourt(
            id: "ausopen.rl",
            name: "Rod Laver Arena",
            subtitle: "Melbourne · Australia",
            latitude: -37.8227,
            longitude: 144.9789,
            vibe: "Summer slam · retractable roof midnight sessions.",
            detail: "Melbourne Park during January turns into a tennis city. AO Ballpark and grounds passes add atmosphere beyond centre court.",
            venueWebsiteURL: URL(string: "https://ausopen.com/"),
            bookingOrMembershipURL: URL(string: "https://tickets.ausopen.com/"),
            referralSummary: "Australian Open tickets rotate through official AO releases — subscribe for ballot alerts."
        ),
        IconicTennisCourt(
            id: "indianwells",
            name: "Indian Wells Tennis Garden",
            subtitle: "California · USA",
            latitude: 33.7244,
            longitude: -116.3116,
            vibe: "Desert palm-lined superseries oasis.",
            detail: "Often called tennis paradise — mountains behind the courts and crisp desert air. BNPP Open weeks fill hotels fast.",
            venueWebsiteURL: URL(string: "https://bnppopen.com/"),
            bookingOrMembershipURL: URL(string: "https://bnppopen.com/en/tickets"),
            referralSummary: "Indian Wells sessions & mini-plans sell on the official tournament site first."
        ),
        IconicTennisCourt(
            id: "montecarlo.mccc",
            name: "Monte Carlo Country Club",
            subtitle: "Roquebrune-Cap-Martin · Monaco area",
            latitude: 43.7524,
            longitude: 7.4339,
            vibe: "Sea-cliff clay · yachts below the baseline.",
            detail: "Monte-Carlo Masters views are unmatched. Access during the event is ticketed; club membership is separate from ATP hospitality.",
            venueWebsiteURL: URL(string: "https://montecarlotennismasters.com/"),
            bookingOrMembershipURL: URL(string: "https://montecarlotennismasters.com/en/tickets"),
            referralSummary: "Monte-Carlo Masters passes via official tournament channels; private club access has its own membership rules."
        ),
        IconicTennisCourt(
            id: "rome.foro",
            name: "Campo Centrale · Foro Italico",
            subtitle: "Rome · Italy",
            latitude: 41.9314,
            longitude: 12.4548,
            vibe: "Marble statues watching orange clay.",
            detail: "Italian Open combines antiquity-adjacent aesthetics with brutal clay rallies — Rome spring trips pair perfectly.",
            venueWebsiteURL: URL(string: "https://www.internazionalibnlditalia.com/"),
            bookingOrMembershipURL: URL(string: "https://www.internazionalibnlditalia.com/en/tickets"),
            referralSummary: "Internazionali BNL d’Italia tickets via the official tournament portal."
        ),
        IconicTennisCourt(
            id: "queens.ltc",
            name: "Centre Court · Queen’s Club",
            subtitle: "London · UK",
            latitude: 51.4877,
            longitude: -0.2118,
            vibe: "Grass tune-up royalty · club roots.",
            detail: "Traditional west London club atmosphere weeks before Wimbledon — hospitality sells early.",
            venueWebsiteURL: URL(string: "https://www.ltatournaments.co.uk/"),
            bookingOrMembershipURL: URL(string: "https://www.ltatournaments.co.uk/tickets"),
            referralSummary: "LTA tournament tickets through official LTA channels."
        ),
        IconicTennisCourt(
            id: "newport.hof",
            name: "International Tennis Hall of Fame",
            subtitle: "Newport · Rhode Island · USA",
            latitude: 41.4828,
            longitude: -71.3089,
            vibe: "Grass history museum meets coastal vibe.",
            detail: "Hall of Fame plus grass courts on the former Newport Casino grounds — worth the East Coast detour.",
            venueWebsiteURL: URL(string: "https://www.tennisfame.com/"),
            bookingOrMembershipURL: URL(string: "https://www.tennisfame.com/visit"),
            referralSummary: "Museum tickets & memberships via tennisfame.com."
        ),
        IconicTennisCourt(
            id: "barcelona.rctb",
            name: "Real Club de Tenis Barcelona",
            subtitle: "Barcelona · Spain",
            latitude: 41.3948,
            longitude: 2.1097,
            vibe: "Historic club hosting ATP Barcelona.",
            detail: "Tree-lined European club setting — Barcelona Open week stacks atmosphere with city tapas runs.",
            venueWebsiteURL: URL(string: "https://www.rctb1899.es/"),
            bookingOrMembershipURL: URL(string: "https://www.barcelonaopenbancsabadell.com/en"),
            referralSummary: "Barcelona Open tickets via the official tournament site; private club visits follow RCTB membership rules."
        ),
        IconicTennisCourt(
            id: "shanghai.qizhong",
            name: "Qi Zhong Tennis Center",
            subtitle: "Shanghai · China",
            latitude: 31.077,
            longitude: 121.398,
            vibe: "Retractable roof mega-campus Masters vibes.",
            detail: "Home of the Rolex Shanghai Masters — scale feels futuristic compared with cozy clay clubs.",
            venueWebsiteURL: URL(string: "https://en.rolexshanghaimasters.com/"),
            bookingOrMembershipURL: URL(string: "https://en.rolexshanghaimasters.com/tickets"),
            referralSummary: "Shanghai Masters sales cycles vary — confirm dates on the official tournament portal."
        ),
    ]

    static func court(id: String) -> IconicTennisCourt? {
        allCourts.first { $0.id == id }
    }
}