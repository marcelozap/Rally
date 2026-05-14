import SwiftUI
import SwiftData

struct MatchLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MatchEntry.date, order: .reverse) private var matches: [MatchEntry]
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if matches.isEmpty {
                    emptyState
                } else {
                    List {
                        Section(header: record) {
                            ForEach(matches) { match in
                                NavigationLink {
                                    MatchEditorView(match: match)
                                } label: {
                                    MatchRow(match: match)
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
            .navigationTitle("Matches")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack { MatchEditorView(match: nil) }
            }
        }
    }

    private var record: some View {
        let wins = matches.filter(\.resultWon).count
        let losses = matches.count - wins
        return HStack(spacing: 24) {
            stat(value: "\(wins)", label: "wins", tint: .cyan)
            stat(value: "\(losses)", label: "losses", tint: Color(hex: "#FF1A55") ?? .red)
            stat(value: "\(matches.count)", label: "total", tint: .white.opacity(0.7))
        }
        .padding(.vertical, 6)
        .foregroundStyle(.white)
    }

    private func stat(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 60))
                .foregroundStyle(.cyan.opacity(0.6))
            Text("No matches logged yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text("Tap + after your next match.")
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(matches[index])
        }
        try? modelContext.save()
        RallySyncTriggers.pushAfterLocalSave(modelContext: modelContext)
    }
}

private struct MatchRow: View {
    let match: MatchEntry
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((match.resultWon ? Color.cyan : Color(hex: "#FF1A55") ?? .red).opacity(0.25))
                Text(match.resultWon ? "W" : "L")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(match.resultWon ? .cyan : (Color(hex: "#FF1A55") ?? .red))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(match.opponentName.isEmpty ? "Opponent" : "vs \(match.opponentName)")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(match.date, style: .date)
                    if !match.scoreDisplay.isEmpty {
                        Text("·")
                        Text(match.scoreDisplay)
                    }
                    Text("·")
                    Text(match.surface.displayName)
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .listRowBackground(Color.white.opacity(0.04))
    }
}
