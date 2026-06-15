import Foundation

/// Reward bookkeeping for completed runs.
///
/// `Rewards` is intentionally pure — it computes "what should change" given
/// a `GameResult` and a current `PlayerProgress`, without performing the
/// mutation itself. The `GameSessionView` calls `Rewards.applying(...)`
/// inside a SwiftData transaction so we keep persistence atomic.
///
/// ## Economy
///
/// Coins are the cosmetics currency. Tuned so a strong 3-minute run earns
/// roughly one cheap cosmetic; an A+ run earns more.
///
/// ```
/// coins = floor(score / 50)
///       + perfectHits * 2
///       + bestComboBonus(maxCombo)
///       + accuracyBonus(accuracy)
///       + matchStoryBonus(clean returns / winners / pressure holds)
///       + dailyFirstRunBonus(if streak just incremented)
/// ```
///
/// XP scales similarly but is harder to game with sandbagging — it favors
/// accuracy + combos over raw score, with a small bump for cleaner point
/// construction.
enum Rewards {

    struct Outcome: Equatable {
        var coinsEarned: Int
        var xpEarned: Int
        var previousBestScore: Int
        var previousBestCombo: Int
        var isNewBestScore: Bool
        var isNewBestCombo: Bool
        var didLevelUp: Bool
        var newLevel: Int
        var newStreak: Int
        var streakIncreased: Bool
        var newBadgesEarned: [String] = []  // badgeIds of newly earned achievements
    }

    /// Compute the reward outcome AND apply it to the given progress
    /// record. Returns the outcome so the UI can celebrate accordingly.
    /// Callers are expected to `try? modelContext.save()` after.
    @discardableResult
    static func applying(result: GameResult, to progress: PlayerProgress, now: Date = Date()) -> Outcome {
        let coins = coinsFor(result: result)
        let xp    = xpFor(result: result)

        let previousBestScore = progress.bestScore
        let previousBestCombo = progress.bestCombo
        let isNewScore = result.finalScore > progress.bestScore
        let isNewCombo = result.maxCombo > progress.bestCombo

        let previousLevel = progress.level

        // Streak update before we mutate coin/xp totals so the streak bonus
        // (added below) reflects the new streak count.
        let streakInfo = updatedStreak(currentStreak: progress.dailyStreak, lastPlay: progress.lastPlayDate, now: now)
        let streakBonus = streakInfo.increased ? streakBonusCoins(streak: streakInfo.streak) : 0

        progress.coins += coins + streakBonus
        progress.xp    += xp
        progress.totalSessions += 1
        progress.totalPerfectHits += result.perfectHits
        progress.totalGreatHits   += result.greatHits
        progress.totalGoodHits    += result.goodHits
        progress.totalMisses      += result.misses
        progress.totalCleanReturnPickups += result.cleanReturnPickups
        progress.totalChangeupWinners += result.changeupWinners
        progress.totalPressureHolds += result.pressureHolds

        if isNewScore { progress.bestScore = result.finalScore }
        if isNewCombo { progress.bestCombo = result.maxCombo }

        progress.dailyStreak = streakInfo.streak
        progress.lastPlayDate = Calendar.current.startOfDay(for: now)

        // Check for newly earned badges
        var newBadges: Set<String> = []
        if progress.totalSessions == 1 { newBadges.insert(BadgeDefinition.firstPlay.rawValue) }
        if progress.bestScore >= 100 && isNewScore { newBadges.insert(BadgeDefinition.firstScore100.rawValue) }
        if result.perfectHits > 0 { newBadges.insert(BadgeDefinition.firstPerfectHit.rawValue) }
        if result.maxCombo >= Tunables.comboTier1 { newBadges.insert(BadgeDefinition.firstCombo.rawValue) }

        if streakInfo.streak >= 7 { newBadges.insert(BadgeDefinition.streak7Days.rawValue) }
        if streakInfo.streak >= 30 { newBadges.insert(BadgeDefinition.streak30Days.rawValue) }
        if streakInfo.streak >= 100 { newBadges.insert(BadgeDefinition.streak100Days.rawValue) }

        if result.maxCombo >= 50 { newBadges.insert(BadgeDefinition.perfectCombo50.rawValue) }
        if result.maxCombo >= 100 { newBadges.insert(BadgeDefinition.perfectCombo100.rawValue) }

        if result.accuracy >= 0.90 { newBadges.insert(BadgeDefinition.accuracy90.rawValue) }
        if result.accuracy >= 0.95 { newBadges.insert(BadgeDefinition.accuracy95.rawValue) }
        if result.cleanReturnPickups > 0 { newBadges.insert(BadgeDefinition.firstCleanReturn.rawValue) }
        if result.changeupWinners >= 3 { newBadges.insert(BadgeDefinition.changeupWinner3.rawValue) }
        if result.pressureHolds >= 5 { newBadges.insert(BadgeDefinition.pressureHold5.rawValue) }

        if progress.level >= 5 { newBadges.insert(BadgeDefinition.level5.rawValue) }
        if progress.level >= 10 { newBadges.insert(BadgeDefinition.level10.rawValue) }
        if progress.level >= 25 { newBadges.insert(BadgeDefinition.level25.rawValue) }
        if progress.level >= 50 { newBadges.insert(BadgeDefinition.level50.rawValue) }

        if progress.totalSessions >= 10 { newBadges.insert(BadgeDefinition.session10.rawValue) }
        if progress.totalSessions >= 50 { newBadges.insert(BadgeDefinition.session50.rawValue) }
        if progress.bestScore >= 1000 { newBadges.insert(BadgeDefinition.totalScore1000.rawValue) }

        return Outcome(
            coinsEarned: coins + streakBonus,
            xpEarned: xp,
            previousBestScore: previousBestScore,
            previousBestCombo: previousBestCombo,
            isNewBestScore: isNewScore,
            isNewBestCombo: isNewCombo,
            didLevelUp: progress.level > previousLevel,
            newLevel: progress.level,
            newStreak: streakInfo.streak,
            streakIncreased: streakInfo.increased,
            newBadgesEarned: Array(newBadges).sorted()
        )
    }

