import Foundation
import SafariServices
import UIKit

/// Central router for every outbound product and venue link in Rally.
///
/// **Why a router?**
/// Raw `Link(destination:)` or `openURL` calls scattered through Shop and
/// Court views make it impossible to enforce consistent UTM tagging,
/// referral-code injection, and URL validation. This class is the single
/// gateway: every tap that opens an external URL in Rally must come through
/// `RallyReferralLinkRouter.shared.open(...)`.
///
/// **Referral code injection**
/// Vendor URLs in the catalog contain the literal token `{REFERRAL_CODE}`.
/// The router substitutes the current code (from `UserDefaults` or a
/// compile-time fallback) before opening. In production, the marketing
/// team sets this via remote config; in development it defaults to `"rally"`.
///
/// **Failure contract**
/// - nil or malformed URL → `assertionFailure` in DEBUG builds; no-op in
///   Release. The caller is responsible for disabling UI controls that
///   would invoke a nil URL.

// MARK: - Referral Code Injection

/// Pure string helpers — nonisolated so they can be called from sync audit code.
extension RallyReferralLinkRouter {
    nonisolated static func resolveReferralStatic(in urlString: String) -> URL? {
        let injected = urlString.replacingOccurrences(
            of: "{REFERRAL_CODE}",
            with: currentReferralCode
        )
        return URL(string: injected)
    }
}

extension RallyReferralLinkRouter {
    private static let referralCodeDefaultsKey = "rally.referral.code"
    nonisolated static let fallbackCode = "rally"

    nonisolated static var currentReferralCode: String {
        UserDefaults.standard.string(forKey: referralCodeDefaultsKey) ?? fallbackCode
    }

    /// Substitutes `{REFERRAL_CODE}` in any URL string and returns the
    /// resolved URL, or `nil` if the string was never a valid URL.
    nonisolated func resolveReferral(in urlString: String) -> URL? {
        let injected = urlString.replacingOccurrences(
            of: "{REFERRAL_CODE}",
            with: Self.currentReferralCode
        )
        return URL(string: injected)
    }

    /// Convenience: resolve referral code in an already-parsed `URL`.
    nonisolated func resolveReferral(in url: URL) -> URL? {
        resolveReferral(in: url.absoluteString)
    }
}

// MARK: - URL Validation

extension RallyReferralLinkRouter {
    /// Returns `true` when `url` is a valid HTTPS URL after referral
    /// substitution. Used by UI to decide whether to render a link button.
    func isReachable(_ url: URL?) -> Bool {
        guard let url else { return false }
        let resolved = resolveReferral(in: url) ?? url
        return resolved.scheme == "https" && resolved.host != nil
    }

    /// Validates `url` and traps in DEBUG if it is nil or malformed.
    /// Returns the resolved URL ready for presentation, or `nil` in Release
    /// if validation fails.
    private func validated(_ url: URL?, context: String) -> URL? {
        guard let url else {
            assertionFailure("RallyReferralLinkRouter: nil URL in \(context)")
            return nil
        }
        guard let resolved = resolveReferral(in: url),
              resolved.scheme == "https",
              resolved.host != nil else {
            assertionFailure("RallyReferralLinkRouter: invalid URL '\(url)' in \(context)")
            return nil
        }
        return resolved
    }
}

// MARK: - Presentation

@MainActor
final class RallyReferralLinkRouter {
    static let shared = RallyReferralLinkRouter()
    private init() {}

    /// Opens `url` in an in-app `SFSafariViewController`.
    /// Injects the referral code, validates, and presents.
    /// Silently no-ops in Release on validation failure.
    func open(_ url: URL?, context: String = "unknown") {
        guard let resolved = validated(url, context: context) else { return }
        #if DEBUG
        print("[RallyReferralLinkRouter] Opening \(context) → \(resolved.absoluteString)")
        #endif
        present(resolved)
    }

    /// Opens a `RallyGearItem`'s referral URL. The preferred entry point
    /// from Shop product cards.
    func openProduct(_ item: RallyGearItem) {
        open(item.referralURL, context: "product:\(item.id)")
    }

    /// Opens a venue/court link. Used by `CourtDetailView`.
    func openVenueLink(_ url: URL?, venueName: String) {
        open(url, context: "venue:\(venueName)")
    }

    private func present(_ url: URL) {
        let safari = SFSafariViewController(url: url)
        safari.preferredBarTintColor = UIColor(red: 0.055, green: 0.063, blue: 0.082, alpha: 1)
        safari.preferredControlTintColor = UIColor(red: 0, green: 0.753, blue: 0.82, alpha: 1) // cyan
        safari.dismissButtonStyle = .close

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            // Fallback: open in default browser if no presenting VC available.
            UIApplication.shared.open(url)
            return
        }
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(safari, animated: true)
    }
}
