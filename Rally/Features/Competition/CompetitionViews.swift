import SwiftUI
import SwiftData

struct CompetitionOverviewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: RallyUIKit.Spacing.md) {
                RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.champagne) {
                    VStack(spacing: RallyUIKit.Spacing.sm) {
                        RallyUIKit.EditorialEyebrow(text: "Competition", tint: RallyUIKit.Palette.champagne)
                        Text("Competition Hub")
                            .font(RallyUIKit.Typography.display(34, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Jump into leaderboards, rivals, challenges, and seasonal rewards.")
                            .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.82))
                            .multilineTextAlignment(.center)
                    }
                }
                VStack(spacing: RallyUIKit.Spacing.sm) {
                    competitionTile(title: "Leaderboard", subtitle: "See how you rank against other players", icon: "list.number", destination: LeaderboardView())
                    competitionTile(title: "Battle Pass", subtitle: "Earn XP, tiers, and premium rewards", icon: "ticket.fill", destination: BattlePassView())
                    competitionTile(title: "Rivals", subtitle: "Challenge a rival and beat their target score", icon: "person.2.fill", destination: RivalModeView())
                    competitionTile(title: "Analytics", subtitle: "Review performance trends and progress", icon: "chart.bar.doc.horizontal.fill", destination: AnalyticsDashboardView())
                    competitionTile(title: "Seasonal Events", subtitle: "Complete special event goals for bonus rewards", icon: "sparkles", destination: SeasonalEventsView())
                }
            }
            .padding(.horizontal, RallyUIKit.Spacing.md)
            .padding(.vertical, RallyUIKit.Spacing.md)
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle("Competition")
    }

    @ViewBuilder
    private func competitionTile<Destination: View>(title: String, subtitle: String, icon: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                        .fill(icon == "ticket.fill" ? RallyUIKit.Palette.gold.opacity(0.16) : RallyUIKit.Palette.cyan.opacity(0.14))
                        .frame(width: 54, height: 54)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(icon == "ticket.fill" ? RallyUIKit.Palette.gold : RallyUIKit.Palette.cyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text(subtitle)
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.74))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.54))
            }
            .padding(RallyUIKit.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                    .stroke(RallyUIKit.Palette.line, lineWidth: 1)
            )
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
            VStack(spacing: RallyUIKit.Spacing.md) {
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
            .padding(RallyUIKit.Spacing.md)
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle("Battle Pass")
    }

    private func passHeader(_ pass: BattlePass) -> some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.gold) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xs + 2) {
                Text(pass.seasonName)
                    .font(RallyUIKit.Typography.title(.title, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text("Season ends in \(pass.daysRemaining) days")
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.8))
                Text("XP: \(pass.xp)")
                    .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                ProgressView(value: pass.tierProgress)
                    .tint(RallyUIKit.Palette.cyan)
            }
        }
    }

    private func progressSection(_ pass: BattlePass) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current tier reward")
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
            Text(BattlePassManager.rewardFor(currentXP: pass.xp))
                .font(RallyUIKit.Typography.body(.subheadline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.82))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).fill(Color.white.opacity(0.03)))
    }

    private func tiersSection(_ pass: BattlePass) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tiers")
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
            ForEach(pass.activeTiers) { tier in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier.name)
                            .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                        Text(tier.rewardDescription)
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.74))
                    }
                    Spacer()
                    Text(tier.premiumOnly ? "Premium" : "Free")
                        .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(tier.premiumOnly ? RallyUIKit.Palette.rose.opacity(0.18) : RallyUIKit.Palette.cyan.opacity(0.18)))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).fill(Color.white.opacity(0.04)))
            }
        }
    }

    private func premiumOffer(_ pass: BattlePass) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(pass.premiumUnlocked ? "Premium unlocked" : "Upgrade to Premium")
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
            Text(pass.premiumUnlocked ? "You can claim all battle pass rewards." : "Unlock exclusive tiers, bonus XP, and premium cosmetics.")
                .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
            Button(action: togglePremium) {
                Text(pass.premiumUnlocked ? "Premium Active" : "Unlock Premium")
                    .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.obsidian)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).fill(pass.premiumUnlocked ? RallyUIKit.Palette.lime : RallyUIKit.Palette.cyan))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg).fill(Color.white.opacity(0.05)))
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
            VStack(spacing: RallyUIKit.Spacing.md) {
                introCopy
                opponentList
                historySection
            }
            .padding(RallyUIKit.Spacing.md)
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle("Rivals")
        .sheet(isPresented: $showSession) {
            if let opponent = selectedOpponent {
                NavigationStack {
                    GameSessionView(rivalOpponent: opponent, onExit: { showSession = false })
                }
            }
        }
    }

    private var introCopy: some View {
        Text("Pick a rival and challenge them in a one-on-one run.")
            .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
            .padding(.top, 10)
    }

    private var opponentList: some View {
        ForEach(RivalModeManager.sampleOpponents) { opponent in
            Button {
                selectedOpponent = opponent
                showSession = true
            } label: {
                opponentCard(opponent)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if !history.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recent rival results")
                    .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)

                ForEach(history, id: \.id) { result in
                    historyRow(result)
                }
            }
        }
    }

    private func opponentCard(_ opponent: RivalOpponent) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(opponent.name)
                    .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(opponent.style)
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                Text("Target: \(opponent.targetScore)")
                    .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.cyan)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Lvl. \(opponent.level)")
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text("+\(opponent.rewardCoins) coins")
                    .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.gold)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func historyRow(_ result: RivalChallenge) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.opponentName)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text("Score: \(result.playerScore) / target: \(result.targetScore)")
                    .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
            }

            Spacer()

            Text(result.didWin ? "Win" : "Loss")
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(result.didWin ? RallyUIKit.Palette.lime : RallyUIKit.Palette.coral)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(Color.white.opacity(0.03))
        )
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
            VStack(spacing: RallyUIKit.Spacing.md) {
                summaryCard
                statTiles
                engagementCard
            }
            .padding(RallyUIKit.Spacing.md)
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle("Analytics")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Performance Summary")
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Text("Track your progress across score, accuracy, and seasonal goals.")
                .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
            HStack(spacing: 10) {
                statBubble(label: "Games", value: "\(insights.totalGames)")
                statBubble(label: "Wins", value: "\(insights.totalWins)")
                statBubble(label: "Perfects", value: "\(insights.totalPerfectHits)")
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg).fill(Color.white.opacity(0.05)))
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
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Text("Achievements unlocked: \(insights.achievementsUnlocked)")
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
            ProgressView(value: insights.seasonalProgress)
                .tint(RallyUIKit.Palette.rose)
            Text("Seasonal event completion: \(Int((insights.seasonalProgress * 100).rounded()))%")
                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.74))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg).fill(Color.white.opacity(0.05)))
    }

    private func statBubble(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.cyan)
            Text(label)
                .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).fill(Color.white.opacity(0.04)))
    }

    private func analyticsTile(title: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(value)
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.cyan)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).fill(Color.white.opacity(0.04)))
    }
}

struct SeasonalEventsView: View {
    @Query private var events: [SeasonalEvent]

    var body: some View {
        ScrollView {
            VStack(spacing: RallyUIKit.Spacing.md) {
                if let event = events.first {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(event.title)
                            .font(RallyUIKit.Typography.title(.title, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text(event.subtitle)
                            .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.82))
                        Text(event.descriptionText)
                            .font(RallyUIKit.Typography.body(.body, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.84))
                        Text(event.goalDescription)
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                        ProgressView(value: event.progressFraction)
                            .tint(RallyUIKit.Palette.rose)
                        HStack {
                            Text("\(event.progress)/\(event.target)")
                                .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                            Spacer()
                            Text(event.isCompleted ? "Complete" : "\(event.daysRemaining)d left")
                                .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                                .foregroundStyle(event.isCompleted ? RallyUIKit.Palette.lime : RallyUIKit.Palette.cloud.opacity(0.8))
                        }
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Reward: \(event.rewardCoins) coins")
                            .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.gold)
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg).fill(Color.white.opacity(0.05)))
                } else {
                    Text("No active seasonal events right now.")
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
                }
            }
            .padding(RallyUIKit.Spacing.md)
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle("Seasonal Events")
    }
}
