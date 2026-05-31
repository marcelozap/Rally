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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            record
                            if !photoMatches.isEmpty {
                                memoryHighlights
                            }
                            atlasBridge
                            VStack(spacing: 12) {
                                ForEach(matches) { match in
                                    NavigationLink {
                                        MatchEditorView(match: match)
                                    } label: {
                                        MatchRow(match: match)
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

    private var photoMatches: [MatchEntry] {
        matches.filter { $0.photoData != nil }
    }

    private var record: some View {
        let wins = matches.filter(\.resultWon).count
        let losses = matches.count - wins
        return RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.gold) {
            VStack(alignment: .leading, spacing: 14) {
                RallyUIKit.EditorialEyebrow(text: "Match ledger", tint: RallyUIKit.Palette.gold)
                HStack(spacing: 24) {
                    stat(value: "\(wins)", label: "wins", tint: .cyan)
                    stat(value: "\(losses)", label: "losses", tint: RallyUIKit.Palette.rose)
                    stat(value: "\(matches.count)", label: "total", tint: RallyUIKit.Palette.gold)
                }
                Text("Keep your competitive record in one place, with quick score and surface recall.")
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
            }
        }
    }

    private var memoryHighlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RallyUIKit.IconBadge(
                    systemName: "photo.on.rectangle.angled",
                    tint: RallyUIKit.Palette.rose,
                    size: 30
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Match memories")
                        .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text("Little snapshots from the people and nights you actually want to remember.")
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(photoMatches.prefix(5)) { match in
                        NavigationLink {
                            MatchEditorView(match: match)
                        } label: {
                            MatchMemoryCard(match: match)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var atlasBridge: some View {
        NavigationLink {
            CourtsMapView()
        } label: {
            RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            RallyUIKit.EditorialEyebrow(text: "Play next", tint: RallyUIKit.Palette.cyan)
                            Text("Courts and camps around the world")
                                .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text("Move from your match memories into iconic venues and global training camps with official links only.")
                                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                        }

                        Spacer(minLength: 8)

                        RallyUIKit.IconBadge(
                            systemName: "globe.americas.fill",
                            tint: RallyUIKit.Palette.cyan,
                            size: 38
                        )
                    }

                    HStack(spacing: 8) {
                        travelChip("Venues", tint: RallyUIKit.Palette.cyan)
                        travelChip("Camps", tint: RallyUIKit.Palette.gold)
                        travelChip("Official links", tint: RallyUIKit.Palette.rose)
                    }

                    HStack(spacing: 8) {
                        Text("Open world atlas")
                            .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(RallyUIKit.Palette.cyan)
                }
            }
        }
        .buttonStyle(.plain)
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

            VStack(alignment: .leading, spacing: 8) {
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

                if let previewImage {
                    ZStack(alignment: .bottomLeading) {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 110)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                LinearGradient(
                                    colors: [Color.clear, Color.black.opacity(0.4)],
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
                            Image(systemName: "camera.fill")
                                .font(.caption2.weight(.bold))
                            Text("Match memory")
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

    private var previewImage: UIImage? {
        guard let data = match.photoData else { return nil }
        return UIImage(data: data)
    }
}

private struct MatchMemoryCard: View {
    let match: MatchEntry

    var body: some View {
        let tint = match.resultWon ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.rose

        VStack(alignment: .leading, spacing: 10) {
            if let previewImage {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 184, height: 146)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.32)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    HStack(spacing: 6) {
                        Image(systemName: match.resultWon ? "sparkles" : "camera.fill")
                            .font(.caption2.weight(.bold))
                        Text(match.resultWon ? "Saved win" : "Saved memory")
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

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(match.resultWon ? "WIN" : "MATCH DAY")
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(tint)
                    Spacer(minLength: 8)
                    Text(match.date, format: .dateTime.month(.abbreviated).day())
                        .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.45))
                }

                Text(match.opponentName.isEmpty ? "Saved memory" : "vs \(match.opponentName)")
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                    .lineLimit(1)

                Text(match.location.isEmpty ? match.surface.displayName : "\(match.location) · \(match.surface.displayName)")
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.66))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(width: 208, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 5)
    }

    private var previewImage: UIImage? {
        guard let data = match.photoData else { return nil }
        return UIImage(data: data)
    }
}

private func travelChip(_ label: String, tint: Color) -> some View {
    Text(label)
        .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(
            Capsule().stroke(tint.opacity(0.18), lineWidth: 1)
        )
}
