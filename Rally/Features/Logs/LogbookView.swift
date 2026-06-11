import SwiftUI
import SwiftData

/// Combined training, match, and journal history — one unified tennis-life destination.
struct LogbookView: View {
    @Binding var section: LogbookSection
    var title: String = "Journal"
    @State private var showJournalComposer = false
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainingSessions: [TrainingSession]
    @Query(sort: \MatchEntry.date, order: .reverse) private var matches: [MatchEntry]
    @Query(sort: \JournalEntry.date, order: .reverse) private var journalEntries: [JournalEntry]
    private let sectionOrder: [LogbookSection] = [.journal, .training, .matches]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RallyUIKit.SectionCard(stroke: activeTint.opacity(0.24)) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            RallyUIKit.IconBadge(
                                systemName: section.iconName,
                                tint: activeTint,
                                size: 36
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Tennis life")
                                    .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                                    .foregroundStyle(RallyUIKit.Palette.frost)
                                Text(sectionDescription)
                                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.58))
                            }
                        }

                        HStack(spacing: 10) {
                            ForEach(sectionOrder) { value in
                                sectionButton(value)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if let summary = practiceSummary {
                    practiceSummaryCard(summary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                if !recentMoments.isEmpty {
                    mixedMomentsCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                switch section {
                case .training:
                    TrainingLogView()
                case .matches:
                    MatchLogView()
                case .journal:
                    JournalView()
                }
            }
            .background(
                ZStack {
                    RallyUIKit.screenBackground
                    LinearGradient(
                        colors: [
                            activeTint.opacity(section == .journal ? 0.10 : 0.06),
                            Color.clear,
                            RallyUIKit.Palette.obsidian.opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .ignoresSafeArea()
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        if section == .journal {
                            Button {
                                showJournalComposer = true
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .foregroundStyle(.cyan)
                            }
                        }
                        SoundToggleButton()
                    }
                }
            }
        }
        .sheet(isPresented: $showJournalComposer) {
            NavigationStack {
                JournalEditorView(entry: nil)
            }
        }
    }

    private var activeTint: Color {
        switch section {
        case .training: return RallyUIKit.Palette.gold
        case .matches: return RallyUIKit.Palette.cyan
        case .journal: return RallyUIKit.Palette.rose
        }
    }

    private var sectionDescription: String {
        switch section {
        case .training:
            return "Training leads this journal so practice, volume, and focus stay front and center."
        case .matches:
            return "Scores, memory, and match pressure once the court time turns competitive."
        case .journal:
            return "Reflections, guided notes, and the inner side of your tennis life."
        }
    }

    private var recentMoments: [LogbookMoment] {
        let moments =
            trainingSessions.prefix(1).map { LogbookMoment(training: $0) } +
            matches.prefix(1).map { LogbookMoment(match: $0) } +
            journalEntries.prefix(1).map { LogbookMoment(journal: $0) }

        return moments
            .sorted { $0.date > $1.date }
            .prefix(3)
            .map { $0 }
    }

    private var practiceSummary: PracticeSummary? {
        guard let latestMatch = matches.first else { return nil }
        let weekBeforeMatch = Calendar.current.date(byAdding: .day, value: -7, to: latestMatch.date) ?? latestMatch.date
        let leadupSessions = trainingSessions.filter { $0.date >= weekBeforeMatch && $0.date < latestMatch.date }
        guard !leadupSessions.isEmpty else { return nil }
        let minutes = leadupSessions.reduce(0) { $0 + $1.durationMinutes }
        return PracticeSummary(
            matchDate: latestMatch.date,
            minutes: minutes,
            sessions: leadupSessions.count
        )
    }

    private func practiceSummaryCard(_ summary: PracticeSummary) -> some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.gold) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        RallyUIKit.EditorialEyebrow(text: "Practice lead-in", tint: RallyUIKit.Palette.gold)
                        Text("\(summary.minutes) minutes before your latest match")
                            .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("\(summary.sessions) training session\(summary.sessions == 1 ? "" : "s") in the seven days before match day")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.6))
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(summary.matchDate, format: .dateTime.month(.abbreviated).day())
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.gold)
                        Text("match")
                            .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.38))
                    }
                }
            }
        }
    }

    private var mixedMomentsCard: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.frost) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        RallyUIKit.EditorialEyebrow(text: "Recent tennis life", tint: RallyUIKit.Palette.frost)
                        Text("Matches, practice, and memories together")
                            .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("A single look at what’s been happening lately, instead of bouncing between separate histories.")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                    }

                    Spacer(minLength: 8)

                    RallyUIKit.IconBadge(
                        systemName: "square.stack.3d.up.fill",
                        tint: RallyUIKit.Palette.frost,
                        size: 34
                    )
                }

                VStack(spacing: 10) {
                    ForEach(recentMoments) { moment in
                        momentRow(moment)
                    }
                }
            }
        }
    }

    private func sectionButton(_ value: LogbookSection) -> some View {
        let selected = value == section
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                section = value
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: value.iconName)
                    .font(.system(size: 12, weight: .bold))
                Text(value.displayName)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Color.black : RallyUIKit.Palette.frost.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? AnyShapeStyle(RallyUIKit.accentGradient(tint(for: value))) : AnyShapeStyle(Color.white.opacity(0.05)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? Color.white.opacity(0.26) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: selected ? tint(for: value).opacity(0.18) : .clear, radius: 12, x: 0, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func tint(for value: LogbookSection) -> Color {
        switch value {
        case .training: return RallyUIKit.Palette.gold
        case .matches: return RallyUIKit.Palette.cyan
        case .journal: return RallyUIKit.Palette.rose
        }
    }

    private func momentRow(_ moment: LogbookMoment) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                section = moment.section
            }
        } label: {
            HStack(spacing: 12) {
                RallyUIKit.IconBadge(
                    systemName: moment.iconName,
                    tint: moment.tint,
                    size: 28
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(moment.title)
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        .lineLimit(1)

                    Text(moment.subtitle)
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.56))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(moment.date, style: .relative)
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .foregroundStyle(moment.tint.opacity(0.92))
                    Text(moment.section.displayName)
                        .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.36))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PracticeSummary {
    let matchDate: Date
    let minutes: Int
    let sessions: Int
}

