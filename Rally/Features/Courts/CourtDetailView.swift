import SwiftUI
import CoreLocation

/// Venue sheet styled like **Shop** referrals — official links only, no fabricated codes.
struct CourtDetailView: View {
    let court: IconicTennisCourt

    @ObservedObject private var unlocks = CourtUnlocks.shared
    @StateObject private var checkInController = CheckInState()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RallyUIKit.LuxePanel(tint: headerTint) {
                    VStack(alignment: .leading, spacing: 14) {
                        RallyUIKit.EditorialEyebrow(
                            text: "\(court.kind.rawValue) · \(court.region)",
                            tint: headerTint
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(court.name)
                                .font(RallyUIKit.Typography.display(30, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text(court.subtitle)
                                .font(RallyUIKit.Typography.body(.subheadline, weight: .semibold))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                            Text(court.vibe)
                                .font(RallyUIKit.Typography.body(.body, weight: .semibold))
                                .foregroundStyle(headerTint.opacity(0.96))
                        }

                        Text(court.detail)
                            .font(RallyUIKit.Typography.body(.body, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.frost.opacity(0.84))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                destinationFactsSection

                if let profile = court.campProfile {
                    campProfileSection(profile)
                }

                mapsActions

                if court.kind == .venue, ShopCatalog.courtUnlockToShopItem[court.id] != nil {
                    courtUnlockSection
                }

                referralSection

                if court.venueWebsiteURL != nil || court.bookingOrMembershipURL != nil || court.officialProgramURL != nil || court.sponsorHostURL != nil {
                    venueLinks
                }

                if !relatedDestinations.isEmpty {
                    relatedDestinationsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 32)
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle(court.kind == .venue ? "Venue" : "Camp")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Court unlock CTA

    private var destinationFactsSection: some View {
        RallyUIKit.SectionCard(stroke: headerTint.opacity(0.18)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    RallyUIKit.IconBadge(systemName: "sparkles.rectangle.stack.fill", tint: headerTint, size: 26)
                    Text("Destination snapshot")
                        .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    snapshotPill(title: "Type", value: court.kind.rawValue, tint: headerTint)
                    snapshotPill(title: "Region", value: court.region, tint: RallyUIKit.Palette.cyan)
                    snapshotPill(title: "Style", value: court.kind == .venue ? "Watch / visit" : "Train / stay", tint: RallyUIKit.Palette.gold)
                    snapshotPill(title: "Links", value: "Official only", tint: RallyUIKit.Palette.rose)
                }
            }
        }
    }

    @ViewBuilder
    private var courtUnlockSection: some View {
        let alreadyUnlocked = unlocks.isUnlocked(courtID: court.id)
        let rewardItem = ShopCatalog.courtUnlockToShopItem[court.id]
            .flatMap { ShopCatalog.item(id: $0) }

        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.rose) {
            VStack(alignment: .leading, spacing: 14) {
                RallyUIKit.EditorialEyebrow(
                    text: alreadyUnlocked ? "Tour unlock collected" : "Tour unlock available",
                    tint: RallyUIKit.Palette.rose
                )

                HStack(alignment: .top, spacing: 12) {
                    RallyUIKit.IconBadge(
                        systemName: alreadyUnlocked ? "checkmark.seal.fill" : "mappin.and.ellipse",
                        tint: alreadyUnlocked ? RallyUIKit.Palette.lime : RallyUIKit.Palette.rose,
                        size: 34
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(alreadyUnlocked ? "You’ve already earned this venue reward." : "Check in on-site to unlock a venue reward.")
                            .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)

                        if let item = rewardItem {
                            Text("\(item.name) · \(item.brand)")
                                .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                                .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.9))
                        }
                    }
                }

                if alreadyUnlocked {
                    Text("The reward is ready in the Shop tab whenever you want to equip it.")
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.64))
                } else {
                    Text("Tap **I’m here** only when you’re actually at the venue. Rally checks location once while this page is open, with no background tracking.")
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.64))

                    Button {
                        checkInController.start(court: court)
                    } label: {
                        HStack(spacing: 8) {
                            if case .verifying = checkInController.state {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text(checkInController.state.buttonTitle)
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.rose))
                    .disabled(checkInController.isBusy)

                    if let msg = checkInController.state.helperMessage {
                        Text(msg)
                            .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.rose.opacity(0.92))
                    }
                }
            }
        }
    }

    private var mapsActions: some View {
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.cyan.opacity(0.18)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    RallyUIKit.IconBadge(systemName: "location.viewfinder", tint: RallyUIKit.Palette.cyan, size: 26)
                    Text("Explore and navigate")
                        .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                }

                Link(destination: court.appleMapsURL) {
                    linkRow(icon: "map.fill", title: "Open in Apple Maps", subtitle: "Navigate & explore nearby")
                }
                Link(destination: court.googleMapsSatelliteURL) {
                    linkRow(icon: "globe.americas.fill", title: "Satellite view (Google Maps)", subtitle: "Closest web experience to “Earth” — good for scouting the campus")
                }
            }
        }
    }

    @ViewBuilder
    private func campProfileSection(_ profile: CampProfile) -> some View {
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.gold.opacity(0.18)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    RallyUIKit.IconBadge(systemName: "figure.tennis", tint: RallyUIKit.Palette.gold, size: 28)
                    Text("Camp snapshot")
                        .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                }

                flowFactPills([
                    ("Audience", profile.audience, RallyUIKit.Palette.cyan),
                    ("Best for", profile.bestFor, RallyUIKit.Palette.lime),
                    ("Stay", profile.stayStyle, RallyUIKit.Palette.gold)
                ])

                factPanel(
                    title: "Training focus",
                    body: profile.programFocus,
                    icon: "scope",
                    tint: RallyUIKit.Palette.rose
                )

                factPanel(
                    title: "Surface mix",
                    body: profile.surfaceMix,
                    icon: "square.grid.3x3.middle.filled",
                    tint: RallyUIKit.Palette.cyan
                )
            }
        }
    }

    private func linkRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            RallyUIKit.IconBadge(systemName: icon, tint: headerTint, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(subtitle)
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.5))
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.34))
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
    }

    private func flowFactPills(_ facts: [(String, String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 4) {
                    Text(fact.0.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.45))
                    Text(fact.1)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(fact.2.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(fact.2.opacity(0.28), lineWidth: 1)
                        )
                }
            }
        }
    }

    private func factPanel(title: String, body: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RallyUIKit.IconBadge(systemName: icon, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// SwiftUI-friendly wrapper over `CourtCheckIn`. Keeps the
    /// `CLLocationManager` lifetime tied to the screen instance via
    /// `@StateObject`, so dismissing the sheet ends the location request.
    @MainActor
    final class CheckInState: ObservableObject {
        enum Phase {
            case idle
            case verifying
            case success
            case denied
            case tooFar(meters: Double)
            case lowAccuracy
            case unavailable

            var buttonTitle: String {
                switch self {
                case .idle:        return "I'm here"
                case .verifying:   return "Checking location…"
                case .success:     return "Unlocked"
                case .denied:      return "Location permission denied"
                case .tooFar:      return "Try again at the venue"
                case .lowAccuracy: return "Signal too noisy — retry"
                case .unavailable: return "Location unavailable"
                }
            }

            var helperMessage: String? {
                switch self {
                case .idle, .verifying, .success: return nil
                case .denied: return "Enable Location → While Using App in Settings to unlock."
                case .tooFar(let m): return "You're \(Int(m))m from the pin. Move closer and retry."
                case .lowAccuracy: return "GPS accuracy was too low. Step outside and retry."
                case .unavailable: return "Couldn't reach location services."
                }
            }
        }

        @Published var state: Phase = .idle
        var isBusy: Bool {
            if case .verifying = state { return true }
            return false
        }

        private let verifier = CourtCheckIn()

        func start(court: IconicTennisCourt) {
            state = .verifying
            verifier.verify(against: court.coordinate) { [weak self] outcome in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch outcome {
                    case .unlocked:
                        CourtUnlocks.shared.unlock(courtID: court.id)
                        self.state = .success
                    case .denied:
                        self.state = .denied
                    case .tooFar(let d):
                        self.state = .tooFar(meters: d)
                    case .lowAccuracy:
                        self.state = .lowAccuracy
                    case .unavailable:
                        self.state = .unavailable
                    }
                }
            }
        }
    }

    private var referralSection: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.rose) {
            VStack(alignment: .leading, spacing: 12) {
                RallyUIKit.EditorialEyebrow(text: "Official booking & perks", tint: RallyUIKit.Palette.rose)

                if let summary = court.referralSummary {
                    Text(summary)
                        .font(RallyUIKit.Typography.body(.body, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.88))
                }

                Text(court.kind == .venue
                    ? "Rally only surfaces legitimate venue pages — same honesty bar as the apparel shop."
                    : "Rally only surfaces official academy, camp, and host pages — no fabricated ambassador or referral codes."
                )
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.5))
            }
        }
    }

    private var relatedDestinations: [IconicTennisCourt] {
        let sameKind = IconicCourtsCatalog.allCourts.filter {
            $0.id != court.id && $0.kind == court.kind && $0.region == court.region
        }
        let sameRegion = IconicCourtsCatalog.allCourts.filter {
            $0.id != court.id && $0.kind == court.kind && $0.region != court.region
        }
        let alternates = IconicCourtsCatalog.allCourts.filter {
            $0.id != court.id && $0.kind != court.kind
        }

        let ordered = sameKind + sameRegion + alternates
        var seen = Set<String>()
        return ordered.filter { seen.insert($0.id).inserted }.prefix(3).map { $0 }
    }

    private var relatedDestinationsSection: some View {
        RallyUIKit.SectionCard(stroke: headerTint.opacity(0.18)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    RallyUIKit.IconBadge(systemName: "globe.europe.africa.fill", tint: headerTint, size: 26)
                    Text("Keep exploring")
                        .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                }

                Text(court.kind == .venue
                    ? "More official tennis destinations nearby in spirit, region, or travel fit."
                    : "More official camps and venues to pair with this training stop."
                )
                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.7))

                VStack(spacing: 10) {
                    ForEach(relatedDestinations) { destination in
                        NavigationLink {
                            CourtDetailView(court: destination)
                        } label: {
                            relatedDestinationRow(destination)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func relatedDestinationRow(_ destination: IconicTennisCourt) -> some View {
        HStack(spacing: 12) {
            RallyUIKit.IconBadge(
                systemName: destination.kind == .venue ? "mappin.and.ellipse" : "figure.tennis",
                tint: destination.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold,
                size: 32
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(destination.name)
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        .lineLimit(2)
                    atlasMiniTag(destination.kind.rawValue, tint: destination.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold)
                }

                Text(destination.subtitle)
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.7))

                HStack(spacing: 8) {
                    atlasMiniTag(destination.region, tint: headerTint)
                    atlasMiniTag("Official links", tint: RallyUIKit.Palette.rose)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.42))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
    }

    @ViewBuilder
    private var venueLinks: some View {
        RallyUIKit.SectionCard(stroke: headerTint.opacity(0.2)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    RallyUIKit.IconBadge(systemName: "arrow.up.right.square", tint: headerTint, size: 26)
                    Text(court.kind == .venue ? "Official actions" : "Official actions")
                        .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                }

                HStack(spacing: 8) {
                    actionAvailabilityTag("Site", available: court.venueWebsiteURL != nil, tint: headerTint)
                    actionAvailabilityTag(court.kind == .venue ? "Booking" : "Enrollment", available: court.bookingOrMembershipURL != nil, tint: RallyUIKit.Palette.rose)
                    if court.officialProgramURL != nil {
                        actionAvailabilityTag("Program", available: true, tint: RallyUIKit.Palette.gold)
                    }
                    if court.sponsorHostURL != nil, court.sponsorHostName != nil {
                        actionAvailabilityTag("Host", available: true, tint: RallyUIKit.Palette.cyan)
                    }
                }

                if let url = court.venueWebsiteURL {
                    Link(destination: court.trackingURL(for: url)) {
                        linkRow(
                            icon: court.kind == .venue ? "safari.fill" : "building.columns.fill",
                            title: court.kind == .venue ? "Official venue site" : "Official academy site",
                            subtitle: court.kind == .venue ? "Hours, news & visitor info" : "Campus overview, coaching philosophy, and contact info"
                        )
                    }
                }
                if let url = court.bookingOrMembershipURL {
                    Link(destination: court.trackingURL(for: url)) {
                        linkRow(
                            icon: court.kind == .venue ? "ticket.fill" : "person.crop.rectangle.badge.plus",
                            title: court.kind == .venue ? "Tickets / hospitality / membership" : "Official enrollment / booking",
                            subtitle: court.kind == .venue ? "Purchase paths vary by event" : "Register through the academy or camp operator"
                        )
                    }
                }
                if let url = court.officialProgramURL {
                    Link(destination: court.trackingURL(for: url)) {
                        linkRow(icon: "figure.tennis", title: "Featured program page", subtitle: "Training format, session type, and camp specifics")
                    }
                }
                if let url = court.sponsorHostURL, let name = court.sponsorHostName {
                    Link(destination: court.trackingURL(for: url)) {
                        linkRow(icon: "rosette", title: "Official host / sponsor", subtitle: name)
                    }
                }
            }
        }
    }

    private func actionAvailabilityTag(_ label: String, available: Bool, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: available ? "checkmark.circle.fill" : "minus.circle")
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
        }
        .foregroundStyle(available ? tint : RallyUIKit.Palette.cloud.opacity(0.45))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule().fill((available ? tint : RallyUIKit.Palette.cloud).opacity(available ? 0.11 : 0.08))
        )
        .overlay(
            Capsule().stroke((available ? tint : RallyUIKit.Palette.cloud).opacity(available ? 0.18 : 0.1), lineWidth: 1)
        )
    }

    private func snapshotPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.46))
            Text(value)
                .font(RallyUIKit.Typography.body(.subheadline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tint.opacity(0.11))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tint.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private func atlasMiniTag(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    private var headerTint: Color {
        court.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold
    }
}
