import SwiftUI
import SwiftData

struct CompetitionOverviewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Competition Hub")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, 12)
                Text("Jump into leaderboards, rivals, challenges, and seasonal rewards.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                VStack(spacing: 14) {
                    competitionTile(title: "Leaderboard", subtitle: "See how you rank against other players", icon: "list.number", destination: LeaderboardView())
                    competitionTile(title: "Battle Pass", subtitle: "Earn XP, tiers, and premium rewards", icon: "ticket.fill", destination: BattlePassView())
                    competitionTile(title: "Rivals", subtitle: "Challenge a rival and beat their target score", icon: "person.2.fill", destination: RivalModeView())
                    competitionTile(title: "Analytics", subtitle: "Review performance trends and progress", icon: "chart.bar.doc.horizontal.fill", destination: AnalyticsDashboardView())
                    competitionTile(title: "Seasonal Events", subtitle: "Complete special event goals for bonus rewards", icon: "sparkles", destination: SeasonalEventsView())
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Competition")
    }

    @ViewBuilder
    private func competitionTile<Destination: View>(title: String, subtitle: String, icon: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 54, height: 54)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(.cyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.04)))
        }
        .buttonStyle(.plain)
    }
}

struct LeaderboardView: View {
    @Query(sort: \LeaderboardEntry.rank, order: .forward) private var entries: [LeaderboardEntry]

    var body: some View {
        List {
            ForEach(entries, id: \.id) { entry in
                HStack {
                    VStack(alignment: .leading) {
                        Text(entry.playerName)
                            .font(.headline)
                        Text("Lvl. \(entry.level) · \(entry.score) pts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("#\(entry.rank)")
                            .font(.title3.weight(.bold))
                        Image(systemName: entry.badge)
                            .foregroundStyle(entry.isPlayer ? .yellow : .white.opacity(0.8))
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Leaderboard")
    }
}

struct BattlePassView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var passes: [BattlePass]

    private var battlePass: BattlePass? { passes.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let pass = battlePass {
                    passHeader(pass)
                    progressSection(pass)
                    tiersSection(pass)
                    premiumOffer(pass)
                } else {
                    Text("No battle pass data available.")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Battle Pass")
    }

    private func passHeader(_ pass: BattlePass) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(pass.seasonName)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text("Season ends in \(pass.daysRemaining) days")
                .font(.subheadline)
                .foregroundStyle(.cyan.opacity(0.75))
            Text("XP: \(pass.xp)")
                .font(.headline)
                .foregroundStyle(.white)
            ProgressView(value: pass.tierProgress)
                .tint(.cyan)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
    }

    private func progressSection(_ pass: BattlePass) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current tier reward")
                .font(.headline)
            Text(BattlePassManager.rewardFor(currentXP: pass.xp))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
    }

    private func tiersSection(_ pass: BattlePass) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tiers")
                .font(.headline)
            ForEach(pass.activeTiers) { tier in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier.name)
                            .font(.subheadline.weight(.bold))
                        Text(tier.rewardDescription)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    Text(tier.premiumOnly ? "Premium" : "Free")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(tier.premiumOnly ? Color.pink.opacity(0.2) : Color.cyan.opacity(0.2)))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
            }
        }
    }

    private func premiumOffer(_ pass: BattlePass) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(pass.premiumUnlocked ? "Premium unlocked" : "Upgrade to Premium")
                .font(.headline)
            Text(pass.premiumUnlocked ? "You can claim all battle pass rewards." : "Unlock exclusive tiers, bonus XP, and premium cosmetics.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Button(action: togglePremium) {
                Text(pass.premiumUnlocked ? "Premium Active" : "Unlock Premium")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(pass.premiumUnlocked ? Color.green : Color.cyan))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
    }

    private func togglePremium() {
        guard let pass = battlePass else { return }
        pass.premiumUnlocked.toggle()
        try? modelContext.save()
    }
}

