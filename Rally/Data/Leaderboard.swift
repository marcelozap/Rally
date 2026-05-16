import Foundation
import SwiftData

@Model
final class LeaderboardEntry {
    var id: UUID = UUID()
    var playerName: String
    var score: Int
    var level: Int
    var rank: Int
    var badge: String
    var isPlayer: Bool
    var lastUpdated: Date

    init(playerName: String, score: Int, level: Int, rank: Int, badge: String = "sparkles", isPlayer: Bool = false) {
        self.id = UUID()
        self.playerName = playerName
        self.score = score
        self.level = level
        self.rank = rank
        self.badge = badge
        self.isPlayer = isPlayer
        self.lastUpdated = Date()
    }
}

struct LeaderboardManager {
    static func seedIfNeeded(modelContext: ModelContext) {
        let existing = (try? modelContext.fetch(FetchDescriptor<LeaderboardEntry>())) ?? []
        guard existing.isEmpty else { return }

        let samples = [
            LeaderboardEntry(playerName: "Nova Ace", score: 3480, level: 22, rank: 1, badge: "crown.fill"),
            LeaderboardEntry(playerName: "RallyRenegade", score: 3280, level: 20, rank: 2, badge: "flame.fill"),
            LeaderboardEntry(playerName: "CourtQueen", score: 3010, level: 18, rank: 3, badge: "star.fill"),
            LeaderboardEntry(playerName: "SpinMaster", score: 2890, level: 17, rank: 4),
            LeaderboardEntry(playerName: "BaselinePro", score: 2765, level: 16, rank: 5)
        ]
        samples.forEach { modelContext.insert($0) }
        try? modelContext.save()
    }

    static func updateLeaderboard(for playerName: String, score: Int, level: Int, modelContext: ModelContext) {
        let request = FetchDescriptor<LeaderboardEntry>()
        guard let entries = try? modelContext.fetch(request) else { return }

        let playerEntry = entries.first { $0.isPlayer }
        if let player = playerEntry {
            player.score = max(player.score, score)
            player.level = level
            player.lastUpdated = Date()
        } else {
            let newPlayer = LeaderboardEntry(playerName: playerName, score: score, level: level, rank: entries.count + 1, badge: "person.fill", isPlayer: true)
            modelContext.insert(newPlayer)
        }

        let sorted = (try? modelContext.fetch(request))?.sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.level > rhs.level }
            return lhs.score > rhs.score
        } ?? []

        for (index, entry) in sorted.enumerated() {
            entry.rank = index + 1
        }

        try? modelContext.save()
    }
}
