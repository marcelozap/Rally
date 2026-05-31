import SwiftUI
import SwiftData

struct TrainingLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            weeklySummary
                            storyBridge

                            VStack(spacing: 12) {
                                ForEach(sessions) { session in
                                    NavigationLink {
                                        TrainingEditorView(session: session)
                                    } label: {
                                        TrainingRow(session: session)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                    }
                }
            }
            .background(RallyUIKit.screenBackground)
            .navigationTitle("Training")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: {
                        RallyUIKit.IconBadge(
                            systemName: "plus",
                            tint: RallyUIKit.Palette.cyan,
                            size: 34
                        )
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack {
                    TrainingEditorView(session: nil)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            RallyUIKit.IconBadge(
                systemName: "figure.tennis",
                tint: RallyUIKit.Palette.cyan,
                size: 72
            )
            Text("No training logged yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text("Tap + to log your first session.")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var weeklySummary: some View {
        let cal = Calendar.current
        let lastWeek = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = sessions.filter { $0.date >= lastWeek }
        let totalMinutes = recent.reduce(0) { $0 + $1.durationMinutes }
        let totalSessions = recent.count
        return RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: 14) {
                RallyUIKit.EditorialEyebrow(text: "7-day training cadence", tint: RallyUIKit.Palette.cyan)
                HStack(spacing: 24) {
                    stat(value: "\(totalSessions)", label: "sessions", tint: RallyUIKit.Palette.cyan)
                    stat(value: "\(totalMinutes)", label: "minutes", tint: RallyUIKit.Palette.lime)
                    stat(value: "7d", label: "window", tint: RallyUIKit.Palette.cloud)
                }
                Text("Your recent training rhythm, logged in one place for quick review and editing.")
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
            }
        }
    }

    private var storyBridge: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.frost) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        RallyUIKit.EditorialEyebrow(text: "Carry it forward", tint: RallyUIKit.Palette.frost)
                        Text("Turn practice into memory and match context")
                            .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("A session can become a match note, a reflection, or the start of a bigger story inside Rally.")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                    }

                    Spacer(minLength: 8)

                    RallyUIKit.IconBadge(
                        systemName: "arrow.triangle.branch",
                        tint: RallyUIKit.Palette.frost,
                        size: 32
                    )
                }

                HStack(spacing: 10) {
                    NavigationLink {
                        MatchLogView()
                    } label: {
                        bridgeCard(
                            title: "Match log",
                            subtitle: "Add the score after the session turns competitive.",
                            tint: RallyUIKit.Palette.gold,
                            icon: "trophy.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        JournalView()
                    } label: {
                        bridgeCard(
                            title: "Journal",
                            subtitle: "Write how the work actually felt while it’s fresh.",
                            tint: RallyUIKit.Palette.rose,
                            icon: "book.pages.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func stat(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func bridgeCard(title: String, subtitle: String, tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RallyUIKit.IconBadge(
                systemName: icon,
                tint: tint,
                size: 28
            )

            Text(title)
                .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)

            Text(subtitle)
                .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.56))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
        try? modelContext.save()
        RallySyncTriggers.pushAfterLocalSave(modelContext: modelContext)
    }
}

private struct TrainingRow: View {
    let session: TrainingSession

    var body: some View {
        HStack(spacing: 14) {
            intensityBadge
            VStack(alignment: .leading, spacing: 4) {
                Text(session.drillType.isEmpty ? "Session" : session.drillType)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(session.date, style: .date)
                    Text("·")
                    Text("\(session.durationMinutes) min")
                    if !session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("·")
                        Text("notes")
                    }
                }
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var intensityBadge: some View {
        Text("\(session.intensity)")
            .font(.system(.body, design: .rounded).weight(.bold))
            .frame(width: 36, height: 36)
            .background(
                Circle().fill(intensityColor.opacity(0.25))
            )
            .overlay(
                Circle().stroke(intensityColor, lineWidth: 1.5)
            )
            .foregroundStyle(intensityColor)
    }

    private var intensityColor: Color {
        switch session.intensity {
        case 1: return Color(hex: "#90EE90") ?? .green
        case 2: return Color(hex: "#7FFF00") ?? .green
        case 3: return Color.cyan
        case 4: return Color(hex: "#FF8C00") ?? .orange
        default: return Color(hex: "#FF1A55") ?? .red
        }
    }
}
