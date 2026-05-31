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
                competitionHighlights
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

    private var competitionHighlights: some View {
        HStack(spacing: 12) {
            competitionHighlightCard(
                eyebrow: "Live now",
                title: "Climb the ladder",
                subtitle: "Leaderboard, rivals, and momentum all in one lane.",
                tint: RallyUIKit.Palette.cyan,
                icon: "figure.tennis"
            )
            competitionHighlightCard(
                eyebrow: "Reward track",
                title: "Season pass",
                subtitle: "XP, tier unlocks, and seasonal rewards stay close.",
                tint: RallyUIKit.Palette.gold,
                icon: "sparkles"
            )
        }
    }

    private func competitionHighlightCard(eyebrow: String, title: String, subtitle: String, tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RallyUIKit.EditorialEyebrow(text: eyebrow, tint: tint)
                Spacer()
                Image(systemName: icon)
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Text(subtitle)
                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.74))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RallyUIKit.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
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

    private var featuredEntries: [LeaderboardEntry] {
        Array(entries.prefix(3))
    }

    private var remainingEntries: [LeaderboardEntry] {
        Array(entries.dropFirst(3))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: RallyUIKit.Spacing.md) {
                RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
                    VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                        RallyUIKit.EditorialEyebrow(text: "Leaderboard", tint: RallyUIKit.Palette.cyan)
                        Text("Live ladder")
                            .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("See who is climbing right now and where your best sessions are stacking up.")
                            .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
                    }
                }

                if featuredEntries.isEmpty {
                    RallyUIKit.SectionCard {
                        Text("No leaderboard results yet.")
                            .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.74))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                        Text("Top players")
                            .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.frost)

                        ForEach(featuredEntries, id: \.id) { entry in
                            leaderboardSpotlight(entry)
                        }
                    }

                    if !remainingEntries.isEmpty {
                        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                            Text("Full ranking")
                                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                                .foregroundStyle(RallyUIKit.Palette.frost)

                            ForEach(remainingEntries, id: \.id) { entry in
                                leaderboardRow(entry)
                            }
                        }
                    }
                }
            }
            .padding(RallyUIKit.Spacing.md)
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle("Leaderboard")
    }

    private func leaderboardSpotlight(_ entry: LeaderboardEntry) -> some View {
        let tint = entry.rank == 1 ? RallyUIKit.Palette.gold : (entry.isPlayer ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.champagne)

        return RallyUIKit.LuxePanel(tint: tint) {
            HStack(alignment: .center, spacing: RallyUIKit.Spacing.md) {
                leaderboardRankBadge(entry.rank, tint: tint)

                VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xxs) {
                    HStack(spacing: 8) {
                        Text(entry.playerName)
                            .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        if entry.isPlayer {
                            chipLabel("You", tint: RallyUIKit.Palette.cyan)
                        }
                    }
                    Text("Lvl. \(entry.level) · \(entry.score) pts")
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
                }

                Spacer()

                badgeStamp(entry)
            }
        }
    }

    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: RallyUIKit.Spacing.md) {
            leaderboardRankBadge(entry.rank, tint: entry.isPlayer ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.champagne)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.playerName)
                        .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    if entry.isPlayer {
                        chipLabel("You", tint: RallyUIKit.Palette.cyan)
                    }
                }
                Text("Lvl. \(entry.level) · \(entry.score) pts")
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.74))
            }

            Spacer()

            badgeStamp(entry)
        }
        .padding(RallyUIKit.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .fill(entry.isPlayer ? RallyUIKit.Palette.cyan.opacity(0.08) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .stroke(entry.isPlayer ? RallyUIKit.Palette.cyan.opacity(0.24) : RallyUIKit.Palette.line, lineWidth: 1)
        )
    }

    private func leaderboardRankBadge(_ rank: Int, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 50, height: 50)
            Text("#\(rank)")
                .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                .foregroundStyle(tint)
        }
    }

    private func badgeStamp(_ entry: LeaderboardEntry) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Image(systemName: entry.badge)
                .font(.title3)
                .foregroundStyle(entry.isPlayer ? RallyUIKit.Palette.gold : RallyUIKit.Palette.cloud.opacity(0.86))
            Text(entry.rank <= 3 ? "Top tier" : "Active")
                .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.6))
        }
    }

    private func chipLabel(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}

