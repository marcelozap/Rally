import SwiftUI

/// The celebratory end-of-run summary.
///
/// This view is the single most important "feels like a real game" surface
/// we ship. It rewards the player visually for what they just did, hands
/// them coins/XP, and offers a one-tap "Play Again" so the loop is friction
/// free. Tuned so the average run ends with at least one piece of good news
/// (new best, level up, streak day) — see `Rewards`.
struct GameOverView: View {

    let result: GameResult
    let outcome: Rewards.Outcome
    let onPlayAgain: () -> Void
    let onExit: () -> Void
    /// Optional — when provided, a "Log how it felt" CTA appears between
    /// "Play Again" and "Back to Home" and routes the player into the
    /// journal editor with a Rally-focus prompt prefilled from `result`.
    /// Default is a no-op so existing previews/tests don't need updating.
    var onLogReflection: (() -> Void)? = nil

    @State private var displayScore: Int = 0
    @State private var fanfareIn: Bool = false
    @State private var statsIn: Bool = false
    @State private var actionsIn: Bool = false
    @State private var showingShareSheet: Bool = false

    var body: some View {
        ZStack {
            backdrop
            ScrollView(showsIndicators: false) {
                VStack(spacing: RallyUIKit.Spacing.xl - 2) {
                    heroPanel
                    matchIdentityStrip
                    segmentedNarrative
                    rewardsStrip
                    newAchievementsStrip
                    actionButtons
                }
                .padding(.horizontal, RallyUIKit.Spacing.lg + 2)
                .padding(.vertical, RallyUIKit.Spacing.xl + 6)
            }
        }
        .ignoresSafeArea()
        .onAppear { runEntranceTimeline() }
        .sheet(isPresented: $showingShareSheet) {
            shareSheet
        }
    }

    private var heroPanel: some View {
        RallyUIKit.LuxePanel(tint: outcome.isNewBestScore ? RallyUIKit.Palette.gold : RallyUIKit.Palette.cyan) {
            VStack(spacing: 20) {
                fanfare
                scoreCounter
                statsGrid
            }
        }
        .overlay(alignment: .topLeading) {
            RallyUIKit.EditorialEyebrow(
                text: "Post Match",
                tint: outcome.isNewBestScore ? RallyUIKit.Palette.gold : RallyUIKit.Palette.champagne
            )
            .offset(x: 18, y: -12)
        }
    }

    // MARK: - Sections

