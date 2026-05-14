import SwiftUI

/// Venue sheet styled like **Shop** referrals — official links only, no fabricated codes.
struct CourtDetailView: View {
    let court: IconicTennisCourt

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
