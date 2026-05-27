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
            .background(RallyUIKit.screenBackground)
            .navigationTitle("Matches")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: {
                        RallyUIKit.IconBadge(
                            systemName: "plus",
                            tint: RallyUIKit.Palette.gold,
                            size: 34
                        )
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
            stat(value: "\(losses)", label: "losses", tint: RallyUIKit.Palette.rose)
            stat(value: "\(matches.count)", label: "total", tint: RallyUIKit.Palette.gold)
        }
        .padding(.vertical, 6)
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            RallyUIKit.IconBadge(
                systemName: "trophy.fill",
                tint: RallyUIKit.Palette.gold,
                size: 72
            )
            Text("No matches logged yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text("Tap + after your next match.")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.58))
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
                    .fill((match.resultWon ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.rose).opacity(0.25))
                Text(match.resultWon ? "W" : "L")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(match.resultWon ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.rose)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(match.opponentName.isEmpty ? "Opponent" : "vs \(match.opponentName)")
                    .font(.system(.body, design: .rounded).weight(.bold))
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
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.white.opacity(0.04))
    }
}