    private var backdrop: some View {
        ZStack {
            RallyUIKit.screenBackground
            RadialGradient(
                colors: [RallyUIKit.Palette.gold.opacity(0.14), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 380
            )
            .blendMode(.screen)
        }
    }

    @ViewBuilder
    private var fanfare: some View {
        VStack(spacing: RallyUIKit.Spacing.xxs + 2) {
            Text(headline)
                .font(RallyUIKit.Typography.label(.title3, weight: .heavy))
                .tracking(2)
                .foregroundStyle(headlineGradient)
                .scaleEffect(fanfareIn ? 1 : 0.7)
                .opacity(fanfareIn ? 1 : 0)
            if outcome.isNewBestScore {
                Text("NEW PERSONAL BEST")
                    .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(RallyUIKit.Palette.gold)
                    .opacity(fanfareIn ? 1 : 0)
            } else if outcome.didLevelUp {
                Text("LEVEL UP — NOW LV. \(outcome.newLevel)")
                    .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(RallyUIKit.Palette.cyan)
                    .opacity(fanfareIn ? 1 : 0)
            } else if outcome.streakIncreased && outcome.newStreak > 1 {
                Text("\(outcome.newStreak)-DAY STREAK")
                    .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(RallyUIKit.Palette.rose)
                    .opacity(fanfareIn ? 1 : 0)
            }
        }
    }

    private var headline: String {
        if outcome.isNewBestScore { return "NEW BEST" }
        if outcome.didLevelUp     { return "LEVEL UP" }
        // Promote the narrative headline only when we have segment data —
        // older payloads (no segments[]) fall back to "RUN COMPLETE".
        if !result.segments.isEmpty {
            return result.narrativeHeadline.uppercased()
        }
        return "RUN COMPLETE"
    }

    /// Per-third accuracy strip plus an optional subhead ("Most Perfects
    /// landed mid-match"). Rendered between the stat tiles and the rewards
    /// strip so the *story* of the run gets a beat of its own.
    @ViewBuilder
    private var segmentedNarrative: some View {
        if result.segments.count == 3 {
            VStack(spacing: RallyUIKit.Spacing.xs) {
                HStack(spacing: RallyUIKit.Spacing.xs + 2) {
                    segmentBar(label: "1st", stats: result.segments[0])
                    segmentBar(label: "2nd", stats: result.segments[1])
                    segmentBar(label: "3rd", stats: result.segments[2])
                }
                if let subhead = result.narrativeSubhead {
                    Text(subhead)
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .opacity(statsIn ? 1 : 0)
            .offset(y: statsIn ? 0 : 16)
        }
    }

    private func segmentBar(label: String, stats: SegmentStats) -> some View {
        let accuracy = stats.accuracy
        let tint: Color = {
            switch accuracy {
            case 0.85...: return RallyUIKit.Palette.cyan
            case 0.65...: return RallyUIKit.Palette.gold
            default:      return RallyUIKit.Palette.rose
            }
        }()
        return VStack(spacing: RallyUIKit.Spacing.xxs) {
            Text(label.uppercased())
                .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                .tracking(2)
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.56))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(tint.opacity(0.85))
                        .frame(width: max(2, geo.size.width * CGFloat(accuracy)))
                }
            }
            .frame(height: 8)
            Text("\(Int((accuracy * 100).rounded()))%")
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var headlineGradient: LinearGradient {
        if outcome.isNewBestScore {
            return LinearGradient(
                colors: [RallyUIKit.Palette.gold, RallyUIKit.Palette.rose],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        if outcome.didLevelUp {
            return LinearGradient(
                colors: [RallyUIKit.Palette.cyan, RallyUIKit.Palette.teal],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color.white.opacity(0.85), Color.white.opacity(0.6)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var scoreCounter: some View {
        VStack(spacing: 8) {
            Text("\(displayScore)")
                .font(RallyUIKit.Typography.display(92, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [RallyUIKit.Palette.frost, RallyUIKit.Palette.champagne],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: RallyUIKit.Palette.cyan.opacity(0.22), radius: 24, x: 0, y: 12)
                .contentTransition(.numericText())
                .monospacedDigit()
            Text("Match score")
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .tracking(2.8)
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
        }
    }

    private var statsGrid: some View {
        HStack(spacing: RallyUIKit.Spacing.sm + 2) {
            AnimatedStatTile(value: "\(result.maxCombo)", label: "Max Combo", tint: RallyUIKit.Palette.cyan)
            AnimatedStatTile(value: "\(Int((result.accuracy * 100).rounded()))%", label: "Accuracy", tint: RallyUIKit.Palette.champagne)
            AnimatedStatTile(value: "\(result.perfectHits)", label: "Perfects", tint: RallyUIKit.Palette.rose)
        }
        .opacity(statsIn ? 1 : 0)
        .offset(y: statsIn ? 0 : 12)
    }

    @ViewBuilder
    private var matchIdentityStrip: some View {
        let highlights = result.matchStoryHighlights
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xs + 2) {
                HStack {
                    RallyUIKit.EditorialEyebrow(text: "Match Story", tint: RallyUIKit.Palette.cyan)
                    Spacer(minLength: 0)
                }
                HStack(spacing: RallyUIKit.Spacing.xs + 2) {
                    ForEach(Array(highlights.enumerated()), id: \.offset) { item in
                        matchStoryChip(
                            value: item.element.value,
                            label: item.element.label,
                            tint: colorToken(named: item.element.tint)
                        )
                    }
                }
            }
            .padding(RallyUIKit.Spacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.lg)
                    .stroke(RallyUIKit.Palette.line, lineWidth: 1)
            )
            .opacity(statsIn ? 1 : 0)
            .offset(y: statsIn ? 0 : 14)
        }
    }

    @ViewBuilder
    private var rewardsStrip: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.gold) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                RallyUIKit.EditorialEyebrow(text: "Rewards", tint: RallyUIKit.Palette.gold)
                HStack(spacing: RallyUIKit.Spacing.sm) {
                    rewardChip(
                        icon: "circle.hexagongrid.fill",
                        text: "+\(outcome.coinsEarned)",
                        sub: "coins",
                        tint: RallyUIKit.Palette.gold
                    )
                    rewardChip(
                        icon: "bolt.fill",
                        text: "+\(outcome.xpEarned)",
                        sub: "xp",
                        tint: RallyUIKit.Palette.cyan
                    )
                }
                if outcome.streakIncreased && outcome.newStreak > 1 {
                    HStack(spacing: RallyUIKit.Spacing.xs) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(RallyUIKit.Palette.rose)
                        Text("Day \(outcome.newStreak) of your streak — bonus coins added")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.74))
                    }
                    .padding(.horizontal, RallyUIKit.Spacing.sm)
                    .padding(.vertical, RallyUIKit.Spacing.xs)
                    .background(
                        Capsule().fill(RallyUIKit.Palette.rose.opacity(0.12))
                    )
                    .overlay(
                        Capsule().stroke(RallyUIKit.Palette.rose.opacity(0.35), lineWidth: 1)
                    )
                }
            }
        }
        .opacity(statsIn ? 1 : 0)
        .offset(y: statsIn ? 0 : 18)
    }

    @ViewBuilder
    private var newAchievementsStrip: some View {
        let badges = outcome.newBadgesEarned.compactMap(BadgeDefinition.init(rawValue:))
        if !badges.isEmpty {
            RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.gold) {
                VStack(spacing: RallyUIKit.Spacing.xs + 2) {
                    HStack(spacing: RallyUIKit.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(RallyUIKit.Palette.gold)
                        Text("New Achievement!")
                            .font(RallyUIKit.Typography.label(.callout, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Spacer()
                    }
                    HStack(spacing: RallyUIKit.Spacing.sm) {
                        ForEach(badges, id: \.rawValue) { badge in
                            achievementBadgeCard(badge)
                        }
                    }
                }
            }
            .opacity(statsIn ? 1 : 0)
            .offset(y: statsIn ? 0 : 18)
        }
    }

    private func achievementBadgeCard(_ badge: BadgeDefinition) -> some View {
        let metadata = badge.metadata
        let tint = Color(hex: metadata.color) ?? RallyUIKit.Palette.cyan

        return VStack(spacing: RallyUIKit.Spacing.xxs) {
            RallyUIKit.IconBadge(systemName: metadata.icon, tint: tint, size: 42)
            Text(metadata.title)
                .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(RallyUIKit.Spacing.xs + 2)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm).fill(Color.white.opacity(0.04)))
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm)
                .stroke(tint.opacity(0.5), lineWidth: 1)
        )
    }

    private func rewardChip(icon: String, text: String, sub: String, tint: Color) -> some View {
        HStack(spacing: RallyUIKit.Spacing.xs + 2) {
            RallyUIKit.IconBadge(systemName: icon, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(sub)
                    .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.56))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RallyUIKit.Spacing.md)
        .padding(.vertical, RallyUIKit.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }

    private func matchStoryChip(value: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xxs + 2) {
            Text("\(value)")
                .font(RallyUIKit.Typography.title(.title3, weight: .heavy))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label.uppercased())
                .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RallyUIKit.Spacing.sm)
        .padding(.vertical, RallyUIKit.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }

    private func colorToken(named token: String) -> Color {
        switch token {
        case "gold":
            return RallyUIKit.Palette.gold
        case "rose":
            return RallyUIKit.Palette.rose
        default:
            return RallyUIKit.Palette.cyan
        }
    }

    private var actionButtons: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.champagne) {
            VStack(spacing: RallyUIKit.Spacing.xs + 2) {
                Button(action: onPlayAgain) {
                    HStack(spacing: RallyUIKit.Spacing.xs + 2) {
                        Image(systemName: "arrow.clockwise")
                        Text("Play Again")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: RallyUIKit.Palette.cyan))
                Button(action: { showingShareSheet = true }) {
                    HStack(spacing: RallyUIKit.Spacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Score")
                    }
                }
                .buttonStyle(GhostButtonStyle())
                if let onLogReflection = onLogReflection {
                    Button(action: onLogReflection) {
                        HStack(spacing: RallyUIKit.Spacing.xs) {
                            Image(systemName: "square.and.pencil")
                            Text("Log how it felt")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.rose))
                }
                Button(action: onExit) {
                    Text("Back to Home")
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
        .opacity(actionsIn ? 1 : 0)
        .offset(y: actionsIn ? 0 : 16)
    }

    private var shareSheet: some View {
        let shareText = "🎾 I just scored \(result.finalScore) points in Rally! Max combo: \(result.maxCombo) 🔥 \(outcome.isNewBestScore ? "New personal best!" : "") #RallyGame"
        return ShareLink(item: shareText) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    // MARK: - Entrance

    private func runEntranceTimeline() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
            fanfareIn = true
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.15)) {
            displayScore = result.finalScore
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            statsIn = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
            actionsIn = true
        }
    }
}
