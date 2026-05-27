import Foundation
import SwiftData

struct AnalyticsInsights {
    let totalGames: Int
    let totalWins: Int
    let averageScore: Int
    let averageAccuracy: Double
    let averageCombo: Int
    let totalPerfectHits: Int
    let seasonalProgress: Double
    let achievementsUnlocked: Int
    let recentWinRate: Double

    static func compute(
        progress: PlayerProgress?,
        trainings: [TrainingSession],
        matches: [MatchEntry],
        achievements: [Achievement],
        challenges: [DailyChallenge],
        seasonalEvents: [SeasonalEvent]
    ) -> AnalyticsInsights {
        let games = progress?.totalSessions ?? 0
        let totalScore = progress?.bestScore ?? 0
        let averageScore = games > 0 ? totalScore / max(games, 1) : 0
        let perfectHits = progress?.totalPerfectHits ?? 0
        let greatHits = progress?.totalGreatHits ?? 0
        let goodHits = progress?.totalGoodHits ?? 0
        let misses = progress?.totalMisses ?? 0
        let madeHits = perfectHits + greatHits + goodHits
        let attemptedHits = madeHits + misses
        let accuracy = attemptedHits > 0 ? Double(madeHits) / Double(attemptedHits) : 0
        let averageCombo = games > 0 ? (progress?.bestCombo ?? 0) : 0
        let totalPerfectHits = perfectHits
        let wins = matches.filter(\.resultWon).count
        let recentGames = matches.prefix(10)
        let recentWinRate = recentGames.isEmpty ? 0 : Double(recentGames.filter(\.`resultWon`).count) / Double(recentGames.count)
        let seasonal = seasonalEvents.first?.progressFraction ?? 0
        let achieved = achievements.count

        return AnalyticsInsights(
            totalGames: games,
            totalWins: wins,
            averageScore: averageScore,
            averageAccuracy: accuracy,
            averageCombo: averageCombo,
            totalPerfectHits: totalPerfectHits,
            seasonalProgress: seasonal,
            achievementsUnlocked: achieved,
            recentWinRate: recentWinRate
        )
    }
}
