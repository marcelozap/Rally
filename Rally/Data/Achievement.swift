import Foundation
import SwiftData

/// Represents a single achievement badge the player can earn.
@Model
final class Achievement {
    var id: UUID = UUID()

    /// Unique identifier: "first_play", "perfect_100_combo", "level_10", etc.
    var badgeId: String

    /// Human-readable title: "First Swing", "Centurion", "Rising Star"
    var title: String

    /// Longer description
    var details: String

    /// SF Symbol name for the badge icon
    var iconName: String

    /// Color theme (hex string or named color)
    var colorHex: String

    /// When the badge was earned
    var earnedDate: Date

    /// Rarity tier: "common", "uncommon", "rare", "epic", "legendary"
    var rarity: String

    init(badgeId: String, title: String, details: String, iconName: String, colorHex: String, rarity: String) {
        self.id = UUID()
        self.badgeId = badgeId
        self.title = title
        self.details = details
        self.iconName = iconName
        self.colorHex = colorHex
        self.earnedDate = Date()
        self.rarity = rarity
    }
}

/// Badges earned: keyed by badgeId for quick lookup.
enum BadgeDefinition: String, CaseIterable {
    // Milestone badges
    case firstPlay = "first_play"
    case firstScore100 = "score_100"
    case firstPerfectHit = "perfect_hit"
    case firstCombo = "first_combo"

    // Streak badges
    case streak7Days = "streak_7"
    case streak30Days = "streak_30"
    case streak100Days = "streak_100"

    // Performance badges
    case perfectCombo50 = "combo_50"
    case perfectCombo100 = "combo_100"
    case accuracy90 = "accuracy_90"
    case accuracy95 = "accuracy_95"
    case firstCleanReturn = "clean_return"
    case changeupWinner3 = "changeup_winner_3"
    case pressureHold5 = "pressure_hold_5"

    // Progression badges
    case level5 = "level_5"
    case level10 = "level_10"
    case level25 = "level_25"
    case level50 = "level_50"

    // Gameplay badges
    case session10 = "sessions_10"
    case session50 = "sessions_50"
    case totalScore1000 = "total_score_1000"

    // Social badges
    case shopCustomizer = "customized_avatar"
    case shopPurchase = "made_purchase"

    var metadata: (title: String, description: String, icon: String, color: String, rarity: String) {
        switch self {
        case .firstPlay:
            ("First Swing", "Play your first game", "tennis.racket", "#00D9FF", "common")
        case .firstScore100:
            ("Century", "Reach 100 score", "star.fill", "#FFD700", "common")
        case .firstPerfectHit:
            ("Perfect!", "Land your first perfect hit", "checkmark.circle.fill", "#FF1493", "uncommon")
        case .firstCombo:
            ("Combo King", "Build your first combo", "flame.fill", "#FF6B35", "uncommon")

        case .streak7Days:
            ("Week Warrior", "7-day streak", "calendar", "#00D9FF", "uncommon")
        case .streak30Days:
            ("Monthly Grinder", "30-day streak", "calendar", "#FF1493", "rare")
        case .streak100Days:
            ("Legend", "100-day streak", "crown.fill", "#FFD700", "legendary")

        case .perfectCombo50:
            ("Unstoppable", "50+ combo", "bolt.fill", "#FF6B35", "rare")
        case .perfectCombo100:
            ("Flawless", "100+ combo", "bolt.fill", "#00D9FF", "epic")
        case .accuracy90:
            ("Precision", "90% accuracy", "target", "#FFD700", "uncommon")
        case .accuracy95:
            ("Sharpshooter", "95% accuracy", "target", "#FF1493", "rare")
        case .firstCleanReturn:
            ("Return Game", "Register your first clean return pickup", "arrow.uturn.left.circle.fill", "#00D9FF", "uncommon")
        case .changeupWinner3:
            ("Pattern Breaker", "Hit 3 change-up winners in a run", "bolt.badge.clock.fill", "#FF1493", "rare")
        case .pressureHold5:
            ("Ice In Veins", "Hold 5 pressure exchanges in a run", "shield.lefthalf.filled", "#FFD700", "epic")

        case .level5:
            ("Climbing", "Reach Level 5", "arrow.up", "#00D9FF", "common")
        case .level10:
            ("Rising Star", "Reach Level 10", "star.fill", "#FFD700", "uncommon")
        case .level25:
            ("Champion", "Reach Level 25", "crown.fill", "#FF1493", "epic")
        case .level50:
            ("Godlike", "Reach Level 50", "crown.fill", "#00D9FF", "legendary")

        case .session10:
            ("Addict", "Play 10 games", "gamecontroller.fill", "#FF6B35", "uncommon")
        case .session50:
            ("Marathon", "Play 50 games", "gamecontroller.fill", "#FFD700", "rare")
        case .totalScore1000:
            ("Big Scorer", "1000+ total score", "square.and.arrow.up", "#00D9FF", "uncommon")

        case .shopCustomizer:
            ("Fashionista", "Customize your avatar", "sparkles", "#FF1493", "common")
        case .shopPurchase:
            ("Collector", "Purchase a shop item", "bag.fill", "#FFD700", "uncommon")
        }
    }

    func create() -> Achievement {
        let metadata = self.metadata
        return Achievement(
            badgeId: self.rawValue,
            title: metadata.title,
            details: metadata.description,
            iconName: metadata.icon,
            colorHex: metadata.color,
            rarity: metadata.rarity
        )
    }
}
