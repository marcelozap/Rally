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
                    List {
                        Section(header: weeklySummary) {
                            ForEach(sessions) { session in
                                NavigationLink {
                                    TrainingEditorView(session: session)
                                } label: {
                                    TrainingRow(session: session)
                                }
                            }
                            .onDelete(perform: delete)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Training")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.cyan)
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
            Image(systemName: "figure.tennis")
                .font(.system(size: 60))
                .foregroundStyle(.cyan.opacity(0.6))
            Text("No training logged yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text("Tap + to log your first session.")
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var weeklySummary: some View {
        let cal = Calendar.current
        let lastWeek = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = sessions.filter { $0.date >= lastWeek }
        let totalMinutes = recent.reduce(0) { $0 + $1.durationMinutes }
        let totalSessions = recent.count
        return HStack(spacing: 24) {
            stat(value: "\(totalSessions)", label: "sessions")
            stat(value: "\(totalMinutes)", label: "minutes")
            stat(value: "7d", label: "window")
        }
        .padding(.vertical, 6)
        .foregroundStyle(.white)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
        try? modelContext.save()
    }
}

private struct TrainingRow: View {
    let session: TrainingSession

    var body: some View {
        HStack(spacing: 14) {
            intensityBadge
            VStack(alignment: .leading, spacing: 4) {
                Text(session.drillType.isEmpty ? "Session" : session.drillType)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(session.date, style: .date)
                    Text("·")
                    Text("\(session.durationMinutes) min")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .listRowBackground(Color.white.opacity(0.04))
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
