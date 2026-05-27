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
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(court.kind.rawValue) · \(court.region) · \(court.subtitle)".uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.45))
                    Text(court.name)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text(court.vibe)
                        .font(.subheadline)
                        .foregroundStyle(.cyan.opacity(0.95))
                }

                Text(court.detail)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

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

    @ViewBuilder
    private var courtUnlockSection: some View {
        let alreadyUnlocked = unlocks.isUnlocked(courtID: court.id)
        let rewardItem = ShopCatalog.courtUnlockToShopItem[court.id]
            .flatMap { ShopCatalog.item(id: $0) }

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: alreadyUnlocked ? "checkmark.seal.fill" : "mappin.and.ellipse")
                    .font(.headline)
                    .foregroundStyle(alreadyUnlocked ? .green : .pink)
                Text(alreadyUnlocked ? "Tour unlock collected" : "Tour unlock available")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
            }
            if let item = rewardItem {
                Text("Reward: \(item.name) (\(item.brand))")
                    .font(.caption)
                    .foregroundStyle(.cyan.opacity(0.85))
            }

            if alreadyUnlocked {
                Text("Visible in the Shop tab. Equip it from there.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                Text("Tap **I'm here** when you're actually at the venue. Rally checks your location *once*, only while this screen is open — no background tracking. If you'd rather not share location, the unlock waits.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
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
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.pink)
                    )
                }
                .disabled(checkInController.isBusy)

                if let msg = checkInController.state.helperMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(.pink.opacity(0.9))
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.pink.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.pink.opacity(0.35)))
    }

    private var mapsActions: some View {
        VStack(spacing: 10) {
            Link(destination: court.appleMapsURL) {
                linkRow(icon: "map.fill", title: "Open in Apple Maps", subtitle: "Navigate & explore nearby")
            }
            Link(destination: court.googleMapsSatelliteURL) {
                linkRow(icon: "globe.americas.fill", title: "Satellite view (Google Maps)", subtitle: "Closest web experience to “Earth” — good for scouting the campus")
            }
        }
    }

    @ViewBuilder
    private func campProfileSection(_ profile: CampProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camp snapshot")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

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
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
    }

    private func linkRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Official booking & perks")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            if let summary = court.referralSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.cyan.opacity(0.88))
            }

            Text(court.kind == .venue
                ? "Rally only surfaces legitimate venue pages — same honesty bar as the apparel shop."
                : "Rally only surfaces official academy, camp, and host pages — no fabricated ambassador or referral codes."
            )
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.2)))
    }

    @ViewBuilder
    private var venueLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(court.kind == .venue ? "Venue links" : "Camp links")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

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
