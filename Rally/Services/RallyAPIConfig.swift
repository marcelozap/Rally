import Foundation

enum UserDefaultsKeys {
    static let savedEmail = "rally.savedEmail"
    /// Persisted **Continue offline** choice until sign-in clears it.
    static let guestMode = "rally.guestMode"
    /// Master mute for music + SFX. Defaults to `false` (muted) on first launch.
    static let soundEnabled = "rally.soundEnabled"
    static let gameDominantHand = "rally.gameDominantHand"
    static let gameShowCoachingCues = "rally.gameShowCoachingCues"
    static let gameHapticsEnabled = "rally.gameHapticsEnabled"
    static let gameMatchPace = "rally.gameMatchPace"
}

enum RallyAPIConfig {
    /// Simulator default; override with UserDefaults (`baseURLKey`) or Auth → Developer.
    private static let developmentDefault = "http://127.0.0.1:8787"

    static let baseURLKey = "rally.apiBaseURL"

    static var baseURL: URL {
        if let s = UserDefaults.standard.string(forKey: baseURLKey),
           let u = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)),
           !s.isEmpty {
            return u
        }
        return URL(string: developmentDefault)!
    }

    static func setBaseURL(_ string: String?) {
        if let string = string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            UserDefaults.standard.set(string, forKey: baseURLKey)
        } else {
            UserDefaults.standard.removeObject(forKey: baseURLKey)
        }
    }
}