struct BattlePassView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var passes: [BattlePass]

    private var battlePass: BattlePass? { passes.first }
    private var featuredReward: String {
        guard let pass = battlePass else { return "No active reward" }
        return BattlePassManager.rewardFor(currentXP: pass.xp)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: RallyUIKit.Spacing.md) {
                if let pass = battlePass {
                    passHeader(pass)
                    progressSection(pass)
                    tiersSection(pass)
                    premiumOffer(pass)
                } else {
                    RallyUIKit.SectionCard {
                        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xs) {
                            Text("No battle pass data available.")
                                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text("When the next season pass goes live, its reward track and premium lane will show up here.")
                                .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(RallyUIKit.Spacing.md)
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle("Battle Pass")
    }

    private func passHeader(_ pass: BattlePass) -> some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.gold) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                RallyUIKit.EditorialEyebrow(text: "Season pass", tint: RallyUIKit.Palette.gold)
                Text(pass.seasonName)
                    .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text("Season ends in \(pass.daysRemaining) days")
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.8))
                ProgressView(value: pass.tierProgress)
                    .tint(RallyUIKit.Palette.cyan)
                HStack(alignment: .firstTextBaseline) {
                    Text("\(pass.xp)")
                        .font(RallyUIKit.Typography.display(28, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text("XP in the current ladder")
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.78))
                }
            }
        }
    }

    private func progressSection(_ pass: BattlePass) -> some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                RallyUIKit.EditorialEyebrow(text: "Reward track", tint: RallyUIKit.Palette.cyan)
                Text("Current tier reward")
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(featuredReward)
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.82))
                HStack(spacing: 10) {
                    rewardStatusChip(title: "Tier progress", value: "\(Int((pass.tierProgress * 100).rounded()))%", tint: RallyUIKit.Palette.cyan)
                    rewardStatusChip(title: "Unlock path", value: pass.premiumUnlocked ? "Premium active" : "Free track", tint: pass.premiumUnlocked ? RallyUIKit.Palette.lime : RallyUIKit.Palette.champagne)
                }
            }
        }
    }

    private func tiersSection(_ pass: BattlePass) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tiers")
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            ForEach(pass.activeTiers) { tier in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier.name)
                            .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text(tier.rewardDescription)
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.74))
                    }
                    Spacer()
                    Text(tier.premiumOnly ? "Premium" : "Free")
                        .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(tier.premiumOnly ? RallyUIKit.Palette.rose : RallyUIKit.Palette.cyan)
                        .background(Capsule().fill(tier.premiumOnly ? RallyUIKit.Palette.rose.opacity(0.18) : RallyUIKit.Palette.cyan.opacity(0.18)))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).fill(Color.white.opacity(0.04)))
                .overlay(
                    RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                        .stroke(tier.premiumOnly ? RallyUIKit.Palette.rose.opacity(0.16) : RallyUIKit.Palette.line, lineWidth: 1)
                )
            }
        }
    }

    private func premiumOffer(_ pass: BattlePass) -> some View {
        RallyUIKit.LuxePanel(tint: pass.premiumUnlocked ? RallyUIKit.Palette.lime : RallyUIKit.Palette.rose) {
            VStack(alignment: .leading, spacing: 12) {
                RallyUIKit.EditorialEyebrow(
                    text: pass.premiumUnlocked ? "Premium active" : "Premium track",
                    tint: pass.premiumUnlocked ? RallyUIKit.Palette.lime : RallyUIKit.Palette.rose
                )
                Text(pass.premiumUnlocked ? "Premium unlocked" : "Upgrade to Premium")
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
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
        }
    }

    private func togglePremium() {
        guard let pass = battlePass else { return }
        pass.premiumUnlocked.toggle()
        try? modelContext.save()
    }

    private func rewardStatusChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
            Text(value)
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
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
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.rose) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                RallyUIKit.EditorialEyebrow(text: "Rival mode", tint: RallyUIKit.Palette.rose)
                Text("Pick your next test")
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text("Choose a rival, chase their target, and turn one run into a real head-to-head session.")
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
            }
        }
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
                HStack(spacing: 8) {
                    rivalChip(opponent.style, tint: RallyUIKit.Palette.champagne)
                    rivalChip("+\(opponent.rewardCoins) coins", tint: RallyUIKit.Palette.gold)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Lvl. \(opponent.level)")
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Image(systemName: "scope")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(RallyUIKit.Palette.rose)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .stroke(RallyUIKit.Palette.line, lineWidth: 1)
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((result.didWin ? RallyUIKit.Palette.lime : RallyUIKit.Palette.coral).opacity(0.14))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .stroke(RallyUIKit.Palette.line, lineWidth: 1)
        )
    }

    private func rivalChip(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.14)))
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

    private var highlightStats: [(title: String, value: String, tint: Color)] {
        [
            ("Games", "\(insights.totalGames)", RallyUIKit.Palette.cyan),
            ("Wins", "\(insights.totalWins)", RallyUIKit.Palette.gold),
            ("Perfects", "\(insights.totalPerfectHits)", RallyUIKit.Palette.rose)
        ]
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
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                RallyUIKit.EditorialEyebrow(text: "Performance", tint: RallyUIKit.Palette.cyan)
                Text("Session pulse")
                    .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text("Track how your rally rhythm, scoring, and seasonal momentum are moving.")
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))

                HStack(spacing: 10) {
                    ForEach(highlightStats, id: \.title) { item in
                        statBubble(label: item.title, value: item.value, tint: item.tint)
                    }
                }
            }
        }
    }

    private var statTiles: some View {
        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
            Text("Breakdown")
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)

            HStack(spacing: 12) {
                analyticsTile(title: "Average Score", value: "\(insights.averageScore)", tint: RallyUIKit.Palette.gold)
                analyticsTile(title: "Average Accuracy", value: "\(Int((insights.averageAccuracy * 100).rounded()))%", tint: RallyUIKit.Palette.cyan)
            }

            HStack(spacing: 12) {
                analyticsTile(title: "Best Combo", value: "\(insights.averageCombo)", tint: RallyUIKit.Palette.rose)
                analyticsTile(title: "Recent Win Rate", value: "\(Int((insights.recentWinRate * 100).rounded()))%", tint: RallyUIKit.Palette.champagne)
            }
        }
    }

    private var engagementCard: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.rose) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                RallyUIKit.EditorialEyebrow(text: "Momentum", tint: RallyUIKit.Palette.rose)
                Text("Engagement")
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)

                HStack(alignment: .firstTextBaseline) {
                    Text("\(insights.achievementsUnlocked)")
                        .font(RallyUIKit.Typography.display(28, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text("achievements unlocked")
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.78))
                }

                ProgressView(value: insights.seasonalProgress)
                    .tint(RallyUIKit.Palette.rose)

                HStack {
                    Text("Seasonal event completion")
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.74))
                    Spacer()
                    Text("\(Int((insights.seasonalProgress * 100).rounded()))%")
                        .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                }
            }
        }
    }

    private func statBubble(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                .foregroundStyle(tint)
            Text(label)
                .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        )
    }

    private func analyticsTile(title: String, value: String, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(value)
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    .foregroundStyle(tint)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }
}