struct RivalModeView: View {
    @State private var selectedOpponent: RivalOpponent? = nil
    @State private var showSession = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RivalChallenge.completedDate, order: .reverse) private var history: [RivalChallenge]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Pick a rival and challenge them in a one-on-one run.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 10)
                ForEach(RivalModeManager.sampleOpponents) { opponent in
                    Button(action: {
                        selectedOpponent = opponent
                        showSession = true
                    }) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(opponent.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(opponent.style)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                Text("Target: \(opponent.targetScore)")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Lvl. \(opponent.level)")
                                    .font(.subheadline.weight(.bold))
                                Text("+\(opponent.rewardCoins) coins")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
                    }
                }
                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent rival results")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ForEach(history, id: \.id) { result in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(result.opponentName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("Score: \(result.playerScore) / target: \(result.targetScore)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                                Text(result.didWin ? "Win" : "Loss")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(result.didWin ? .green : .red)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.03)))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Rivals")
        .sheet(isPresented: $showSession) {
            if let opponent = selectedOpponent {
                NavigationStack {
                    GameSessionView(onExit: { showSession = false }, rivalOpponent: opponent)
                }
            }
        }
    }
}

struct AnalyticsDashboardView: View {
    @EnvironmentObject private var auth: AuthSession
    @Query private var progressRecords: [PlayerProgress]
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainings: [TrainingSession]
    @Query(sort: \MatchEntry.date, order: .reverse) private var matches: [MatchEntry]
    @Query(sort: \JournalEntry.date, order: .reverse) private var journal: [JournalEntry]
    @Query(sort: \DailyChallenge.createdDate, order: .reverse) private var challenges: [DailyChallenge]
    @Query(sort: \SeasonalEvent.startDate, order: .reverse) private var seasonalEvents: [SeasonalEvent]
    @Query private var achievements: [Achievement]

    private var insights: AnalyticsInsights {
        AnalyticsInsights.compute(
            progress: progressRecords.first,
            trainings: trainings,
            matches: matches,
            achievements: achievements,
            challenges: challenges,
            seasonalEvents: seasonalEvents
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                summaryCard
                statTiles
                engagementCard
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Analytics")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Performance Summary")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Track your progress across score, accuracy, and seasonal goals.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 10) {
                statBubble(label: "Games", value: "\(insights.totalGames)")
                statBubble(label: "Wins", value: "\(insights.totalWins)")
                statBubble(label: "Perfects", value: "\(insights.totalPerfectHits)")
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
    }

    private var statTiles: some View {
        VStack(spacing: 12) {
            analyticsTile(title: "Average Score", value: "\(insights.averageScore)")
            analyticsTile(title: "Average Accuracy", value: "\(Int((insights.averageAccuracy * 100).rounded()))%")
            analyticsTile(title: "Best Combo", value: "\(insights.averageCombo)")
            analyticsTile(title: "Recent Win Rate", value: "\(Int((insights.recentWinRate * 100).rounded()))%")
        }
    }

    private var engagementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Engagement")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Achievements unlocked: \(insights.achievementsUnlocked)")
                .foregroundStyle(.white.opacity(0.7))
            ProgressView(value: insights.seasonalProgress)
                .tint(.pink)
            Text("Seasonal event completion: \(Int((insights.seasonalProgress * 100).rounded()))%")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
    }

    private func statBubble(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.cyan)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
    }

    private func analyticsTile(title: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.cyan)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
    }
}

struct SeasonalEventsView: View {
    @Query private var events: [SeasonalEvent]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let event = events.first {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(event.title)
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                        Text(event.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.cyan.opacity(0.8))
                        Text(event.descriptionText)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.75))
                        Text(event.goalDescription)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        ProgressView(value: event.progressFraction)
                            .tint(.pink)
                        HStack {
                            Text("\(event.progress)/\(event.target)")
                                .font(.headline)
                            Spacer()
                            Text(event.isCompleted ? "Complete" : "\(event.daysRemaining)d left")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(event.isCompleted ? .green : .white.opacity(0.7))
                        }
                        .foregroundStyle(.white)
                        Text("Reward: \(event.rewardCoins) coins")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.yellow)
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
                } else {
                    Text("No active seasonal events right now.")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Seasonal Events")
    }
}
