import CoreLocation
import Foundation

/// Curated iconic tennis venues for the **Court atlas** map. Data is static (like
/// `ShopCatalog`) — only tennis-specific pins appear on the map.
enum AtlasDestinationKind: String, Hashable {
    case venue = "Venue"
    case academy = "Camp"
}

struct CampProfile: Hashable {
    let audience: String
    let programFocus: String
    let surfaceMix: String
    let bestFor: String
    let stayStyle: String
    let bestForTag: BestForTag
}

enum BestForTag: String, CaseIterable, Hashable, Identifiable {
    case allAround = "All-around growth"
    case juniors = "Junior pathway"
    case intensive = "Intensive blocks"
    case travel = "Travel training"
    case flexible = "Flexible local training"
    case surfaces = "Surface variety"

    var id: String { rawValue }
}

struct IconicTennisCourt: Identifiable, Hashable {
    let id: String
    let kind: AtlasDestinationKind
    let name: String
    /// City · Country
    let subtitle: String
    /// Region or continent tag for travel context.
    let region: String
    let latitude: Double
    let longitude: Double
    /// One-line hook for the card.
    let vibe: String
    /// Longer copy for the detail screen.
    let detail: String
    /// Official venue / tournament site — opens in Safari (tagged like shop URLs).
    let venueWebsiteURL: URL?
    /// Booking, hospitality, camp enrollment, or official membership portal when applicable.
    let bookingOrMembershipURL: URL?
    /// Dedicated program / camp page when different from the main site.
    let officialProgramURL: URL?
    /// Host, sponsor, or campus partner surfaced only when clearly official.
    let sponsorHostName: String?
    let sponsorHostURL: URL?
    let campProfile: CampProfile?
    /// Same spirit as `Vendor.referralSummary`: points users to **official** channels only.
    let referralSummary: String?

    init(
        id: String,
        kind: AtlasDestinationKind = .venue,
        name: String,
        subtitle: String,
        region: String,
        latitude: Double,
        longitude: Double,
        vibe: String,
        detail: String,
        venueWebsiteURL: URL?,
        bookingOrMembershipURL: URL?,
        officialProgramURL: URL? = nil,
        sponsorHostName: String? = nil,
        sponsorHostURL: URL? = nil,
        campProfile: CampProfile? = nil,
        referralSummary: String?
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.subtitle = subtitle
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
        self.vibe = vibe
        self.detail = detail
        self.venueWebsiteURL = venueWebsiteURL
        self.bookingOrMembershipURL = bookingOrMembershipURL
        self.officialProgramURL = officialProgramURL
        self.sponsorHostName = sponsorHostName
        self.sponsorHostURL = sponsorHostURL
        self.campProfile = campProfile
        self.referralSummary = referralSummary
    }

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
    static let iconicVenues: [IconicTennisCourt] = [
        IconicTennisCourt(
            id: "wimbledon.cc",
            name: "Centre Court · Wimbledon",
            subtitle: "London · UK",
            region: "Europe",
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
            region: "Europe",
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
            region: "North America",
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
            region: "Oceania",
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
            region: "North America",
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
            region: "Europe",
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
            region: "Europe",
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
            region: "Europe",
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
            region: "North America",
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
            region: "Europe",
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
            region: "Asia",
            latitude: 31.077,
            longitude: 121.398,
            vibe: "Retractable roof mega-campus Masters vibes.",
            detail: "Home of the Rolex Shanghai Masters — scale feels futuristic compared with cozy clay clubs.",
            venueWebsiteURL: URL(string: "https://en.rolexshanghaimasters.com/"),
            bookingOrMembershipURL: URL(string: "https://en.rolexshanghaimasters.com/tickets"),
            referralSummary: "Shanghai Masters sales cycles vary — confirm dates on the official tournament portal."
        ),
    ]

