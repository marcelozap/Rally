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
///       + dailyFirstRunBonus(if streak just incremented)
/// ```
///
/// XP scales similarly but is harder to game with sandbagging — it favors
/// accuracy + combos over raw score.
enum Rewards {

    struct Outcome: Equatable {
        var coinsEarned: Int
        var xpEarned: Int
        var isNewBestScore: Bool
        var isNewBestCombo: Bool
        var didLevelUp: Bool
        var newLevel: Int
        var newStreak: Int
        var streakIncreased: Bool
    }

    /// Compute the reward outcome AND apply it to the given progress
    /// record. Returns the outcome so the UI can celebrate accordingly.
    /// Callers are expected to `try? modelContext.save()` after.
    @discardableResult
    static func applying(result: GameResult, to progress: PlayerProgress, now: Date = Date()) -> Outcome {
        let coins = coinsFor(result: result)
        let xp    = xpFor(result: result)

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

        if isNewScore { progress.bestScore = result.finalScore }
        if isNewCombo { progress.bestCombo = result.maxCombo }

        progress.dailyStreak = streakInfo.streak
        progress.lastPlayDate = Calendar.current.startOfDay(for: now)

        return Outcome(
            coinsEarned: coins + streakBonus,
            xpEarned: xp,
            isNewBestScore: isNewScore,
            isNewBestCombo: isNewCombo,
            didLevelUp: progress.level > previousLevel,
            newLevel: progress.level,
            newStreak: streakInfo.streak,
            streakIncreased: streakInfo.increased
        )
    }

    // MARK: - Economy formulas (pure)

    static func coinsFor(result: GameResult) -> Int {
        let base = result.finalScore / 50
        let perfectBonus = result.perfectHits * 2
        let comboBonus = comboCoinBonus(result.maxCombo)
        let accuracyBonus = accuracyCoinBonus(result.accuracy)
        return max(0, base + perfectBonus + comboBonus + accuracyBonus)
    }

    static func xpFor(result: GameResult) -> Int {
        // XP rewards both engagement (hits) and quality (perfect rate).
        let baseHits = result.totalHits * 5
        let perfectBoost = result.perfectHits * 10
        let comboFactor = result.maxCombo / 5
        return max(0, baseHits + perfectBoost + comboFactor * 5)
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
