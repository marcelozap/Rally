import Foundation
import SwiftData

/// Represents a daily challenge the player can attempt
@Model
final class DailyChallenge {
    var id: UUID = UUID()

    /// Unique identifier: "score_250", "combo_30", etc.
    var challengeId: String

    /// Display title
    var title: String

    /// Longer description
    var details: String

    /// Required target value
    var target: Int

    /// Current player progress
    var currentProgress: Int = 0

    /// SF Symbol icon
    var iconName: String

    /// Color theme (hex string)
    var colorHex: String

    /// Reward coins if completed
    var rewardCoins: Int

    /// Date the challenge was created
    var createdDate: Date = Date()

    /// Whether the player completed this challenge today
    var isCompleted: Bool = false

    /// When it was completed (if at all)
    var completedDate: Date?

    init(
        challengeId: String,
        title: String,
        details: String,
        target: Int,
        iconName: String,
        colorHex: String,
        rewardCoins: Int
    ) {
        self.id = UUID()
        self.challengeId = challengeId
        self.title = title
        self.details = details
        self.target = target
        self.iconName = iconName
        self.colorHex = colorHex
        self.rewardCoins = rewardCoins
    }

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(currentProgress) / Double(target))
    }

    func markComplete() {
        isCompleted = true
        completedDate = Date()
    }
}

/// Challenge templates for daily generation
enum ChallengeTemplate: String, CaseIterable {
    case score250 = "score_250"
    case score500 = "score_500"
    case perfectHits10 = "perfect_hits_10"
    case combo30 = "combo_30"
    case accuracy85 = "accuracy_85"
    case twoGames = "two_games"
    case threePerfects = "three_perfects"
    case cleanReturns5 = "clean_returns_5"
    case changeupWinners2 = "changeup_winners_2"
    case pressureHolds2 = "pressure_holds_2"

    var definition: (title: String, description: String, target: Int, icon: String, color: String, reward: Int) {
        switch self {
        case .score250:
            ("Quick Cash", "Score 250 points", 250, "bolt.fill", "#00D9FF", 50)
        case .score500:
            ("Big Scorer", "Score 500 points", 500, "star.fill", "#FFD700", 100)
        case .perfectHits10:
            ("Perfect Shot", "Land 10 perfect hits", 10, "checkmark.circle.fill", "#FF1493", 75)
        case .combo30:
            ("On Fire", "Build a 30+ combo", 30, "flame.fill", "#FF6B35", 80)
        case .accuracy85:
            ("Precision Play", "Achieve 85% accuracy", 85, "target", "#00D9FF", 60)
        case .twoGames:
            ("Warm Up", "Play 2 games", 2, "gamecontroller.fill", "#FFD700", 40)
        case .threePerfects:
            ("Legend", "Land 3 perfect hits", 3, "crown.fill", "#FF1493", 90)
        case .cleanReturns5:
            ("Return Wall", "Register 5 clean returns", 5, "arrow.uturn.left.circle.fill", "#00D9FF", 70)
        case .changeupWinners2:
            ("Break The Pattern", "Hit 2 change-up winners", 2, "bolt.badge.clock.fill", "#FF1493", 85)
        case .pressureHolds2:
            ("Hold Firm", "Complete 2 pressure holds", 2, "shield.lefthalf.filled", "#FFD700", 95)
        }
    }

    func create() -> DailyChallenge {
        let def = definition
        return DailyChallenge(
            challengeId: rawValue,
            title: def.title,
            details: def.description,
            target: def.target,
            iconName: def.icon,
            colorHex: def.color,
            rewardCoins: def.reward
        )
    }
}

/// Helper to generate and manage daily challenges
struct DailyChallengeMgr {
    static func accuracyPercent(perfectHits: Int, greatHits: Int, totalHits: Int) -> Int {
        guard totalHits > 0 else { return 0 }
        let accuracy = Double(perfectHits + greatHits) / Double(totalHits)
        guard accuracy.isFinite else { return 0 }
        return Int(accuracy * 100)
    }

    /// Generate challenges for today (call once per app session)
    static func generateDailyIfNeeded(modelContext: ModelContext) {
        do {
            let existing = try modelContext.fetch(FetchDescriptor<DailyChallenge>())
                .filter { Calendar.current.isDateInToday($0.createdDate) }
            // If we already have today's challenges, don't regenerate
            guard existing.isEmpty else { return }
        } catch {
            print("❌ Failed to fetch daily challenges:", error)
        }

        // Generate 3 random challenges for today
        let selected = ChallengeTemplate.allCases.shuffled().prefix(3)
        for template in selected {
            let challenge = template.create()
            modelContext.insert(challenge)
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save daily challenges:", error)
        }
    }

    /// Update challenge progress based on game result
    static func updateChallenges(
        from result: GameResult,
        modelContext: ModelContext
    ) {
        do {
            let challenges = try modelContext.fetch(FetchDescriptor<DailyChallenge>())
                .filter { Calendar.current.isDateInToday($0.createdDate) && !$0.isCompleted }

            for i in challenges.indices {
                let accuracyPercent = accuracyPercent(
                    perfectHits: result.perfectHits,
                    greatHits: result.greatHits,
                    totalHits: result.totalHits
                )

                switch challenges[i].challengeId {
                case ChallengeTemplate.score250.rawValue:
                    challenges[i].currentProgress += result.finalScore
                case ChallengeTemplate.score500.rawValue:
                    challenges[i].currentProgress += result.finalScore
                case ChallengeTemplate.perfectHits10.rawValue:
                    challenges[i].currentProgress += result.perfectHits
                case ChallengeTemplate.combo30.rawValue:
                    challenges[i].currentProgress = max(challenges[i].currentProgress, result.maxCombo)
                case ChallengeTemplate.accuracy85.rawValue:
                    challenges[i].currentProgress = max(challenges[i].currentProgress, accuracyPercent)
                case ChallengeTemplate.twoGames.rawValue:
                    challenges[i].currentProgress += 1
                case ChallengeTemplate.threePerfects.rawValue:
                    challenges[i].currentProgress += result.perfectHits
                case ChallengeTemplate.cleanReturns5.rawValue:
                    challenges[i].currentProgress += result.cleanReturnPickups
                case ChallengeTemplate.changeupWinners2.rawValue:
                    challenges[i].currentProgress += result.changeupWinners
                case ChallengeTemplate.pressureHolds2.rawValue:
                    challenges[i].currentProgress += result.pressureHolds
                default:
                    break
                }

                // Check if completed
                if challenges[i].currentProgress >= challenges[i].target && !challenges[i].isCompleted {
                    challenges[i].markComplete()
                }
            }

            try modelContext.save()
        } catch {
            print("❌ Failed to update daily challenges:", error)
        }
    }
}
