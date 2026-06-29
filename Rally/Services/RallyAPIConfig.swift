import Foundation

enum UserDefaultsKeys {
    static let savedEmail = "rally.savedEmail"
    /// Persisted **Continue offline** choice until sign-in clears it.
    static let guestMode = "rally.guestMode"
    /// Master mute for music + SFX.
    static let soundEnabled = "rally.soundEnabled"
    /// Marks that the player intentionally changed the sound setting.
    static let soundPreferenceExplicitlySet = "rally.soundPreferenceExplicitlySet"
    /// One-time migration marker for the quiet-by-default audio policy.
    static let soundQuietDefaultApplied = "rally.soundQuietDefaultApplied.v1"
    static let gameDominantHand = "rally.gameDominantHand"
    static let gameShowCoachingCues = "rally.gameShowCoachingCues"
    static let gameHapticsEnabled = "rally.gameHapticsEnabled"
    static let gameMatchPace = "rally.gameMatchPace"
}

enum RallyDefaults {
    /// One-time reset for builds that previously had sound enabled during
    /// testing. After this runs, the player can still opt back in from any
    /// sound toggle and that choice will persist.
    static func applyQuietSoundDefaultIfNeeded(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: UserDefaultsKeys.soundQuietDefaultApplied) else { return }
        defaults.set(false, forKey: UserDefaultsKeys.soundEnabled)
        defaults.set(true, forKey: UserDefaultsKeys.soundPreferenceExplicitlySet)
        defaults.set(true, forKey: UserDefaultsKeys.soundQuietDefaultApplied)
    }

    /// Sound should stay quiet by default so test/autoplay launches never
    /// surprise the room. The player can still opt in from the sound toggle.
    static func resolvedSoundEnabled(
        _ defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        #if DEBUG
        if arguments.contains("-RallyAutoPlay") {
            return false
        }
        #endif
        if defaults.bool(forKey: UserDefaultsKeys.soundPreferenceExplicitlySet) {
            return defaults.bool(forKey: UserDefaultsKeys.soundEnabled)
        }
        return false
    }
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
