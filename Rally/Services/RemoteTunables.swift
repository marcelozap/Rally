import Foundation

/// Live, opt-in override for a hand-picked subset of `Tunables` values.
///
/// ## Why a tiny subset
///
/// `Tunables` holds dozens of build-time constants. We don't want every one
/// of them mutable from a server — that'd make the game's feel unaudit-
/// able. The remote manifest only covers numbers we'd want to *adjust* in
/// live ops without shipping a build: match-flow BPM curves and the
/// post-combo-break recovery window.
///
/// ## Lifecycle
///
/// - Feature flag: `RemoteTunables.featureFlagDefaultsKey`. Disabled by
///   default. The app runs **offline-first** with bundled `Tunables`.
/// - When enabled, `refreshIfEnabled()` is called from `RallyApp.init` and
///   on foreground.
/// - Manifest is persisted to `UserDefaults` after every successful fetch.
///   A cold launch with no network loads the last known overrides instead
///   of falling all the way back to the bundled defaults.
///
/// ## Wire format
///
/// `GET /api/tunables` → `RemoteTunablesManifest`. Every field is
/// optional; missing fields mean "use the bundled default."
struct RemoteTunablesManifest: Codable, Equatable {
    var bpmWarmUp:    Double?
    var bpmExchange:  Double?
    var bpmPressure:  Double?
    var bpmBreaker:   Double?
    var recoverySeconds: Double?

    static let empty = RemoteTunablesManifest()
}

@MainActor
final class RemoteTunables: ObservableObject {

    static let shared = RemoteTunables()

    static let featureFlagDefaultsKey = "rally.remoteTunables.enabled"
    static let persistenceDefaultsKey = "rally.remoteTunables.cachedManifest"

    @Published private(set) var current: RemoteTunablesManifest = .empty
    @Published private(set) var lastRefreshedAt: Date?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        self.encoder = e
        // Restore last cached manifest so offline cold-launches still use
        // the most recently fetched overrides.
        if let data = UserDefaults.standard.data(forKey: Self.persistenceDefaultsKey),
           let saved = try? d.decode(RemoteTunablesManifest.self, from: data) {
            self.current = saved
        }
    }

    /// One-shot fetch. No-op when the feature flag is off. Errors swallow
    /// — the bundled `Tunables` always remain authoritative on failure.
    /// On success the manifest is persisted to `UserDefaults` so the next
    /// cold launch (even offline) starts with the last known overrides.
    func refreshIfEnabled() async {
        guard UserDefaults.standard.bool(forKey: Self.featureFlagDefaultsKey) else {
            return
        }
        let url = RallyAPIConfig.baseURL.appendingPathComponent("api/tunables")
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 4
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            let manifest = try decoder.decode(RemoteTunablesManifest.self, from: data)
            self.current = manifest
            self.lastRefreshedAt = Date()
            // Persist so offline launches start with the last good values.
            if let encoded = try? encoder.encode(manifest) {
                UserDefaults.standard.set(encoded, forKey: Self.persistenceDefaultsKey)
            }
        } catch {
            // Offline / 4xx / decode failure — keep whatever we had.
        }
    }

    // MARK: - Resolved lookups

    func bpm(for phase: MatchFlowPhase) -> Double {
        switch phase {
        case .warmUp:    return current.bpmWarmUp    ?? Tunables.MatchFlow.bpmWarmUp
        case .exchange:  return current.bpmExchange  ?? Tunables.MatchFlow.bpmExchange
        case .pressure:  return current.bpmPressure  ?? Tunables.MatchFlow.bpmPressure
        case .breaker:   return current.bpmBreaker   ?? Tunables.MatchFlow.bpmBreaker
        case .recovery:  return current.bpmExchange  ?? Tunables.MatchFlow.bpmExchange
        }
    }

    func recoverySeconds() -> TimeInterval {
        current.recoverySeconds ?? Tunables.MatchFlow.recoverySeconds
    }
}
