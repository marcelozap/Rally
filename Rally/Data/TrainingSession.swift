import Foundation
import SwiftData

@Model
final class TrainingSession {
    var id: UUID = UUID()
    var date: Date = Date()
    /// Length of the session in minutes.
    var durationMinutes: Int = 60
    /// Free-form drill / focus area, e.g. "Backhand slice", "Serve practice".
    var drillType: String = ""
    /// 1 (recovery) … 5 (max effort).
    var intensity: Int = 3
    var notes: String = ""

    init(
        date: Date = Date(),
        durationMinutes: Int = 60,
        drillType: String = "",
        intensity: Int = 3,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.durationMinutes = durationMinutes
        self.drillType = drillType
        self.intensity = intensity
        self.notes = notes
    }
}
