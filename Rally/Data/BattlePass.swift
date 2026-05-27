import Foundation
import SwiftData

struct BattlePassTier: Identifiable, Equatable {
    let id: Int
    let name: String
    let rewardDescription: String
    let xpThreshold: Int
    let premiumOnly: Bool
}

@Model
final class BattlePass {
    var id: UUID = UUID()
    var xp: Int = 0
    var seasonName: String = "Summer Smash"
    var seasonEndDate: Date = Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date()
    var premiumUnlocked: Bool = false
    var claimedTiersCSV: String = ""

    static let xpPerTier = 500

    init(
        xp: Int = 0,
        seasonName: String = "Summer Smash",
        seasonEndDate: Date = Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date(),
        premiumUnlocked: Bool = false,
        claimedTiersCSV: String = ""
    ) {
        self.id = UUID()
        self.xp = xp
        self.seasonName = seasonName
        self.seasonEndDate = seasonEndDate
        self.premiumUnlocked = premiumUnlocked
        self.claimedTiersCSV = claimedTiersCSV
    }

    var claimedTierIndices: Set<Int> {
        get { Set(claimedTiersCSV.split(separator: ",").compactMap { Int($0) }) }
        set { claimedTiersCSV = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    var level: Int { 1 + xp / Self.xpPerTier }
    var tierProgress: Double { Double(xp % Self.xpPerTier) / Double(Self.xpPerTier) }
    var daysRemaining: Int {
        let comps = Calendar.current.dateComponents([.day], from: Date(), to: seasonEndDate)
        return max(0, comps.day ?? 0)
    }

    var activeTiers: [BattlePassTier] {
        BattlePass.availableTiers
    }

    var currentTier: BattlePassTier? {
        BattlePass.availableTiers.last(where: { xp >= $0.xpThreshold })
    }

    static var availableTiers: [BattlePassTier] {
        [
            BattlePassTier(id: 1, name: "Rookie", rewardDescription: "Vintage racket skin", xpThreshold: 0, premiumOnly: false),
            BattlePassTier(id: 2, name: "Ace", rewardDescription: "Neon wristband", xpThreshold: 500, premiumOnly: false),
            BattlePassTier(id: 3, name: "Champion", rewardDescription: "Exclusive livery", xpThreshold: 1000, premiumOnly: true),
            BattlePassTier(id: 4, name: "Smash", rewardDescription: "Animated avatar badge", xpThreshold: 1500, premiumOnly: true),
            BattlePassTier(id: 5, name: "Legend", rewardDescription: "Golden racket trail", xpThreshold: 2000, premiumOnly: true)
        ]
    }
}

struct BattlePassManager {
    static func seedIfNeeded(modelContext: ModelContext) {
        let passes = (try? modelContext.fetch(FetchDescriptor<BattlePass>())) ?? []
        guard passes.isEmpty else { return }
        modelContext.insert(BattlePass())
        try? modelContext.save()
    }

    static func grantXP(_ amount: Int, to modelContext: ModelContext) {
        guard let pass = (try? modelContext.fetch(FetchDescriptor<BattlePass>()))?.first else { return }
        pass.xp += amount
        try? modelContext.save()
    }

    static func rewardFor(currentXP: Int) -> String {
        let tier = BattlePass.availableTiers.last(where: { currentXP >= $0.xpThreshold })
        return tier?.rewardDescription ?? "Start the pass"
    }

    static func claimTier(_ tier: BattlePassTier, modelContext: ModelContext) {
        guard let pass = (try? modelContext.fetch(FetchDescriptor<BattlePass>()))?.first else { return }
        pass.claimedTierIndices.insert(tier.id)
        try? modelContext.save()
    }
}
