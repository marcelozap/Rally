import Foundation
import SwiftData

enum JournalFocus: String, CaseIterable, Codable, Identifiable {
    case general
    case practice
    case match
    case rallyGame

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "Reflection"
        case .practice: return "Practice"
        case .match: return "Match"
        case .rallyGame: return "Rally game"
        }
    }

    var shortLabel: String {
        switch self {
        case .general: return "Note"
        case .practice: return "Practice"
        case .match: return "Match"
        case .rallyGame: return "Game"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "leaf.fill"
        case .practice: return "figure.run"
        case .match: return "trophy.fill"
        case .rallyGame: return "tennis.racket"
        }
    }
}

@Model
final class JournalEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var title: String = ""
    var body: String = ""
    var mood: Int = 3
    var tagsCSV: String = ""
    var focusRaw: String = JournalFocus.general.rawValue
    var promptId: String = ""

    init(
        date: Date = Date(),
        title: String = "",
        body: String = "",
        mood: Int = 3,
        tags: [String] = [],
        focus: JournalFocus = .general,
        promptId: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.title = title
        self.body = body
        self.mood = mood
        self.tagsCSV = tags.joined(separator: ",")
        self.focusRaw = focus.rawValue
        self.promptId = promptId
    }

    var tags: [String] {
        get {
            tagsCSV
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set { tagsCSV = newValue.joined(separator: ",") }
    }

    var focus: JournalFocus {
        get { JournalFocus(rawValue: focusRaw) ?? .general }
        set { focusRaw = newValue.rawValue }
    }
}
