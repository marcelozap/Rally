import SwiftUI
import SwiftData

/// Journal tab styled after popular apps (**Day One** timeline + daily inspiration,
/// **Journey** guided templates, **Reflectly** streaks) — scoped to tennis practice,
/// matches, and Rally rhythm play.
struct JournalView: View {
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
        NavigationStack {
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
            .background(RallyUIKit.screenBackground)
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        composerRoute = .blank
                    } label: {
                        RallyUIKit.IconBadge(
                            systemName: "square.and.pencil",
                            tint: RallyUIKit.Palette.cyan,
                            size: 34
                        )
                    }
                }
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
    }

    // MARK: - Insights (streak card)

    private var insightsHeader: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.rose) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [RallyUIKit.Palette.rose.opacity(0.48), RallyUIKit.Palette.gold.opacity(0.24)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(spacing: 6) {
                        RallyUIKit.IconBadge(
                            systemName: insights.journalingStreakDays > 0 ? "flame.fill" : "sparkles",
                            tint: RallyUIKit.Palette.gold,
                            size: 34
                        )
                        Text("\(insights.journalingStreakDays)")
                            .font(.system(.title, design: .rounded).weight(.heavy))
                            .foregroundStyle(.white)
                        Text("day streak")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.vertical, 14)
                }
                .frame(width: 110, height: 116)

                VStack(alignment: .leading, spacing: 8) {
                    RallyUIKit.EditorialEyebrow(text: "Your rhythm", tint: RallyUIKit.Palette.rose)
                    Text("\(insights.entriesThisWeek) this week · \(insights.entriesThisMonth) this month")
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text("\(insights.totalEntries) total entries")
                        .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.88))
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Featured prompt (daily inspiration)

    private var featuredPromptCard: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RallyUIKit.IconBadge(
                        systemName: "lightbulb.max.fill",
                        tint: RallyUIKit.Palette.gold,
                        size: 28
                    )
                    RallyUIKit.EditorialEyebrow(text: "Today's prompt", tint: RallyUIKit.Palette.cyan)
                    Spacer()
                    Text(featured.focus.shortLabel.uppercased())
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(RallyUIKit.Palette.cyan.opacity(0.18)))
                        .foregroundStyle(RallyUIKit.Palette.cyan)
                }

                Text(featured.title)
                    .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(String(featured.bodyStarter.trimmingCharacters(in: .newlines).prefix(120)))
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.58))
                    .lineLimit(3)

                Button {
                    composerRoute = .seeded(featured)
                } label: {
                    HStack {
                        Text("Write with this prompt")
                        Image(systemName: "arrow.right.circle.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: RallyUIKit.Palette.cyan))
            }
        }
    }

    // MARK: - Filters

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(nil, label: "All")
                ForEach(JournalFocus.allCases) { focus in
                    filterChip(focus, label: focus.shortLabel)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
    }

    private func filterChip(_ focus: JournalFocus?, label: String) -> some View {
        let selected = filterFocus == focus
        return Button {
            filterFocus = focus
        } label: {
            HStack(spacing: 6) {
                if let focus {
                    Image(systemName: focus.symbolName)
                        .font(.system(size: 12, weight: .bold))
                }
                Text(label)
                    .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? AnyShapeStyle(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan)) : AnyShapeStyle(Color.white.opacity(0.06)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? Color.white.opacity(0.26) : Color.white.opacity(0.10), lineWidth: 1)
            )
            .foregroundStyle(selected ? Color.black : RallyUIKit.Palette.frost.opacity(0.88))
            .shadow(color: selected ? RallyUIKit.Palette.cyan.opacity(0.2) : .clear, radius: 12, x: 0, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeline

    private var timelineSections: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(timeline) { section in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Capsule()
                            .fill(RallyUIKit.Palette.cyan.opacity(0.82))
                            .frame(width: 18, height: 4)
                        Text(section.title.uppercased())
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.42))
                    }
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
            RallyUIKit.IconBadge(
                systemName: "book.pages.fill",
                tint: RallyUIKit.Palette.cyan,
                size: 72
            )
            Text(filterFocus == nil ? "Start your journal" : "Nothing in \(filterFocus!.shortLabel.lowercased()) yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text("Capture practice notes, match debriefs, and Rally sessions — one tap at a time.")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.52))
                .padding(.horizontal)

            Button {
                composerRoute = .seeded(featured)
            } label: {
                Label("Try today's prompt", systemImage: "wand.and.stars")
            }
            .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.cyan))
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
            ZStack {
                Circle()
                    .fill(moodTint.opacity(0.18))
                Text(moodEmoji)
                    .font(.title3)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: entry.focus.symbolName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(focusTint.opacity(0.9))
                    Text(entry.title.isEmpty ? "Untitled entry" : entry.title)
                        .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(entry.date, format: .dateTime.month(.abbreviated).day())
                        .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.4))
                }

                HStack(spacing: 8) {
                    entryMetaTag(entry.focus.displayName, tint: focusTint)
                    if !entry.promptId.isEmpty {
                        entryMetaTag("Guided", tint: RallyUIKit.Palette.gold, systemName: "wand.and.stars")
                    }
                }

                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.66))
                        .lineLimit(2)
                }

                if let previewImage {
                    ZStack(alignment: .bottomLeading) {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 118)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                LinearGradient(
                                    colors: [Color.clear, Color.black.opacity(0.38)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        HStack(spacing: 6) {
                            Image(systemName: "photo.fill")
                                .font(.caption2.weight(.bold))
                            Text("Saved memory")
                                .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(Color.black.opacity(0.34))
                        )
                        .padding(10)
                    }
                }

                if !entry.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(entry.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 9)
                                    .background(Capsule().fill(RallyUIKit.Palette.cyan.opacity(0.12)))
                                    .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.92))
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .scrollClipDisabled()
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.28))
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 5)
    }

    private func entryMetaTag(_ text: String, tint: Color, systemName: String? = nil) -> some View {
        HStack(spacing: 5) {
            if let systemName {
                Image(systemName: systemName)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(tint.opacity(0.12))
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .foregroundStyle(tint.opacity(0.92))
    }

    private var focusTint: Color {
        switch entry.focus {
        case .general: return RallyUIKit.Palette.lime
        case .practice: return RallyUIKit.Palette.cyan
        case .match: return RallyUIKit.Palette.gold
        case .rallyGame: return RallyUIKit.Palette.rose
        }
    }

    private var moodTint: Color {
        switch entry.mood {
        case 1: return RallyUIKit.Palette.rose
        case 2: return RallyUIKit.Palette.gold
        case 3: return RallyUIKit.Palette.cloud
        case 4: return RallyUIKit.Palette.cyan
        default: return RallyUIKit.Palette.lime
        }
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

    private var previewImage: UIImage? {
        guard let data = entry.photoData else { return nil }
        return UIImage(data: data)
    }
}
