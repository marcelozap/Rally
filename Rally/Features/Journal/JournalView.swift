import SwiftUI
import SwiftData

/// Journal content embedded inside **Logbook** (training + matches + journal).
struct JournalLogSection: View {
    @Binding var showComposer: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var filterFocus: JournalFocus?
    @State private var composerRoute: JournalComposerRoute?

    private var insights: JournalInsights {
        JournalInsights.compute(entries: entries)
    }

    private var filteredEntries: [JournalEntry] {
        guard let f = filterFocus else { return entries }
        return entries.filter { $0.focus == f }
    }

    private var timeline: [JournalTimeline.Section] {
        JournalTimeline.sections(from: filteredEntries)
    }

    private var featured: JournalPrompt {
        JournalPromptLibrary.featuredPrompt()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                insightsHeader
                featuredPromptCard
                filterChips
                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    timelineSections
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: showComposer) { _, show in
            if show { composerRoute = .blank; showComposer = false }
        }
        .sheet(item: $composerRoute) { route in
            NavigationStack {
                switch route {
                case .blank:
                    JournalEditorView(entry: nil)
                case .seeded(let prompt):
                    JournalEditorView(entry: nil, seedPrompt: prompt)
                }
            }
        }
    }

    // MARK: - Insights (streak card)

    private var insightsHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.35), Color.orange.opacity(0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                VStack(spacing: 4) {
                    Image(systemName: insights.journalingStreakDays > 0 ? "flame.fill" : "sparkles")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("\(insights.journalingStreakDays)")
                        .font(.system(.title, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                    Text("day streak")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.vertical, 14)
            }
            .frame(width: 110, height: 112)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your rhythm")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(insights.entriesThisWeek) this week · \(insights.entriesThisMonth) this month")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(insights.totalEntries) total entries")
                    .font(.caption)
                    .foregroundStyle(.cyan.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Featured prompt (daily inspiration)

    private var featuredPromptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.max.fill")
                    .foregroundStyle(.yellow)
                Text("Today's prompt")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(featured.focus.shortLabel.uppercased())
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.2)))
                    .foregroundStyle(.cyan)
            }
            Text(featured.title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text(featured.bodyStarter.trimmingCharacters(in: .newlines).prefix(120))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(3)

            Button {
                composerRoute = .seeded(featured)
            } label: {
                HStack {
                    Text("Write with this prompt")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                    Image(systemName: "arrow.right.circle.fill")
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cyan)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.06, green: 0.08, blue: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Filters

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "All")
                ForEach(JournalFocus.allCases) { focus in
                    filterChip(focus, label: focus.shortLabel)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(_ focus: JournalFocus?, label: String) -> some View {
        let selected = filterFocus == focus
        return Button {
            filterFocus = focus
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? Color.cyan.opacity(0.35) : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .stroke(selected ? Color.cyan : Color.white.opacity(0.12), lineWidth: 1)
                )
                .foregroundStyle(selected ? Color.black : Color.white.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeline

    private var timelineSections: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(timeline) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.title.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.38))
                    ForEach(section.entries) { entry in
                        NavigationLink {
                            JournalEditorView(entry: entry)
                        } label: {
                            JournalRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 52))
                .foregroundStyle(.cyan.opacity(0.55))
            Text(filterFocus == nil ? "Start your journal" : "Nothing in \(filterFocus!.shortLabel.lowercased()) yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text("Capture practice notes, match debriefs, and Rally sessions — one tap at a time.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal)

            Button {
                composerRoute = .seeded(featured)
            } label: {
                Text("Try today's prompt")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.cyan)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func delete(at offsets: IndexSet, from sectionEntries: [JournalEntry]) {
        for index in offsets {
            modelContext.delete(sectionEntries[index])
        }
        try? modelContext.save()
        RallySyncTriggers.pushAfterLocalSave(modelContext: modelContext)
    }
}

// MARK: - Composer routing

private enum JournalComposerRoute: Identifiable {
    case blank
    case seeded(JournalPrompt)

    var id: String {
        switch self {
        case .blank: return "blank"
        case .seeded(let p): return "seed-\(p.id)"
        }
    }
}

// MARK: - Row

private struct JournalRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(moodEmoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: entry.focus.symbolName)
                        .font(.caption)
                        .foregroundStyle(Color.cyan.opacity(0.85))
                    Text(entry.title.isEmpty ? "Untitled entry" : entry.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(entry.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.38))
                }

                if !entry.promptId.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.caption2)
                        Text("Guided")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.yellow.opacity(0.85))
                }

                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                }

                if !entry.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(entry.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2.weight(.medium))
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 8)
                                    .background(Capsule().fill(Color.cyan.opacity(0.14)))
                                    .foregroundStyle(.cyan.opacity(0.9))
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var moodEmoji: String {
        switch entry.mood {
        case 1: return "😞"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "🔥"
        }
    }
}