    // MARK: - Economy formulas (pure)

    static func coinsFor(result: GameResult) -> Int {
        let base = result.finalScore / 50
        let perfectBonus = result.perfectHits * 2
        let comboBonus = comboCoinBonus(result.maxCombo)
        let accuracyBonus = accuracyCoinBonus(result.accuracy)
        let matchStoryBonus = matchStoryCoinBonus(result)
        return max(0, base + perfectBonus + comboBonus + accuracyBonus + matchStoryBonus)
    }

    static func xpFor(result: GameResult) -> Int {
        // XP rewards both engagement (hits) and quality (perfect rate).
        let baseHits = result.totalHits * 5
        let perfectBoost = result.perfectHits * 10
        let comboFactor = result.maxCombo / 5
        let matchStoryBonus = matchStoryXPBonus(result)
        return max(0, baseHits + perfectBoost + comboFactor * 5 + matchStoryBonus)
    }

    /// Tiered combo bonus — rewards passing the same tier thresholds the
    /// music uses, so the player feels them.
    private static func comboCoinBonus(_ maxCombo: Int) -> Int {
        switch maxCombo {
        case 0..<Tunables.comboTier1: return 0
        case Tunables.comboTier1..<Tunables.comboTier2: return 5
        case Tunables.comboTier2..<Tunables.comboTier3: return 15
        case Tunables.comboTier3..<Tunables.comboTier4: return 35
        default: return 75
        }
    }

    /// Accuracy bonus — A-grade play deserves a tip.
    private static func accuracyCoinBonus(_ accuracy: Double) -> Int {
        switch accuracy {
        case 0.95...: return 20
        case 0.85...: return 10
        case 0.75...: return 5
        default:      return 0
        }
    }

    private static func matchStoryCoinBonus(_ result: GameResult) -> Int {
        let returnValue = min(10, result.cleanReturnPickups * 2)
        let winnerValue = min(12, result.changeupWinners * 3)
        let pressureValue = min(15, result.pressureHolds * 5)
        return returnValue + winnerValue + pressureValue
    }

    private static func matchStoryXPBonus(_ result: GameResult) -> Int {
        let returnValue = result.cleanReturnPickups * 6
        let winnerValue = result.changeupWinners * 8
        let pressureValue = result.pressureHolds * 12
        return returnValue + winnerValue + pressureValue
    }

    private static func streakBonusCoins(streak: Int) -> Int {
        // 5 coins per consecutive day, capped at 35 (week-streak).
        min(35, max(0, streak) * 5)
    }

    // MARK: - Streak math (pure)

    struct StreakResult: Equatable {
        var streak: Int
        var increased: Bool
    }

    static func updatedStreak(currentStreak: Int, lastPlay: Date?, now: Date) -> StreakResult {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        guard let lastPlay = lastPlay else {
            return StreakResult(streak: 1, increased: true)
        }
        let lastDay = cal.startOfDay(for: lastPlay)
        if lastDay == today {
            // Already counted today — no streak change.
            return StreakResult(streak: max(1, currentStreak), increased: false)
        }
        let days = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if days == 1 {
            return StreakResult(streak: currentStreak + 1, increased: true)
        }
        // Missed at least one day — streak resets to 1 (today counts).
        return StreakResult(streak: 1, increased: true)
    }
}
