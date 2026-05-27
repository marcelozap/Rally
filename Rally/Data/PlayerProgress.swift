import Foundation
import SwiftData

/// Singleton-style progression row — see `RallyApp.seedIfNeeded`.
@Model
final class PlayerProgress {
    var id: UUID = UUID()

    var coins: Int = 0
    var xp: Int = 0
    var bestScore: Int = 0
    var bestCombo: Int = 0

    var totalSessions: Int = 0
    var totalPerfectHits: Int = 0
    var totalGreatHits: Int = 0
    var totalGoodHits: Int = 0
    var totalMisses: Int = 0
    var totalCleanReturnPickups: Int = 0
    var totalChangeupWinners: Int = 0
    var totalPressureHolds: Int = 0

    var dailyStreak: Int = 0
    var lastPlayDate: Date? = nil

    init() {
        self.id = UUID()
    }

    var level: Int { 1 + xp / Self.xpPerLevel }

    var levelProgress: Double {
        let inLevel = xp % Self.xpPerLevel
        return Double(inLevel) / Double(Self.xpPerLevel)
    }

    var xpToNextLevel: Int {
        Self.xpPerLevel - (xp % Self.xpPerLevel)
    }

    static let xpPerLevel: Int = 1000
}