struct SeasonalEventsView: View {
    @Query private var events: [SeasonalEvent]

    var body: some View {
        ScrollView {
            VStack(spacing: RallyUIKit.Spacing.md) {
                if let event = events.first {
                    RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.rose) {
                        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                            RallyUIKit.EditorialEyebrow(text: "Seasonal event", tint: RallyUIKit.Palette.rose)
                            Text(event.title)
                                .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text(event.subtitle)
                                .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.82))
                            Text(event.descriptionText)
                                .font(RallyUIKit.Typography.body(.body, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.84))

                            HStack(spacing: 10) {
                                eventChip(title: event.goalDescription, tint: RallyUIKit.Palette.champagne)
                                eventChip(title: event.isCompleted ? "Complete" : "\(event.daysRemaining)d left", tint: event.isCompleted ? RallyUIKit.Palette.lime : RallyUIKit.Palette.rose)
                            }

                            ProgressView(value: event.progressFraction)
                                .tint(RallyUIKit.Palette.rose)

                            HStack(alignment: .firstTextBaseline) {
                                Text("\(event.progress)/\(event.target)")
                                    .font(RallyUIKit.Typography.display(28, weight: .bold))
                                    .foregroundStyle(RallyUIKit.Palette.frost)
                                Text("event progress")
                                    .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.78))
                                Spacer()
                                rewardBadge(event.rewardCoins)
                            }
                        }
                    }
                } else {
                    RallyUIKit.SectionCard {
                        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xs) {
                            Text("No active seasonal events right now.")
                                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text("The next live event will show up here as soon as Rally opens a new campaign window.")
                                .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(RallyUIKit.Spacing.md)
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle("Seasonal Events")
    }

    private func eventChip(title: String, tint: Color) -> some View {
        Text(title)
            .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    private func rewardBadge(_ coins: Int) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(coins)")
                .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.gold)
            Text("coins")
                .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.68))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(RallyUIKit.Palette.gold.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .stroke(RallyUIKit.Palette.gold.opacity(0.2), lineWidth: 1)
        )
    }
}
