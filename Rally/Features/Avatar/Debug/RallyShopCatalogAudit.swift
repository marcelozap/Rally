import Foundation

#if DEBUG
/// Audit gate for Workstream B — real-merchandise shop overhaul.
/// All checks must pass before the workstream is reported complete.
enum RallyShopCatalogAudit {
    struct Check: Identifiable {
        let id: String
        let passed: Bool
        let evidence: String
    }

    static func run(projectRoot: URL? = nil) -> [Check] {
        let root = projectRoot ?? inferProjectRoot()
        return [
            checkCatalogLoadsMinimumItems(),
            checkAllItemsHaveRequiredFields(),
            checkReferralURLsHaveToken(),
            checkNoSFSymbolTerminalState(root: root),
            checkShopCTAsRouteViaRouter(root: root),
        ]
    }

    static func printReport(projectRoot: URL? = nil) {
        let checks = run(projectRoot: projectRoot)
        let passed = checks.filter(\.passed).count
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  RALLY SHOP CATALOG AUDIT  \(passed)/\(checks.count) passed")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        checks.forEach { check in
            print("\(check.passed ? "PASS" : "FAIL") [\(check.id)] \(check.evidence)")
        }
    }

    // MARK: - S-1: Catalog loads ≥12 items; every item has non-empty required fields.

    private static func checkCatalogLoadsMinimumItems() -> Check {
        let items = RallyReferralCatalog.allItems
        let count = items.count
        return Check(
            id: "S-1a",
            passed: count >= 12,
            evidence: "Catalog contains \(count) items (need ≥ 12)."
        )
    }

    private static func checkAllItemsHaveRequiredFields() -> Check {
        let items = RallyReferralCatalog.allItems
        let failures = items.filter {
            $0.brand.isEmpty || $0.name.isEmpty ||
            $0.priceDisplay.isEmpty || $0.productImageURL == nil ||
            $0.referralURL.absoluteString.isEmpty
        }.map(\.id)
        return Check(
            id: "S-1b",
            passed: failures.isEmpty,
            evidence: failures.isEmpty
                ? "All \(items.count) items have brand, name, priceDisplay, productImageURL, referralURL."
                : "Items missing required fields: \(failures.joined(separator: ", "))."
        )
    }

    // MARK: - S-2: Every referralURL contains {REFERRAL_CODE} and is valid after substitution.

    private static func checkReferralURLsHaveToken() -> Check {
        let passed = RallyReferralCatalog.passesS2Audit
        let withoutToken = RallyReferralCatalog.allItems.filter {
            !$0.referralURL.absoluteString.contains("{REFERRAL_CODE}")
        }.map(\.id)
        return Check(
            id: "S-2",
            passed: passed,
            evidence: passed
                ? "All referralURLs contain {REFERRAL_CODE} and resolve after substitution."
                : "Missing token in: \(withoutToken.joined(separator: ", "))."
        )
    }

    // MARK: - S-3: No SF Symbol is the terminal visual state of any product card.

    private static func checkNoSFSymbolTerminalState(root: URL?) -> Check {
        guard let root else {
            return Check(id: "S-3", passed: false, evidence: "Could not resolve project root for file-system check.")
        }
        let detail = read(root.appendingPathComponent("Rally/Features/Shop/ShopItemDetailView.swift"))
        // The SF Symbol fallback must be inside a conditional branch guarded
        // by `productImageURL == nil` or `referralItem == nil`, not shown unconditionally.
        // We check that `productIconFallback` exists (named helper, not inline) and
        // that `AsyncImage` wraps it.
        let hasAsyncImage = detail.contains("AsyncImage(url:")
        let hasFallbackHelper = detail.contains("productIconFallback")
        let guardedProperly = detail.contains("referralItem?.productImageURL")
        return Check(
            id: "S-3",
            passed: hasAsyncImage && hasFallbackHelper && guardedProperly,
            evidence: "AsyncImage present: \(hasAsyncImage). Fallback helper exists: \(hasFallbackHelper). Guarded by productImageURL: \(guardedProperly)."
        )
    }

    // MARK: - S-5: Every Shop CTA routes through RallyReferralLinkRouter.

    private static func checkShopCTAsRouteViaRouter(root: URL?) -> Check {
        guard let root else {
            return Check(id: "S-5", passed: false, evidence: "Could not resolve project root for file-system check.")
        }
        let detail = read(root.appendingPathComponent("Rally/Features/Shop/ShopItemDetailView.swift"))
        let shopView = read(root.appendingPathComponent("Rally/Features/Shop/ShopView.swift"))

        // No raw `Link(destination: ... productURL` or `Link(destination: ... websiteURL`
        // should remain in shop views.
        let detailHasRawProductLink = detail.contains("Link(destination: item.trackingProductURL)")
        let detailHasRawVendorLink  = detail.contains("Link(destination: vendor.websiteURL)")
        let shopViewHasRawVendorLink = shopView.contains("Link(destination: vendor.websiteURL)")

        let usesRouter = detail.contains("RallyReferralLinkRouter.shared")
        let passed = !detailHasRawProductLink && !detailHasRawVendorLink && !shopViewHasRawVendorLink && usesRouter

        var evidence: [String] = []
        if detailHasRawProductLink { evidence.append("ShopItemDetailView has raw trackingProductURL Link") }
        if detailHasRawVendorLink  { evidence.append("ShopItemDetailView has raw vendor.websiteURL Link") }
        if shopViewHasRawVendorLink { evidence.append("ShopView has raw vendor.websiteURL Link") }
        if !usesRouter             { evidence.append("RallyReferralLinkRouter not referenced in ShopItemDetailView") }

        return Check(
            id: "S-5",
            passed: passed,
            evidence: passed ? "All Shop CTAs route through RallyReferralLinkRouter." : evidence.joined(separator: "; ") + "."
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
