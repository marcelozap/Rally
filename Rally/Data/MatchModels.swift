import Foundation
import SwiftData

enum CourtSurface: String, CaseIterable, Codable, Identifiable {
    case hard, clay, grass, carpet, indoor
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .hard: return "Hard"
        case .clay: return "Clay"
        case .grass: return "Grass"
        case .carpet: return "Carpet"
        case .indoor: return "Indoor"
        }
    }
}

@Model
final class MatchEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var opponentName: String = ""
    var location: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    /// Stored as `CourtSurface.rawValue` for SwiftData friendliness.
    var surfaceRaw: String = CourtSurface.hard.rawValue
    var resultWon: Bool = false
    /// Encoded as `"6-4,4-6,7-5"` so SwiftData stays simple — no relationship.
    var setsCSV: String = ""
    var notes: String = ""

    init(
        date: Date = Date(),
        opponentName: String = "",
        location: String = "",
        photoData: Data? = nil,
        surface: CourtSurface = .hard,
        resultWon: Bool = false,
        sets: [SetScore] = [],
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.opponentName = opponentName
        self.location = location
        self.photoData = photoData
        self.surfaceRaw = surface.rawValue
        self.resultWon = resultWon
        self.setsCSV = SetScore.encode(sets)
        self.notes = notes
    }

    var surface: CourtSurface {
        get { CourtSurface(rawValue: surfaceRaw) ?? .hard }
        set { surfaceRaw = newValue.rawValue }
    }

    var sets: [SetScore] {
        get { SetScore.decode(setsCSV) }
        set { setsCSV = SetScore.encode(newValue) }
    }

    var scoreDisplay: String {
        sets.map { $0.display }.joined(separator: ", ")
    }
}

/// A single set's score. Tiebreak optional, stored as `6-7(3)`.
struct SetScore: Hashable, Codable {
    var won: Int
    var lost: Int
    /// Tiebreak points the loser scored, or nil for a non-tiebreak set.
    var tiebreak: Int?

    var display: String {
        if let tb = tiebreak {
            return "\(won)-\(lost)(\(tb))"
        }
        return "\(won)-\(lost)"
    }

    static func encode(_ sets: [SetScore]) -> String {
        sets.map { set in
            if let tb = set.tiebreak {
                return "\(set.won)-\(set.lost)t\(tb)"
            }
            return "\(set.won)-\(set.lost)"
        }.joined(separator: ",")
    }

    static func decode(_ csv: String) -> [SetScore] {
        guard !csv.isEmpty else { return [] }
        return csv.split(separator: ",").compactMap { raw -> SetScore? in
            let parts = raw.split(separator: "-")
            guard parts.count == 2, let won = Int(parts[0]) else { return nil }
            let tail = parts[1]
            if let tIdx = tail.firstIndex(of: "t") {
                let lost = Int(tail[..<tIdx]) ?? 0
                let tb = Int(tail[tail.index(after: tIdx)...])
                return SetScore(won: won, lost: lost, tiebreak: tb)
            }
            return SetScore(won: won, lost: Int(tail) ?? 0, tiebreak: nil)
        }
    }
}
