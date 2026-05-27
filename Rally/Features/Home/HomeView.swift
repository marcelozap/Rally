import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var auth: AuthSession
    @Query private var avatarConfigs: [AvatarConfig]
    @Query private var progressRecords: [PlayerProgress]
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainings: [TrainingSession]
    @Query(sort: \MatchEntry.date, order: .reverse) private var matches: [MatchEntry]
    @Query(sort: \JournalEntry.date, order: .reverse) private var journal: [JournalEntry]
    @Query(sort: \DailyChallenge.createdDate, order: .reverse) private var dailyChallenges: [DailyChallenge]
    @Query(sort: \Achievement.earnedDate, order: .reverse) private var achievements: [Achievement]
    @Query private var battlePasses: [BattlePass]
    @Query(sort: \SeasonalEvent.startDate, order: .reverse) private var seasonalEvents: [SeasonalEvent]
    @Query(sort: \RivalChallenge.completedDate, order: .reverse) private var rivalHistory: [RivalChallenge]

    @Binding var selectedTab: RallyTab
    @Binding var logsSection: LogsSection

    @State private var showingTrainingEditor = false
    @State private var showingMatchEditor = false
    @State private var showingJournalEditor = false

    private var avatar: AvatarConfig? { avatarConfigs.first }
    private var progress: PlayerProgress? { progressRecords.first }
    private var battlePass: BattlePass? { battlePasses.first }
    private var featuredSeasonEvent: SeasonalEvent? { seasonalEvents.first }
    private var todaysChallenges: [DailyChallenge] {
        dailyChallenges.filter { Calendar.current.isDateInToday($0.createdDate) }
    }
    private var recentAchievements: [Achievement] {
        Array(achievements.prefix(4))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RallyUIKit.Spacing.lg) {
                    if auth.isGuestMode {
                        guestOfflineBanner
                    }
                    avatarCard
                    playerBadge
                    quickActions
                    competitionSummarySection
                    seasonalEventSection
                    dailyChallengesSection
                    recentAchievementsSection
                    courtAtlasSection
                    weeklyStats
                    recentJournal
                }
                .padding(.horizontal, RallyUIKit.Spacing.md)
                .padding(.vertical, RallyUIKit.Spacing.sm)
            }
            .background(RallyUIKit.screenBackground)
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if auth.isGuestMode {
                            Label("Offline on this device", systemImage: "wifi.slash")
                        }
                        if let email = auth.userEmail {
                            Label(email, systemImage: "envelope.fill")
                        }
                        Button(auth.isGuestMode ? "Leave offline mode…" : "Sign out", role: .destructive) {
                            auth.logout()
                        }
                    } label: {
                        Image(systemName: "person.text.rectangle")
                            .foregroundStyle(RallyUIKit.Palette.champagne)
                    }
                    .accessibilityLabel("Account")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let avatar = avatar {
                        NavigationLink {
                            AvatarCustomizerView(config: avatar)
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(RallyUIKit.Palette.champagne)
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

    private var guestOfflineBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.title3)
                .foregroundStyle(RallyUIKit.Palette.gold)
            Text("You're offline — data stays on this device. Tap Account (top left) → Leave offline mode… when you want to sign in and sync.")
                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RallyUIKit.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).fill(RallyUIKit.Palette.gold.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).stroke(RallyUIKit.Palette.gold.opacity(0.28), lineWidth: 1))
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
                    RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.cyan.opacity(0.28)) {
                        AvatarView(config: avatar, subtlePerspective: true)
                            .frame(height: 320)
                    }
                    VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xxs) {
                        Text(avatar.playerName)
                            .font(RallyUIKit.Typography.title(.title, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text(equippedSummary(avatar))
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.68))
                    }
                    .padding(RallyUIKit.Spacing.lg)
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
            RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.cyan.opacity(0.26)) {
                VStack(spacing: RallyUIKit.Spacing.sm) {
                    HStack(spacing: RallyUIKit.Spacing.md) {
                        levelBadge(p)
                        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xxs) {
                            Text("Level \(p.level)")
                                .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text("\(p.xpToNextLevel) XP to lv. \(p.level + 1)")
                                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.68))
                            levelBar(progress: p.levelProgress)
                                .frame(height: 5)
                        }
                        Spacer()
                    }
                    HStack(spacing: RallyUIKit.Spacing.xs + 2) {
                        badgeChip(icon: "circle.hexagongrid.fill", value: "\(p.coins)", label: "coins", tint: RallyUIKit.Palette.gold)
                        badgeChip(icon: "star.fill", value: "\(p.bestScore)", label: "best", tint: RallyUIKit.Palette.cyan)
                        badgeChip(icon: "flame.fill", value: "\(p.dailyStreak)d", label: "streak", tint: RallyUIKit.Palette.rose)
                    }
                }
            }
        }
    }

    private func levelBadge(_ p: PlayerProgress) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [RallyUIKit.Palette.champagne, RallyUIKit.Palette.gold, RallyUIKit.Palette.cyan],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 56, height: 56)
            Text("\(p.level)")
                .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.obsidian)
        }
        .shadow(color: RallyUIKit.Shadow.glow(RallyUIKit.Palette.gold), radius: 14, x: 0, y: 10)
    }

    private func levelBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(
                        colors: [RallyUIKit.Palette.cyan, RallyUIKit.Palette.rose],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * CGFloat(max(0.02, progress)))
            }
        }
    }

    private func badgeChip(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: RallyUIKit.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(label)
                    .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, RallyUIKit.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(spacing: RallyUIKit.Spacing.xs + 2) {
            actionButton(icon: "tennis.racket", label: "Practice", tint: RallyUIKit.Palette.cyan, big: true) {
                selectedTab = .play
            }
            HStack(spacing: RallyUIKit.Spacing.xs + 2) {
                actionButton(icon: "figure.tennis", label: "Log training", tint: RallyUIKit.Palette.lime) {
                    showingTrainingEditor = true
                }
                actionButton(icon: "trophy", label: "Log match", tint: RallyUIKit.Palette.gold) {
                    showingMatchEditor = true
                }
                actionButton(icon: "book.closed", label: "Quick note", tint: RallyUIKit.Palette.rose) {
                    showingJournalEditor = true
                }
            }
        }
    }

    private var competitionSummarySection: some View {
        let competitionSubtitle = battlePass?.currentTier == nil
            ? "Join the race"
            : "Tier \(battlePass?.currentTier?.id ?? 1) · \(battlePass?.currentTier?.name ?? "Top 10 chase")"

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Competition", actionTitle: "Explore") {
                CompetitionOverviewView()
            }

            NavigationLink {
                CompetitionOverviewView()
            } label: {
                featureRow(
                    icon: "bolt.circle.fill",
                    iconTint: RallyUIKit.Palette.rose,
                    title: "Leaderboard sprint",
                    subtitle: competitionSubtitle
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var seasonalEventSection: some View {
        guard let event = featuredSeasonEvent else {
            return AnyView(EmptyView())
        }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Season event")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    seasonStatusPill(isActive: event.isActive)
                    NavigationLink(destination: SeasonalEventsView()) {
                        Text("View season")
                            .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                            .foregroundStyle(RallyUIKit.Palette.cyan)
                    }
                    .buttonStyle(.plain)
                }

                Text(event.title)
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)

                Text(event.descriptionText)
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.82))
                    .lineLimit(2)

                ProgressView(value: event.progressFraction)
                    .tint(RallyUIKit.Palette.rose)

                HStack(spacing: 8) {
                    statKicker(label: "Level", value: event.levelName)
                    Spacer()
                    statKicker(label: "Reward", value: "\(event.rewardCoins) coins")
                    Spacer()
                    statKicker(label: "Time", value: event.isCompleted ? "Complete" : "\(event.daysRemaining)d left")
                }
            }
            .modifier(HomeSectionCardModifier(stroke: RallyUIKit.Palette.rose.opacity(0.28)))
        )
    }

    // MARK: - Court atlas (world map)

    private var courtAtlasSection: some View {
        NavigationLink {
            CourtsMapView()
        } label: {
            featureRow(
                icon: "globe.americas.fill",
                iconTint: RallyUIKit.Palette.lime,
                title: "World tennis atlas",
                subtitle: "Iconic venues, global camps, and official booking or enrollment links"
            )
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
                            .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                            .tracking(0.3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RallyUIKit.Spacing.lg)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.title3)
                        Text(label)
                            .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), tint.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                    .stroke(tint.opacity(0.78), lineWidth: 1)
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
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            HStack(spacing: 12) {
                statTile(value: "\(recentTrain.count)", label: "sessions", tint: RallyUIKit.Palette.cyan)
                statTile(value: "\(totalMins)m", label: "trained", tint: RallyUIKit.Palette.cyan)
                statTile(value: "\(wins)-\(losses)", label: "record", tint: RallyUIKit.Palette.gold)
            }
        }
    }

    private func statTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                .foregroundStyle(tint)
            Text(label)
                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Journal preview

    @ViewBuilder
    private var recentJournal: some View {
        if let entry = journal.first {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeaderAction(title: "From the journal", actionTitle: "See all") {
                    selectedTab = .journal
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.title.isEmpty ? "Untitled entry" : entry.title)
                        .font(RallyUIKit.Typography.body(.body, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text(entry.body.isEmpty ? "No body yet." : entry.body)
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.82))
                        .lineLimit(3)
                    Text(entry.date, format: .dateTime.month().day().year())
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.5))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
    }

    // MARK: - Daily Challenges

    private var dailyChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's challenges")
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            if todaysChallenges.isEmpty {
                Text("No challenges today yet. Tap Play to get started!")
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
            } else {
                VStack(spacing: 10) {
                    ForEach(todaysChallenges, id: \.id) { challenge in
                        challengeRow(challenge)
                    }
                }
            }
        }
    }

    // MARK: - Recent Achievements

    private var recentAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent achievements")
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            if recentAchievements.isEmpty {
                Text("Unlock achievements by hitting milestones!")
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                    ForEach(recentAchievements, id: \.id) { achievement in
                        achievementTile(achievement)
                    }
                }
            }
        }
    }

    private func challengeRow(_ challenge: DailyChallenge) -> some View {
        let tint = Color(hex: challenge.colorHex) ?? RallyUIKit.Palette.cyan
        let stroke = challenge.isCompleted ? Color.green.opacity(0.5) : tint.opacity(0.24)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint)
                    .frame(width: 44, height: 44)
                    .opacity(0.2)
                Image(systemName: challenge.iconName)
                    .font(.system(.caption, design: .default).weight(.bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                HStack(spacing: 8) {
                    ProgressView(value: challenge.progress)
                        .tint(tint)
                    Text("\(challenge.currentProgress)/\(challenge.target)")
                        .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                }
            }

            Spacer()

            if challenge.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Text("+\(challenge.rewardCoins)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm).stroke(stroke, lineWidth: 1))
    }

    private func achievementTile(_ achievement: Achievement) -> some View {
        let tint = Color(hex: achievement.colorHex) ?? RallyUIKit.Palette.cyan

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint)
                    .frame(width: 56, height: 56)
                    .opacity(0.15)
                Image(systemName: achievement.iconName)
                    .font(.title2)
                    .foregroundStyle(tint)
            }
            Text(achievement.title)
                .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(achievement.rarity)
                .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm).stroke(tint.opacity(0.3), lineWidth: 1))
    }

    private func featureRow(icon: String, iconTint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: RallyUIKit.Spacing.sm + 2) {
            ZStack {
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                    .fill(iconTint.opacity(0.18))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconTint)
            }
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xxs) {
                Text(title)
                    .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(subtitle)
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.68))
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.46))
        }
        .modifier(HomeSectionCardModifier(stroke: iconTint.opacity(0.28)))
    }

    private func seasonStatusPill(isActive: Bool) -> some View {
        Text(isActive ? "Live now" : "Upcoming")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? RallyUIKit.Palette.lime : RallyUIKit.Palette.cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill((isActive ? RallyUIKit.Palette.lime : RallyUIKit.Palette.cyan).opacity(0.12))
            )
    }

    private func statKicker(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
            Text(value)
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
        }
    }

    private func sectionHeader<Destination: View>(
        title: String,
        actionTitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        HStack {
            Text(title)
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Spacer()
            NavigationLink(destination: destination()) {
                Text(actionTitle)
                    .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.cyan)
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionHeaderAction(title: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Spacer()
            Button(action: action) {
                Text(actionTitle)
                    .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.cyan)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HomeSectionCardModifier: ViewModifier {
    let stroke: Color

    func body(content: Content) -> some View {
        content
            .padding(RallyUIKit.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}
