import Foundation
import SwiftData

struct RivalOpponent: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let style: String
    let targetScore: Int
    let level: Int
    let rewardCoins: Int
    let badge: String
}

@Model
final class RivalChallenge {
    var id: UUID = UUID()
    var opponentName: String
    var targetScore: Int
    var playerScore: Int
    var didWin: Bool
    var completedDate: Date

    init(opponentName: String, targetScore: Int, playerScore: Int, didWin: Bool) {
        self.opponentName = opponentName
        self.targetScore = targetScore
        self.playerScore = playerScore
        self.didWin = didWin
        self.completedDate = Date()
    }
}

struct RivalModeManager {
    static var sampleOpponents: [RivalOpponent] {
        [
            RivalOpponent(name: "Sonic Slice", style: "Precision", targetScore: 2100, level: 16, rewardCoins: 60, badge: "bolt.fill"),
            RivalOpponent(name: "Court Commander", style: "Power", targetScore: 2400, level: 18, rewardCoins: 80, badge: "shield.fill"),
            RivalOpponent(name: "Volley Vixen", style: "Rhythm", targetScore: 1900, level: 15, rewardCoins: 50, badge: "heart.fill")
        ]
    }

    static func addChallengeResult(_ result: RivalChallenge, modelContext: ModelContext) {
        modelContext.insert(result)
        try? modelContext.save()
    }
}