    static let trainingCamps: [IconicTennisCourt] = [
        IconicTennisCourt(
            id: "rna.mallorca",
            kind: .academy,
            name: "Rafa Nadal Academy",
            subtitle: "Manacor · Spain",
            region: "Europe",
            latitude: 39.5696,
            longitude: 3.2092,
            vibe: "Mallorca flagship campus with Rafa’s methodology.",
            detail: "The academy’s official site highlights junior and adult camps built around the training system developed with Rafa Nadal’s team, plus the broader campus environment in Manacor.",
            venueWebsiteURL: URL(string: "https://www.rafanadalacademy.com/"),
            bookingOrMembershipURL: URL(string: "https://www.rafanadalacademy.com/en/tennis-camps"),
            sponsorHostName: "Rafa Nadal Academy by Movistar",
            sponsorHostURL: URL(string: "https://www.rafanadalacademy.com/"),
            campProfile: CampProfile(
                audience: "Juniors and adults",
                programFocus: "Rafa methodology, technical-tactical-physical-mental development",
                surfaceMix: "Full academy campus",
                bestFor: "Players wanting a flagship European academy stay",
                stayStyle: "Camp pathways plus academy environment",
                bestForTag: .allAround
            ),
            referralSummary: "Use the official academy camp pages for registration and availability. Rally does not invent discount or ambassador codes."
        ),
        IconicTennisCourt(
            id: "mouratoglou.fr",
            kind: .academy,
            name: "Mouratoglou Academy",
            subtitle: "Biot · France",
            region: "Europe",
            latitude: 43.6158,
            longitude: 7.0715,
            vibe: "Côte d’Azur high-performance campus with boarding and camp options.",
            detail: "The official camp page positions Mouratoglou as a tennis-focused resort and academy environment in Sophia Antipolis, with camp formats for juniors and adults.",
            venueWebsiteURL: URL(string: "https://www.mouratoglou.com/en/"),
            bookingOrMembershipURL: URL(string: "https://www.mouratoglou.com/en/tennis-camps/"),
            sponsorHostName: "Mouratoglou Hotel & Resort",
            sponsorHostURL: URL(string: "https://www.mouratoglou.com/en/"),
            campProfile: CampProfile(
                audience: "Juniors and adults",
                programFocus: "Camp blocks, boarding pathways, tennis-resort training",
                surfaceMix: "High-performance academy courts",
                bestFor: "Players who want an academy plus resort setting",
                stayStyle: "Camp weeks and residential options",
                bestForTag: .travel
            ),
            referralSummary: "Book camps through Mouratoglou’s official camp pages to verify session type, accommodation, and language-program availability."
        ),
        IconicTennisCourt(
            id: "img.bradenton",
            kind: .academy,
            name: "IMG Academy Tennis",
            subtitle: "Bradenton · Florida · USA",
            region: "North America",
            latitude: 27.4497,
            longitude: -82.6094,
            vibe: "Big-campus U.S. training hub with year-round camps.",
            detail: "IMG’s official tennis camp pages emphasize year-round programming, multiple camp formats, and an expansive multi-surface facility in Bradenton.",
            venueWebsiteURL: URL(string: "https://www.imgacademy.com/boarding-school/tennis"),
            bookingOrMembershipURL: URL(string: "https://www.imgacademy.com/sport-camps/tennis-camp"),
            sponsorHostName: "IMG Legacy Hotel",
            sponsorHostURL: URL(string: "https://www.imgacademy.com/events/venues/img-academy-tennis-courts-pro-shop"),
            campProfile: CampProfile(
                audience: "Ages 8-18",
                programFocus: "Year-round customizable camp tracks and performance training",
                surfaceMix: "Hard, clay, indoor, and stadium courts",
                bestFor: "Families looking for a broad U.S. boarding-camp ecosystem",
                stayStyle: "Boarding and non-boarding weekly camp options",
                bestForTag: .juniors
            ),
            referralSummary: "Use IMG’s official camp booking flow for dates, boarding, and age-specific availability."
        ),
        IconicTennisCourt(
            id: "ferrero.villena",
            kind: .academy,
            name: "Ferrero Tennis Academy",
            subtitle: "Villena · Spain",
            region: "Europe",
            latitude: 38.6355,
            longitude: -0.8658,
            vibe: "Train-like-a-pro short-stay campus tied to the Ferrero system.",
            detail: "Ferrero’s official short-stay and summer-stage pages describe intensive tennis, physical, and mental training with on-site lodging and multi-week options.",
            venueWebsiteURL: URL(string: "https://www.equelite.com/"),
            bookingOrMembershipURL: URL(string: "https://www.equelite.com/competicion-corta-estancia/"),
            officialProgramURL: URL(string: "https://www.equelite.com/summer-stage/"),
            sponsorHostName: "Equelite",
            sponsorHostURL: URL(string: "https://www.equelite.com/"),
            campProfile: CampProfile(
                audience: "Competitive juniors and serious improvers",
                programFocus: "Short-stay competition training and summer-stage weeks",
                surfaceMix: "Academy training base with on-site performance support",
                bestFor: "Players chasing an intensive Spain-based pro-style block",
                stayStyle: "Weekly or multi-week residential stays",
                bestForTag: .intensive
            ),
            referralSummary: "Ferrero’s official pages include the current short-stay and summer-stage enrollment details; rely on those rather than third-party camp resellers."
        ),
        IconicTennisCourt(
            id: "evert.bocaraton",
            kind: .academy,
            name: "Evert Tennis Academy",
            subtitle: "Boca Raton · Florida · USA",
            region: "North America",
            latitude: 26.3208,
            longitude: -80.2147,
            vibe: "Legacy U.S. academy with year-round camp and school pathways.",
            detail: "Evert’s official site presents holiday, weekly, and summer camp options, plus training-and-academics pathways on the Boca Raton campus.",
            venueWebsiteURL: URL(string: "https://evertacademy.com/"),
            bookingOrMembershipURL: URL(string: "https://evertacademy.com/tennis-camps/"),
            officialProgramURL: URL(string: "https://www.evertacademy.com/tennis-camps/weekly-pre-tournament-tennis-camps"),
            sponsorHostName: "Evert Tennis Academy",
            sponsorHostURL: URL(string: "https://evertacademy.com/about-us/"),
            campProfile: CampProfile(
                audience: "Competitive juniors",
                programFocus: "Weekly, pre-tournament, holiday, and summer camp options",
                surfaceMix: "Large Boca Raton academy campus",
                bestFor: "Players wanting a structured Florida junior pathway",
                stayStyle: "Boarding and non-boarding camp formats",
                bestForTag: .juniors
            ),
            referralSummary: "The official Evert camp pages are the safest source for session formats, boarding details, and registration forms."
        ),
        IconicTennisCourt(
            id: "tennis360.dubai",
            kind: .academy,
            name: "Tennis 360 · Meydan Tennis Academy",
            subtitle: "Dubai · UAE",
            region: "Middle East",
            latitude: 25.1637,
            longitude: 55.3015,
            vibe: "Dubai multi-location coaching hub with academy and clinic pathways.",
            detail: "Tennis 360’s official Dubai site outlines coaching programs, development squads, advanced clinics, and the Meydan Tennis Academy base.",
            venueWebsiteURL: URL(string: "https://www.tennisthreesixty.com/"),
            bookingOrMembershipURL: URL(string: "https://www.tennisthreesixty.com/tennis-dubai/"),
            officialProgramURL: URL(string: "https://www.tennisthreesixty.com/program/advanced-clinic/"),
            sponsorHostName: "Meydan Tennis Academy",
            sponsorHostURL: URL(string: "https://www.tennisthreesixty.com/locations-facilities/meydan-tennis-club/"),
            campProfile: CampProfile(
                audience: "Kids, adults, and club-level competitors",
                programFocus: "Academy coaching, development squads, clinics, and trials",
                surfaceMix: "Dubai multi-location hard-court network",
                bestFor: "Travelers or residents wanting flexible Dubai training blocks",
                stayStyle: "Mostly local-program and trial-session style",
                bestForTag: .flexible
            ),
            referralSummary: "Use Tennis 360’s official academy and program pages for trial lessons, clinics, and Dubai location details."
        ),
        IconicTennisCourt(
            id: "rvta.potchefstroom",
            kind: .academy,
            name: "Riaan Venter Tennis Academy",
            subtitle: "Potchefstroom · South Africa",
            region: "Africa",
            latitude: -26.7168,
            longitude: 27.0980,
            vibe: "South African academy with clay, hard, and grass training base.",
            detail: "RVTA’s official site describes its North-West University partnership and highlights training access across three surfaces in Potchefstroom.",
            venueWebsiteURL: URL(string: "https://www.rvta.co.za/"),
            bookingOrMembershipURL: URL(string: "https://www.rvta.co.za/"),
            sponsorHostName: "North-West University Potchefstroom",
            sponsorHostURL: URL(string: "https://www.rvta.co.za/"),
            campProfile: CampProfile(
                audience: "High-performance players",
                programFocus: "International-scene preparation and full-time development",
                surfaceMix: "Italian red clay, hard, and grass",
                bestFor: "Players prioritizing surface variety and South African competition prep",
                stayStyle: "Academy-base development with residential support",
                bestForTag: .surfaces
            ),
            referralSummary: "Contact RVTA through the official academy site for program fit, intake, and university-linked training logistics."
        ),
        IconicTennisCourt(
            id: "rna.costamujeres",
            kind: .academy,
            name: "Rafa Nadal Tennis Center Costa Mujeres",
            subtitle: "Costa Mujeres · Mexico",
            region: "Latin America",
            latitude: 21.2054,
            longitude: -86.8035,
            vibe: "Resort-linked Nadal methodology camp experience in the Caribbean.",
            detail: "The official Costa Mujeres camp pages describe adult and junior programs built around the Rafa Nadal Academy methodology, delivered as international camp experiences.",
            venueWebsiteURL: URL(string: "https://camps.rafanadalacademy.com/en/"),
            bookingOrMembershipURL: URL(string: "https://camps.rafanadalacademy.com/en/programs/adult-programs/"),
            officialProgramURL: URL(string: "https://camps.rafanadalacademy.com/en/programs/juniors-programs/"),
            sponsorHostName: "Rafa Nadal Tennis Center Costa Mujeres",
            sponsorHostURL: URL(string: "https://camps.rafanadalacademy.com/en/about-us/"),
            campProfile: CampProfile(
                audience: "Juniors and adults",
                programFocus: "International camps based on Rafa Nadal Academy methodology",
                surfaceMix: "Resort-linked tennis center",
                bestFor: "Players combining tennis training with destination travel",
                stayStyle: "Camp-style destination stay",
                bestForTag: .travel
            ),
            referralSummary: "Use the official Rafa Nadal Tennis Center camp pages for Costa Mujeres program enrollment and methodology details."
        ),
    ]

    /// Historical name kept so existing views continue to compile while the
    /// atlas expands beyond just match venues.
    static let allCourts: [IconicTennisCourt] = iconicVenues + trainingCamps

    static func court(id: String) -> IconicTennisCourt? {
        allCourts.first { $0.id == id }
    }
}
