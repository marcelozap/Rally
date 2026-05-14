import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var auth: AuthSession
    @Query private var avatarConfigs: [AvatarConfig]
    @Query private var progressRecords: [PlayerProgress]
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainings: [TrainingSession]
    @Query(sort: \MatchEntry.date, order: .reverse) private var matches: [MatchEntry]
    @Query(sort: \JournalEntry.date, order: .reverse) private var journal: [JournalEntry]

    @Binding var selectedTab: RallyTab
    @Binding var logsSection: LogsSection

    @State private var showingTrainingEditor = false
    @State private var showingMatchEditor = false
    @State private var showingJournalEditor = false

    private var avatar: AvatarConfig? { avatarConfigs.first }
    private var progress: PlayerProgress? { progressRecords.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    avatarCard
                    playerBadge
                    quickActions
                    courtAtlasSection
                    weeklyStats
                    recentJournal
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if let email = auth.userEmail {
                            Label(email, systemImage: "envelope.fill")
                        }
                        Button("Sign out", role: .destructive) {
                            auth.logout()
                        }
                    } label: {
                        Image(systemName: "person.text.rectangle")
                            .foregroundStyle(.cyan)
                    }
                    .accessibilityLabel("Account")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let avatar = avatar {
                        NavigationLink {
                            AvatarCustomizerView(config: avatar)
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingTrainingEditor) {
                NavigationStack { TrainingEditorView(session: nil) }
            }
            .sheet(isPresented: $showingMatchEditor) {
                NavigationStack { MatchEditorView(match: nil) }
            }
            .sheet(isPresented: $showingJournalEditor) {
                NavigationStack { JournalEditorView(entry: nil) }
            }
        }
    }

    private var greeting: String {
        let raw = avatar?.playerName.trimmingCharacters(in: .whitespaces) ?? ""
        let name = raw.isEmpty ? "Player" : raw
        return "Hey, \(name)"
    }

    // MARK: - Avatar card

    private var avatarCard: some View {
        Group {
            if let avatar = avatar {
                ZStack(alignment: .bottomLeading) {
                    AvatarView(config: avatar, subtlePerspective: true)
                        .frame(height: 320)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(avatar.playerName)
                            .font(.system(.title, design: .rounded).weight(.heavy))
                            .foregroundStyle(.white)
                        Text(equippedSummary(avatar))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding()
                }
            }
        }
    }

    private func equippedSummary(_ avatar: AvatarConfig) -> String {
        let top = ShopCatalog.item(id: avatar.equippedTopID)?.name ?? "—"
        let racket = ShopCatalog.item(id: avatar.equippedRacketID)?.name ?? "—"
        return "\(top) · \(racket)"
    }

    // MARK: - Player badge (level / coins / best)

    @ViewBuilder
    private var playerBadge: some View {
        if let p = progress {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    levelBadge(p)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Level \(p.level)")
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                            .foregroundStyle(.white)
                        Text("\(p.xpToNextLevel) XP to lv. \(p.level + 1)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                        levelBar(progress: p.levelProgress)
                            .frame(height: 5)
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    badgeChip(icon: "circle.hexagongrid.fill", value: "\(p.coins)", label: "coins", tint: .yellow)
                    badgeChip(icon: "star.fill",               value: "\(p.bestScore)", label: "best",  tint: .cyan)
                    badgeChip(icon: "flame.fill",              value: "\(p.dailyStreak)d", label: "streak", tint: .pink)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private func levelBadge(_ p: PlayerProgress) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.cyan, Color(red: 0.0, green: 0.5, blue: 0.9)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 56, height: 56)
            Text("\(p.level)")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(.black)
        }
        .shadow(color: .cyan.opacity(0.5), radius: 8, x: 0, y: 0)
    }

    private func levelBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color.cyan, Color.pink],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * CGFloat(max(0.02, progress)))
            }
        }
    }

    private func badgeChip(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: -2) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(spacing: 10) {
            actionButton(icon: "tennis.racket", label: "Practice", tint: .cyan, big: true) {
                selectedTab = .play
            }
            HStack(spacing: 10) {
                actionButton(icon: "figure.tennis", label: "Log training", tint: Color(hex: "#C8FF36") ?? .green) {
                    showingTrainingEditor = true
                }
                actionButton(icon: "trophy", label: "Log match", tint: Color(hex: "#FF8C00") ?? .orange) {
                    showingMatchEditor = true
                }
                actionButton(icon: "book.closed", label: "Quick note", tint: Color(hex: "#D63384") ?? .pink) {
                    showingJournalEditor = true
                }
            }
        }
    }

    // MARK: - Court atlas (world map)

    private var courtAtlasSection: some View {
        NavigationLink {
            CourtsMapView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.45), Color.green.opacity(0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: "globe.americas.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("World court atlas")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("Iconic venues · satellite-style map · official booking links")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func actionButton(
        icon: String,
        label: String,
        tint: Color,
        big: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if big {
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.title2)
                        Text(label)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.title3)
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(tint.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(tint, lineWidth: 1)
            )
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats

    private var weeklyStats: some View {
        let cal = Calendar.current
        let lastWeek = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentTrain = trainings.filter { $0.date >= lastWeek }
        let recentMatches = matches.filter { $0.date >= lastWeek }
        let totalMins = recentTrain.reduce(0) { $0 + $1.durationMinutes }
        let wins = recentMatches.filter(\.resultWon).count
        let losses = recentMatches.count - wins

        return VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                statTile(value: "\(recentTrain.count)", label: "sessions", tint: .cyan)
                statTile(value: "\(totalMins)m", label: "trained", tint: .cyan)
                statTile(value: "\(wins)-\(losses)", label: "record", tint: Color(hex: "#FF8C00") ?? .orange)
            }
        }
    }

    private func statTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Journal preview

    @ViewBuilder
    private var recentJournal: some View {
        if let entry = journal.first {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("From the journal")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        selectedTab = .journal
                    } label: {
                        Text("See all")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.cyan)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.title.isEmpty ? "Untitled entry" : entry.title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text(entry.body.isEmpty ? "No body yet." : entry.body)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(3)
                    Text(entry.date, format: .dateTime.month().day().year())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
    }
}
