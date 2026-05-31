import SwiftUI

/// Player-facing match settings that should be reachable from the live play
/// screen rather than hidden behind debug-only controls.
@MainActor
final class GamePreferences: ObservableObject {
    static let shared = GamePreferences()

    enum DominantHand: String, CaseIterable, Identifiable {
        case right
        case left

        var id: String { rawValue }

        var title: String {
            switch self {
            case .right: return "Right"
            case .left: return "Left"
            }
        }

        var coachingCopy: String {
            switch self {
            case .right: return "Forehand emphasis stays on the right lane."
            case .left: return "Forehand emphasis flips to the left lane."
            }
        }
    }

    enum MatchPace: String, CaseIterable, Identifiable {
        case calm
        case standard
        case quick

        var id: String { rawValue }

        var title: String {
            switch self {
            case .calm: return "Calm"
            case .standard: return "Standard"
            case .quick: return "Quick"
            }
        }

        var subtitle: String {
            switch self {
            case .calm: return "More read time through the strike window."
            case .standard: return "Balanced live pace."
            case .quick: return "Sharper incoming pace and less breathing room."
            }
        }

        var travelScalar: Double {
            switch self {
            case .calm: return 1.14
            case .standard: return 1.0
            case .quick: return 0.9
            }
        }
    }

    @Published var dominantHand: DominantHand {
        didSet {
            guard oldValue != dominantHand else { return }
            UserDefaults.standard.set(dominantHand.rawValue, forKey: UserDefaultsKeys.gameDominantHand)
        }
    }

    @Published var showCoachingCues: Bool {
        didSet {
            guard oldValue != showCoachingCues else { return }
            UserDefaults.standard.set(showCoachingCues, forKey: UserDefaultsKeys.gameShowCoachingCues)
        }
    }

    @Published var isHapticsEnabled: Bool {
        didSet {
            guard oldValue != isHapticsEnabled else { return }
            UserDefaults.standard.set(isHapticsEnabled, forKey: UserDefaultsKeys.gameHapticsEnabled)
            HapticManager.shared.isEnabled = isHapticsEnabled
        }
    }

    @Published var matchPace: MatchPace {
        didSet {
            guard oldValue != matchPace else { return }
            UserDefaults.standard.set(matchPace.rawValue, forKey: UserDefaultsKeys.gameMatchPace)
        }
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: UserDefaultsKeys.gameDominantHand),
           let hand = DominantHand(rawValue: stored) {
            dominantHand = hand
        } else {
            dominantHand = .right
        }

        if UserDefaults.standard.object(forKey: UserDefaultsKeys.gameShowCoachingCues) == nil {
            showCoachingCues = true
        } else {
            showCoachingCues = UserDefaults.standard.bool(forKey: UserDefaultsKeys.gameShowCoachingCues)
        }

        if UserDefaults.standard.object(forKey: UserDefaultsKeys.gameHapticsEnabled) == nil {
            isHapticsEnabled = true
        } else {
            isHapticsEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.gameHapticsEnabled)
        }

        if let stored = UserDefaults.standard.string(forKey: UserDefaultsKeys.gameMatchPace),
           let pace = MatchPace(rawValue: stored) {
            matchPace = pace
        } else {
            matchPace = .standard
        }

        HapticManager.shared.isEnabled = isHapticsEnabled
    }
}
