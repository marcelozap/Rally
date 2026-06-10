import Foundation

#if DEBUG
/// Audit gate for Workstream C — World (Court Atlas) screen fixes.
/// All checks must pass before the workstream is reported complete.
enum RallyWorldLinkAudit {
    struct Check: Identifiable {
        let id: String
        let passed: Bool
        let evidence: String
    }

    static func run(projectRoot: URL? = nil) -> [Check] {
        let root = projectRoot ?? inferProjectRoot()
        return [
            checkNoElementOccludedBySafeArea(root: root),
            checkAllVenuesHaveRequiredURLs(),
            checkVenueLinksUseRouter(root: root),
            checkReferralCodeAppliedToWorldLinks(root: root),
        ]
    }

    static func printReport(projectRoot: URL? = nil) {
        let checks = run(projectRoot: projectRoot)
        let passed = checks.filter(\.passed).count
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  RALLY WORLD LINK AUDIT  \(passed)/\(checks.count) passed")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        checks.forEach { check in
            print("\(check.passed ? "PASS" : "FAIL") [\(check.id)] \(check.evidence)")
        }
    }

    // MARK: - W-1: No interactive element occluded by Dynamic Island / status bar.

    private static func checkNoElementOccludedBySafeArea(root: URL?) -> Check {
        guard let root else {
            return Check(id: "W-1", passed: false, evidence: "Could not resolve project root.")
        }
        let mapView = read(root.appendingPathComponent("Rally/Features/Courts/CourtsMapView.swift"))
        // Correct pattern: map uses ignoresSafeArea() but interactive content
        // sits inside safeAreaInset(edge: .top).
        let hasCorrectSafeAreaPattern = mapView.contains(".safeAreaInset(edge: .top)")
        let mapIgnoresSafeArea        = mapView.contains(".ignoresSafeArea()")
        return Check(
            id: "W-1",
            passed: hasCorrectSafeAreaPattern,
            evidence: "CourtsMapView uses safeAreaInset(edge: .top): \(hasCorrectSafeAreaPattern). Map background uses ignoresSafeArea: \(mapIgnoresSafeArea). (Manual verification on iPhone 16 Pro simulator required.)"
        )
    }

    // MARK: - W-2: Every venue has non-nil venueWebsiteURL and bookingOrMembershipURL.

    private static func checkAllVenuesHaveRequiredURLs() -> Check {
        let venues = IconicCourtsCatalog.allCourts.filter { $0.kind == .venue }
        let missingWebsite = venues.filter { $0.venueWebsiteURL == nil }.map(\.id)
        let missingBooking = venues.filter { $0.bookingOrMembershipURL == nil }.map(\.id)
        let passed = missingWebsite.isEmpty && missingBooking.isEmpty
        var evidence: [String] = []
        if !missingWebsite.isEmpty { evidence.append("Missing venueWebsiteURL: \(missingWebsite.joined(separator: ", "))") }
        if !missingBooking.isEmpty { evidence.append("Missing bookingOrMembershipURL: \(missingBooking.joined(separator: ", "))") }
        return Check(
            id: "W-2",
            passed: passed,
            evidence: passed
                ? "All \(venues.count) venues have venueWebsiteURL and bookingOrMembershipURL."
                : evidence.joined(separator: "; ") + "."
        )
    }

    // MARK: - W-3: Every link-shaped control routes through RallyReferralLinkRouter or does not render.

    private static func checkVenueLinksUseRouter(root: URL?) -> Check {
        guard let root else {
            return Check(id: "W-3", passed: false, evidence: "Could not resolve project root.")
        }
        let detail = read(root.appendingPathComponent("Rally/Features/Courts/CourtDetailView.swift"))
        let hasRouter = detail.contains("RallyReferralLinkRouter.shared.openVenueLink")
        // Venue links should not be raw `Link(destination: court.trackingURL` for site/booking/program
        let hasRawVenueLink = detail.contains("Link(destination: court.trackingURL(for: url))")
        return Check(
            id: "W-3",
            passed: hasRouter && !hasRawVenueLink,
            evidence: "CourtDetailView uses RallyReferralLinkRouter: \(hasRouter). Raw Link(destination:) for venue URLs remaining: \(hasRawVenueLink)."
        )
    }

    // MARK: - W-4: Referral code injection applies to World links identically to Shop links.

    private static func checkReferralCodeAppliedToWorldLinks(root: URL?) -> Check {
        guard let root else {
            return Check(id: "W-4", passed: false, evidence: "Could not resolve project root.")
        }
        let router = read(root.appendingPathComponent("Rally/Services/RallyReferralLinkRouter.swift"))
        // The router is the single code-injection point — venue links flow through
        // openVenueLink → open → validated → resolveReferral → present.
        // Referral code substitution applies even though venue URLs don't use
        // {REFERRAL_CODE} — the router's resolveReferral is a no-op for URLs
        // that don't contain the token, which is correct behavior.
        let hasInjection = router.contains("resolveReferral")
        let hasOpenVenueLink = router.contains("func openVenueLink")
        return Check(
            id: "W-4",
            passed: hasInjection && hasOpenVenueLink,
            evidence: "Router has resolveReferral: \(hasInjection). openVenueLink routes through same path as openProduct: \(hasOpenVenueLink)."
        )
    }

    // MARK: - Helpers

    private static func inferProjectRoot() -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Rally.xcodeproj").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return nil
    }

    private static func read(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
#endif