enum LogbookSection: String, CaseIterable, Identifiable, Hashable {
    case training
    case matches
    case journal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .training: return "Training"
        case .matches:  return "Matches"
        case .journal:  return "Journal"
        }
    }

    var iconName: String {
        switch self {
        case .training: return "figure.tennis"
        case .matches: return "trophy.fill"
        case .journal: return "book.pages.fill"
        }
    }
}

private struct LogbookMoment: Identifiable {
    let id: String
    let section: LogbookSection
    let title: String
    let subtitle: String
    let date: Date
    let tint: Color
    let iconName: String

    init(training: TrainingSession) {
        let focus = training.drillType.isEmpty ? "Court session" : training.drillType
        self.id = "training-\(training.id.uuidString)"
        self.section = .training
        self.title = focus
        self.subtitle = "\(training.durationMinutes) min · Intensity \(training.intensity)"
        self.date = training.date
        self.tint = RallyUIKit.Palette.cyan
        self.iconName = "figure.tennis"
    }

    init(match: MatchEntry) {
        self.id = "match-\(match.id.uuidString)"
        self.section = .matches
        self.title = match.opponentName.isEmpty ? "Match day" : "vs \(match.opponentName)"
        self.subtitle = match.scoreDisplay.isEmpty ? match.surface.displayName : "\(match.scoreDisplay) · \(match.surface.displayName)"
        self.date = match.date
        self.tint = RallyUIKit.Palette.gold
        self.iconName = match.resultWon ? "sparkles" : "trophy.fill"
    }

    init(journal: JournalEntry) {
        self.id = "journal-\(journal.id.uuidString)"
        self.section = .journal
        self.title = journal.title.isEmpty ? "Journal note" : journal.title
        let bodyPreview = journal.body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subtitle = bodyPreview.isEmpty ? journal.focus.displayName : bodyPreview
        self.date = journal.date
        self.tint = RallyUIKit.Palette.rose
        self.iconName = journal.focus.symbolName
    }
}
