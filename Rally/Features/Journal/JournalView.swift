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
                VStack(alignment: .leading, spacing: 28) {
                    insightsHeader
                    featuredPromptCard
                    filterChips
                    if filteredEntries.isEmpty {
                        emptyState
                    } else {
                        timelineSections
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(journalBackground)
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

    private var journalBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.03, blue: 0.07),
                    Color(red: 0.02, green: 0.02, blue: 0.04),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [RallyUIKit.Palette.rose.opacity(0.10), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [RallyUIKit.Palette.champagne.opacity(0.06), .clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 380
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.42)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var insightsHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            RallyUIKit.EditorialEyebrow(text: "Your rhythm", tint: RallyUIKit.Palette.rose)

            HStack(alignment: .bottom, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(insights.journalingStreakDays)")
                        .font(RallyUIKit.Typography.display(52, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text(insights.journalingStreakDays == 1 ? "day in a row" : "days in a row")
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.58))
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(insights.entriesThisWeek) this week")
                        .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.frost.opacity(0.82))
                    Text("\(insights.totalEntries) memories saved")
                        .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.46))
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // MARK: - Featured prompt (daily inspiration)

    private var featuredPromptCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                RallyUIKit.EditorialEyebrow(text: "Today's prompt", tint: RallyUIKit.Palette.champagne)
                Spacer()
                Text(featured.focus.shortLabel)
                    .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.52))
            }

            Text(featured.title)
                .font(RallyUIKit.Typography.display(24, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(featured.bodyStarter.trimmingCharacters(in: .newlines).prefix(140)))
                .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                .lineSpacing(4)
                .lineLimit(4)

            Button {
                composerRoute = .seeded(featured)
            } label: {
                HStack {
                    Text("Begin writing")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PrimaryButtonStyle(tint: RallyUIKit.Palette.rose))
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            RallyUIKit.Palette.rose.opacity(0.08),
                            Color.black.opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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
        LazyVStack(alignment: .leading, spacing: 28) {
            ForEach(timeline) { section in
                VStack(alignment: .leading, spacing: 14) {
                    Text(section.title)
                        .font(RallyUIKit.Typography.title(.subheadline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.48))
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
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.rose) {
            VStack(spacing: 18) {
                RallyUIKit.IconBadge(
                    systemName: "book.pages.fill",
                    tint: RallyUIKit.Palette.cyan,
                    size: 64
                )
                RallyUIKit.EditorialEyebrow(text: "Your tennis story", tint: RallyUIKit.Palette.rose)
                Text(filterFocus == nil ? "Your court diary" : "Nothing in \(filterFocus!.shortLabel.lowercased()) yet")
                    .font(RallyUIKit.Typography.display(24, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                    .multilineTextAlignment(.center)
                Text("Practice notes, match debriefs, quiet moments between sets.")
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                    .lineSpacing(4)
                    .padding(.horizontal, 8)

                Button {
                    composerRoute = .seeded(featured)
                } label: {
                    Label("Begin with today's prompt", systemImage: "pencil.line")
                }
                .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.rose))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .padding(.vertical, 12)
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
        VStack(alignment: .leading, spacing: 0) {
            if let previewImage {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 148)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 148)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title.isEmpty ? "Untitled" : entry.title)
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                            .lineLimit(2)
                        Text(entry.date, format: .dateTime.month(.wide).day().year())
                            .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                    }
                    .padding(16)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                if previewImage == nil {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.title.isEmpty ? "Untitled entry" : entry.title)
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Text(entry.date, format: .dateTime.month(.abbreviated).day())
                            .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.42))
                    }
                }

                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.68))
                        .lineLimit(previewImage == nil ? 3 : 2)
                        .lineSpacing(3)
                }

                HStack(spacing: 8) {
                    entryMetaTag(entry.focus.displayName, tint: focusTint)
                    if !entry.promptId.isEmpty {
                        entryMetaTag("Guided", tint: RallyUIKit.Palette.champagne, systemName: "sparkles")
                    }
                    Spacer(minLength: 0)
                    Text(moodEmoji)
                        .font(.body)
                }

                if !entry.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(entry.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 9)
                                    .background(Capsule().fill(Color.white.opacity(0.06)))
                                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .scrollClipDisabled()
                }
            }
            .padding(18)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
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
