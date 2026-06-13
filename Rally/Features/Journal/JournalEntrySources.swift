import Foundation
import SwiftData

// MARK: - Source kinds

/// Where a journal entry came from. Persisted on `JournalEntry.sourceRaw`
/// so the Journal can filter, badge, and dedupe by provenance.
///
/// North Star §Journal: "Garmin integration should be architected behind a
/// source protocol: manual entries, in-app rally entries, future Garmin
/// imports. Build now with stubs; plug real Garmin API after approval."
enum JournalEntrySourceKind: String, Codable, CaseIterable {
    case manual
    case rallySession
    case garminImport

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .rallySession: return "Rally session"
        case .garminImport: return "Garmin"
        }
    }
}

// MARK: - Entry draft

/// Value-type payload a source produces. The auto-logger turns drafts into
/// persisted `JournalEntry` rows; keeping the draft separate from the
/// SwiftData model lets future sources (Garmin) run off the main actor.
struct JournalEntryDraft {
    var date: Date
    var title: String
    var body: String
    var mood: Int
    var tags: [String]
    var focus: JournalFocus
    var source: JournalEntrySourceKind
    // Structured rally metrics — nil for manual/Garmin drafts
    var rallyScore: Int? = nil
    var rallyMaxCombo: Int? = nil
    var rallyAccuracyPct: Int? = nil
}

// MARK: - Source protocol

/// A provider of journal entries. Conformers:
/// - `RallySessionJournalSource` — wraps a finished in-app `GameResult`.
/// - `GarminJournalSource` — stub; returns nothing until the Garmin
///   Connect API integration is approved and keys exist.
/// Manual entries don't need a source — `JournalEditorView` writes the
/// model directly with `sourceRaw = .manual`.
protocol JournalEntrySource {
    var kind: JournalEntrySourceKind { get }
    func makeDrafts() -> [JournalEntryDraft]
}

// MARK: - Rally session source

/// Builds one journal draft from a finished wall-rally session.
struct RallySessionJournalSource: JournalEntrySource {
    let result: GameResult
    let endedAt: Date

    var kind: JournalEntrySourceKind { .rallySession }

    func makeDrafts() -> [JournalEntryDraft] {
        // Don't journal a session with no swings — opening the play screen
        // and immediately exiting is not tennis history.
        guard result.totalHits + result.misses > 0 else { return [] }

        let accuracyPct = Int((result.accuracy * 100).rounded())
        let title = "Wall Rally — \(result.finalScore) pts"

        var lines: [String] = [
            "Score \(result.finalScore) · Best combo ×\(result.maxCombo) · \(accuracyPct)% accuracy.",
            "Perfect \(result.perfectHits) · Great \(result.greatHits) · Good \(result.goodHits) · Miss \(result.misses)."
        ]

        // Segment breakdown: early / mid / late third of the session
        let labels = ["Early", "Mid", "Late"]
        let segs = result.segments
        if segs.count == 3 {
            let breakdown = segs.enumerated().map { i, seg in
                let pct = Int((seg.accuracy * 100).rounded())
                return "\(labels[i]) \(pct)%"
            }.joined(separator: " · ")
            lines.append("Thirds: \(breakdown).")
        }

        // Narrative tag: clutch finish, strong start, or flat session
        if segs.count == 3 {
            let lateAcc  = segs[2].accuracy
            let earlyAcc = segs[0].accuracy
            if lateAcc >= 0.85 && lateAcc > earlyAcc + 0.15 {
                lines.append("Clutch finish — best in the final third.")
            } else if earlyAcc >= 0.85 && earlyAcc > lateAcc + 0.15 {
                lines.append("Strong opener, faded late — work on sustaining focus.")
            }
        }

        let body = lines.joined(separator: "\n")

        return [JournalEntryDraft(
            date: endedAt,
            title: title,
            body: body,
            mood: Self.mood(for: result),
            tags: ["auto", "wall-rally"],
            focus: .rallyGame,
            source: .rallySession,
            rallyScore: result.finalScore,
            rallyMaxCombo: result.maxCombo,
            rallyAccuracyPct: Int((result.accuracy * 100).rounded())
        )]
    }

    /// Simple deterministic mood read from the run: neutral baseline,
    /// brighter for accurate or high-combo runs, dimmer for rough ones.
    private static func mood(for result: GameResult) -> Int {
        if result.accuracy >= 0.85 && result.maxCombo >= 15 { return 5 }
        if result.accuracy >= 0.70 { return 4 }
        if result.accuracy < 0.40 { return 2 }
        return 3
    }
}

// MARK: - Garmin source (stub)

/// Placeholder until Garmin Connect API access is approved. Architecture
/// contract: when real, this fetches activities since the last import and
/// maps them to drafts with `source: .garminImport`. Returns nothing today
/// so it is safe to register unconditionally.
struct GarminJournalSource: JournalEntrySource {
    var kind: JournalEntrySourceKind { .garminImport }

    func makeDrafts() -> [JournalEntryDraft] {
        // TODO(Garmin): exchange OAuth token, pull tennis activities,
        // map to JournalEntryDraft. Blocked on API approval.
        []
    }
}

// MARK: - Auto-logger

/// Persists drafts from a source into SwiftData. Called from the session
/// end path so every played rally session creates a useful Journal entry
/// (North Star exit test: "A played session creates a useful entry").
@MainActor
enum JournalAutoLogger {

    static func logRallySession(result: GameResult, modelContext: ModelContext) {
        persist(
            drafts: RallySessionJournalSource(result: result, endedAt: Date()).makeDrafts(),
            modelContext: modelContext
        )
    }

    static func persist(drafts: [JournalEntryDraft], modelContext: ModelContext) {
        guard !drafts.isEmpty else { return }
        for draft in drafts {
            let entry = JournalEntry(
                date: draft.date,
                title: draft.title,
                body: draft.body,
                mood: draft.mood,
                tags: draft.tags,
                focus: draft.focus
            )
            entry.sourceRaw = draft.source.rawValue
            entry.rallyScore = draft.rallyScore
            entry.rallyMaxCombo = draft.rallyMaxCombo
            entry.rallyAccuracyPct = draft.rallyAccuracyPct
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }
}
