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
                    Text(court.subtitle.uppercased())
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

                mapsActions

                if ShopCatalog.courtUnlockToShopItem[court.id] != nil {
                    courtUnlockSection
                }

                referralSection

                if court.venueWebsiteURL != nil || court.bookingOrMembershipURL != nil {
                    venueLinks
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 32)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Court")
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
                linkRow(icon: "globe.americas.fill", title: "Satellite view (Google Maps)", subtitle: "Closest web experience to “Earth” — no SDK")
            }
        }
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

            Text("Rally only surfaces legitimate venue pages — same honesty bar as the apparel shop.")
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
            Text("Venue links")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            if let url = court.venueWebsiteURL {
                Link(destination: court.trackingURL(for: url)) {
                    linkRow(icon: "safari.fill", title: "Official venue site", subtitle: "Hours, news & visitor info")
                }
            }
            if let url = court.bookingOrMembershipURL {
                Link(destination: court.trackingURL(for: url)) {
                    linkRow(icon: "ticket.fill", title: "Tickets / hospitality / membership", subtitle: "Purchase paths vary by event")
                }
            }
        }
    }
}
