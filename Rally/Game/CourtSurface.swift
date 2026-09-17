import CoreGraphics
import UIKit

/// Venue + surface preset for local play (`UserDefaults`). Display names use
/// Barcelona / Wimbledon / Miami where applicable. Distinct from the data-layer
/// `CourtSurface` enum (`Rally/Data/MatchModels.swift`) used for match logs.
typealias CourtTheme = CourtVenue

/// Real-world inspired venues — stored locally (`UserDefaults`), no API.
enum CourtVenue: String, CaseIterable, Identifiable {
    case miamiHard
    case wimbledonGrass
    case redClay
    case barcelonaClay

    var id: String { rawValue }

    static let storageKey = "rally.courtVenue"

    static var current: CourtVenue {
        get {
            guard let s = UserDefaults.standard.string(forKey: storageKey),
                  let v = CourtVenue(rawValue: s) else { return .miamiHard }
            return v
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }

    var displayName: String {
        switch self {
        case .miamiHard:      return "Miami"
        case .wimbledonGrass: return "Wimbledon"
        case .redClay:        return "Clay"
        case .barcelonaClay:  return "Barcelona"
        }
    }

    /// Tennis ball bounce feel per surface (SpriteKit tuning).
    var ballRestitution: CGFloat {
        switch self {
        case .miamiHard:      return 0.82
        case .wimbledonGrass: return 0.72
        case .redClay:        return 0.62
        case .barcelonaClay:  return 0.64
        }
    }

    var ballLinearDamping: CGFloat {
        switch self {
        case .miamiHard:      return 0.35
        case .wimbledonGrass: return 0.55
        case .redClay:        return 0.75
        case .barcelonaClay:  return 0.72
        }
    }

    /// Restrained daylight materials shared by every native court render.
    var palette: (skyTop: UIColor, skyBottom: UIColor, court: UIColor, courtDark: UIColor, line: UIColor) {
        let ivory = UIColor(red: 0.96, green: 0.95, blue: 0.86, alpha: 1)
        switch self {
        case .miamiHard:
            return (
                UIColor(red: 0.53, green: 0.72, blue: 0.77, alpha: 1),
                UIColor(red: 0.84, green: 0.88, blue: 0.79, alpha: 1),
                UIColor(red: 0.23, green: 0.43, blue: 0.54, alpha: 1),
                UIColor(red: 0.17, green: 0.34, blue: 0.43, alpha: 1),
                ivory
            )
        case .wimbledonGrass:
            return (
                UIColor(red: 0.58, green: 0.71, blue: 0.73, alpha: 1),
                UIColor(red: 0.85, green: 0.88, blue: 0.79, alpha: 1),
                UIColor(red: 0.33, green: 0.49, blue: 0.29, alpha: 1),
                UIColor(red: 0.21, green: 0.36, blue: 0.22, alpha: 1),
                ivory
            )
        case .redClay:
            return (
                UIColor(red: 0.62, green: 0.73, blue: 0.75, alpha: 1),
                UIColor(red: 0.90, green: 0.83, blue: 0.68, alpha: 1),
                UIColor(red: 0.68, green: 0.39, blue: 0.27, alpha: 1),
                UIColor(red: 0.54, green: 0.30, blue: 0.21, alpha: 1),
                ivory
            )
        case .barcelonaClay:
            return (
                UIColor(red: 0.56, green: 0.73, blue: 0.79, alpha: 1),
                UIColor(red: 0.94, green: 0.85, blue: 0.68, alpha: 1),
                UIColor(red: 0.73, green: 0.43, blue: 0.28, alpha: 1),
                UIColor(red: 0.58, green: 0.32, blue: 0.20, alpha: 1),
                ivory
            )
        }
    }
}
