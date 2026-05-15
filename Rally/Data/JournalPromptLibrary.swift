import Foundation

/// Guided prompts inspired by popular journaling apps (**Day One** daily prompts,
/// **Journey** templates, **Reflectly** check-ins) — localized to tennis practice,
/// matches, and Rally rhythm sessions.
struct JournalPrompt: Identifiable, Hashable {
    let id: String
    let focus: JournalFocus
    /// Short headline shown in the editor / cards.
    let title: String
    /// Prefilled body starter the user can edit freely.
    let bodyStarter: String
}

enum JournalPromptLibrary {

    static let allPrompts: [JournalPrompt] = [
        // Reflection (general)
        .init(id: "g.gratitude", focus: .general, title: "Three wins today",
              bodyStarter: "On and off the court, three things that went well today:\n1.\n2.\n3.\n"),
        .init(id: "g.headspace", focus: .general, title: "Where my head is",
              bodyStarter: "Honestly, today I felt ___ because ___.\nWhat I need tomorrow is ___."),
        .init(id: "g.identity", focus: .general, title: "The player I'm becoming",
              bodyStarter: "One habit I'm proud of lately:\nOne habit I want to tighten:\n"),

        // Practice
        .init(id: "p.drill", focus: .practice, title: "Today's drill focus",
              bodyStarter: "Drill / theme:\nWhat clicked:\nWhat felt off:\nOne cue I'll remember next time:\n"),
        .init(id: "p.intensity", focus: .practice, title: "Effort & recovery",
              bodyStarter: "Session length / intensity (1–10):\nBody feedback:\nSleep / fuel notes:\n"),
        .init(id: "p.technical", focus: .practice, title: "Stroke notebook",
              bodyStarter: "Shot or pattern I worked:\nFilm or coach feedback:\nFeel vs reality:\n"),

        // Match
        .init(id: "m.post", focus: .match, title: "Post-match debrief",
              bodyStarter: "Opponent / surface:\nScore:\nWhat worked tactically:\nWhat broke down:\nNext adjustment:\n"),
        .init(id: "m.mental", focus: .match, title: "Pressure moments",
              bodyStarter: "Key pressure point(s):\nWhat I told myself:\nWhat I'd repeat / change:\n"),
        .init(id: "m.pattern", focus: .match, title: "Patterns I saw",
              bodyStarter: "Their patterns:\nHow I attacked / defended:\nShot I want more of next time:\n"),

        // Rally game (rhythm / mental)
        .init(id: "r.session", focus: .rallyGame, title: "Rally session log",
              bodyStarter: "Rough score / combo high:\nFlow state (1–10):\nWhen I lost rhythm:\n"),
        .init(id: "r.focus", focus: .rallyGame, title: "Focus under speed",
              bodyStarter: "What broke my combo:\nWhat helped me lock in:\nOne mental cue for next run:\n"),
        .init(id: "r.fun", focus: .rallyGame, title: "Why I played",
              bodyStarter: "Tonight I opened Rally because ___.\nMost satisfying moment:\n"),
    ]

    static func prompts(for focus: JournalFocus) -> [JournalPrompt] {
        allPrompts.filter { $0.focus == focus }
    }

    /// Build a Rally-focus prompt seeded with the freshly-completed run's
    /// numbers. Drives the "Log how it felt" CTA on `GameOverView` so the
    /// player can drop into journal flow without retyping the basics.
    static func sessionReflectionPrompt(for result: GameResult, outcome: Rewards.Outcome) -> JournalPrompt {
        let accuracyPct = Int((result.accuracy * 100).rounded())
        var lines: [String] = [
            "Score: \(result.finalScore)",
            "Max combo: \(result.maxCombo)",
            "Accuracy: \(accuracyPct)% (Perfects: \(result.perfectHits))"
        ]
        if result.segments.count == 3 {
            lines.append("Shape: \(result.narrativeHeadline)")
        }
        if outcome.isNewBestScore {
            lines.append("This was a new personal best.")
        } else if outcome.didLevelUp {
            lines.append("Levelled up to Lv. \(outcome.newLevel).")
        }
        lines.append("")
        lines.append("Flow state (1-10):")
        lines.append("When I lost rhythm:")
        lines.append("One cue for next session:")

        return JournalPrompt(
            id: "r.session.auto",
            focus: .rallyGame,
            title: "After a Rally session",
            bodyStarter: lines.joined(separator: "\n")
        )
    }

    /// Deterministic “prompt of the day” — same calendar day → same prompt for a focus.
    static func dailyPrompt(for date: Date = Date(), focus: JournalFocus = .general) -> JournalPrompt {
        let list = prompts(for: focus)
        guard !list.isEmpty else {
            return allPrompts[0]
        }
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let ord = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        let salt = focus.rawValue.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let idx = (y * 367 + ord + salt) % list.count
        return list[idx]
    }

    /// Featured card on the journal home — rotates focus across the week (Journey-style variety).
    static func featuredPrompt(for date: Date = Date()) -> JournalPrompt {
        let cycle: [JournalFocus] = [.practice, .match, .rallyGame, .general]
        let weekday = Calendar.current.component(.weekday, from: date)
        let f = cycle[(weekday - 1 + cycle.count) % cycle.count]
        return dailyPrompt(for: date, focus: f)
    }

    static func prompt(id: String) -> JournalPrompt? {
        allPrompts.first { $0.id == id }
    }
}

// MARK: - Insights (streak / weekly counts — computed from entries)

struct JournalInsights: Equatable {
    /// Consecutive days with at least one entry, anchored from today or yesterday.
    var journalingStreakDays: Int
    var entriesThisWeek: Int
    var entriesThisMonth: Int
    var totalEntries: Int

    static func compute(entries: [JournalEntry], now: Date = Date(), calendar: Calendar = .current) -> JournalInsights {
        let total = entries.count
        guard total > 0 else {
            return JournalInsights(journalingStreakDays: 0, entriesThisWeek: 0, entriesThisMonth: 0, totalEntries: 0)
        }

        let days = Set(entries.map { calendar.startOfDay(for: $0.date) })

        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while days.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        let weekCount = entries.filter { $0.date >= startOfWeek }.count
        let monthCount = entries.filter { $0.date >= startOfMonth }.count

        return JournalInsights(
            journalingStreakDays: streak,
            entriesThisWeek: weekCount,
            entriesThisMonth: monthCount,
            totalEntries: total
        )
    }
}

// MARK: - Timeline grouping (month sections like Day One)

enum JournalTimeline {
    struct Section: Identifiable {
        var id: String { titleKey }
        let titleKey: String
        let title: String
        let entries: [JournalEntry]
    }

    static func sections(from entries: [JournalEntry], calendar: Calendar = .current) -> [Section] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: entries) { entry -> String in
            let c = calendar.dateComponents([.year, .month], from: entry.date)
            guard let y = c.year, let m = c.month else { return "0000-00" }
            return String(format: "%04d-%02d", y, m)
        }

        let sortedKeys = grouped.keys.sorted(by: >)

        return sortedKeys.compactMap { key in
            guard let list = grouped[key], let first = list.first else { return nil }
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: first.date)) ?? first.date
            return Section(
                titleKey: key,
                title: formatter.string(from: monthStart),
                entries: list.sorted { $0.date > $1.date }
            )
        }
    }
}
