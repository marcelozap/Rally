import Foundation
import SwiftData

@Model
final class SeasonalEvent {
    var id: UUID = UUID()
    var eventId: String
    var title: String
    var subtitle: String
    var descriptionText: String
    var goalDescription: String
    var target: Int
    var progress: Int = 0
    var rewardCoins: Int
    var startDate: Date
    var endDate: Date
    var isCompleted: Bool = false

    init(
        eventId: String,
        title: String,
        subtitle: String,
        descriptionText: String,
        goalDescription: String,
        target: Int,
        rewardCoins: Int,
        startDate: Date,
        endDate: Date
    ) {
        self.eventId = eventId
        self.title = title
        self.subtitle = subtitle
        self.descriptionText = descriptionText
        self.goalDescription = goalDescription
        self.target = target
        self.rewardCoins = rewardCoins
        self.startDate = startDate
        self.endDate = endDate
    }

    var progressFraction: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(progress) / Double(target))
    }

    var daysRemaining: Int {
        let comps = Calendar.current.dateComponents([.day], from: Date(), to: endDate)
        return max(0, comps.day ?? 0)
    }
}

struct SeasonalEventManager {
    static func seedCurrentSeasonIfNeeded(modelContext: ModelContext) {
        let activeEvents = (try? modelContext.fetch(FetchDescriptor<SeasonalEvent>())) ?? []
        guard activeEvents.isEmpty || activeEvents.allSatisfy({ $0.endDate < Date() }) else { return }

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate) ?? Date()
        let event = SeasonalEvent(
            eventId: "summer_smash_2026",
            title: "Summer Smash",
            subtitle: "Limited-time court challenges",
            descriptionText: "Play Rally for summer-themed rewards and nail timed court combos in the event season.",
            goalDescription: "Score 5000 points in event matches.",
            target: 5000,
            rewardCoins: 250,
            startDate: startDate,
            endDate: endDate
        )
        modelContext.insert(event)
        try? modelContext.save()
    }

    static func updateProgress(from result: GameResult, modelContext: ModelContext) {
        guard let event = (try? modelContext.fetch(FetchDescriptor<SeasonalEvent>()))?.first else { return }
        guard !event.isCompleted, event.endDate >= Date() else { return }

        event.progress += result.finalScore
        if event.progress >= event.target {
            event.isCompleted = true
        }
        try? modelContext.save()
    }
}
