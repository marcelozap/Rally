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
        case .miamiHard:      return "Australia"
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

    /// Court paint + sky colors for the faux-3D backdrop.
    var palette: (skyTop: UIColor, skyBottom: UIColor, court: UIColor, courtDark: UIColor, line: UIColor) {
        switch self {
        case .miamiHard:
            return (
                UIColor(red: 0.35, green: 0.72, blue: 0.92, alpha: 1),
                UIColor(red: 0.12, green: 0.45, blue: 0.62, alpha: 1),
                UIColor(red: 0.08, green: 0.42, blue: 0.55, alpha: 1),
                UIColor(red: 0.05, green: 0.28, blue: 0.38, alpha: 1),
                UIColor(white: 0.95, alpha: 1)
            )
        case .wimbledonGrass:
            return (
                UIColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1),
                UIColor(red: 0.35, green: 0.58, blue: 0.82, alpha: 1),
                UIColor(red: 0.22, green: 0.52, blue: 0.28, alpha: 1),
                UIColor(red: 0.14, green: 0.38, blue: 0.20, alpha: 1),
                UIColor(white: 0.92, alpha: 1)
            )
        case .redClay:
            return (
                UIColor(red: 0.42, green: 0.62, blue: 0.88, alpha: 1),
                UIColor(red: 0.62, green: 0.42, blue: 0.38, alpha: 1),
                UIColor(red: 0.72, green: 0.34, blue: 0.22, alpha: 1),
                UIColor(red: 0.52, green: 0.22, blue: 0.14, alpha: 1),
                UIColor(white: 0.90, alpha: 0.95)
            )
        case .barcelonaClay:
            return (
                UIColor(red: 0.48, green: 0.68, blue: 0.92, alpha: 1),
                UIColor(red: 0.58, green: 0.48, blue: 0.38, alpha: 1),
                UIColor(red: 0.78, green: 0.42, blue: 0.22, alpha: 1),
                UIColor(red: 0.55, green: 0.28, blue: 0.14, alpha: 1),
                UIColor(white: 0.91, alpha: 1)
            )
        }
    }
}
