import Foundation
import SwiftData

// MARK: - Training session

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

// MARK: - Match entry

enum CourtSurface: String, CaseIterable, Codable, Identifiable {
    case hard, clay, grass, carpet, indoor
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .hard:   return "Hard"
        case .clay:   return "Clay"
        case .grass:  return "Grass"
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
        surface: CourtSurface = .hard,
        resultWon: Bool = false,
        sets: [SetScore] = [],
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.opponentName = opponentName
        self.location = location
        self.surfaceRaw = surface.rawValue
        self.resultWon = resultWon
        self.setsCSV = SetScore.encode(sets)
        self.notes = notes
    }

    // MARK: Convenience accessors

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

// MARK: - Journal entry

@Model
final class JournalEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var title: String = ""
    var body: String = ""
    /// 1 (low) … 5 (high).
    var mood: Int = 3
    /// Comma-separated tags, e.g. "serve,mental,coach-feedback".
    var tagsCSV: String = ""

    init(
        date: Date = Date(),
        title: String = "",
        body: String = "",
        mood: Int = 3,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.date = date
        self.title = title
        self.body = body
        self.mood = mood
        self.tagsCSV = tags.joined(separator: ",")
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
}

// MARK: - Avatar config

@Model
final class AvatarConfig {
    var id: UUID = UUID()
    /// Empty on a fresh install so the first-launch customizer forces the
    /// player to type their own name. The customizer re-applies "Player" as
    /// a defensive fallback if they save without entering one.
    var playerName: String = ""
    var skinToneRaw: String = AvatarSkinTone.medium.rawValue
    var hairStyleRaw: String = AvatarHairStyle.short.rawValue
    var hairColorHex: String = "#3A2A1A"   // brown
    var bodyTypeRaw: String = AvatarBodyType.athletic.rawValue

    /// Equipped shop item IDs, keyed by category. Use the constants in
    /// `ShopCatalog.defaults` as fallbacks.
    var equippedTopID: String = ShopCatalog.defaultTopID
    var equippedBottomID: String = ShopCatalog.defaultBottomID
    var equippedShoesID: String = ShopCatalog.defaultShoesID
    var equippedRacketID: String = ShopCatalog.defaultRacketID

    /// True once the user has completed the first-launch customizer.
    var hasCompletedSetup: Bool = false

    init() {
        self.id = UUID()
    }

    var skinTone: AvatarSkinTone {
        get { AvatarSkinTone(rawValue: skinToneRaw) ?? .medium }
        set { skinToneRaw = newValue.rawValue }
    }

    var hairStyle: AvatarHairStyle {
        get { AvatarHairStyle(rawValue: hairStyleRaw) ?? .short }
        set { hairStyleRaw = newValue.rawValue }
    }

    var bodyType: AvatarBodyType {
        get { AvatarBodyType(rawValue: bodyTypeRaw) ?? .athletic }
        set { bodyTypeRaw = newValue.rawValue }
    }
}

enum AvatarSkinTone: String, CaseIterable, Identifiable {
    case fair, light, medium, tan, deep, rich
    var id: String { rawValue }
    var hex: String {
        switch self {
        case .fair:   return "#F5D6BB"
        case .light:  return "#E0B79A"
        case .medium: return "#C58F66"
        case .tan:    return "#A06B40"
        case .deep:   return "#6D4326"
        case .rich:   return "#3D2718"
        }
    }
    var displayName: String { rawValue.capitalized }
}

enum AvatarHairStyle: String, CaseIterable, Identifiable {
    case bald, short, medium, long, ponytail, bun
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum AvatarBodyType: String, CaseIterable, Identifiable {
    case slim, athletic, strong
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
