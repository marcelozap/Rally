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

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 22) {
                fanfare
                scoreCounter
                statsGrid
                segmentedNarrative
                rewardsStrip
                actionButtons
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 36)
        }
        .ignoresSafeArea()
        .onAppear { runEntranceTimeline() }
    }

    // MARK: - Sections

    private var backdrop: some View {
        ZStack {
            Color.black.opacity(0.93)
            RadialGradient(
                colors: [Color.cyan.opacity(0.18), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 380
            )
            .blendMode(.screen)
        }
    }

    @ViewBuilder
    private var fanfare: some View {
        VStack(spacing: 6) {
            Text(headline)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .tracking(2)
                .foregroundStyle(headlineGradient)
                .scaleEffect(fanfareIn ? 1 : 0.7)
                .opacity(fanfareIn ? 1 : 0)
            if outcome.isNewBestScore {
                Text("NEW PERSONAL BEST")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(Color.yellow)
                    .opacity(fanfareIn ? 1 : 0)
            } else if outcome.didLevelUp {
                Text("LEVEL UP — NOW LV. \(outcome.newLevel)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(Color.cyan)
                    .opacity(fanfareIn ? 1 : 0)
            } else if outcome.streakIncreased && outcome.newStreak > 1 {
                Text("\(outcome.newStreak)-DAY STREAK")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(Color.pink)
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
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    segmentBar(label: "1st", stats: result.segments[0])
                    segmentBar(label: "2nd", stats: result.segments[1])
                    segmentBar(label: "3rd", stats: result.segments[2])
                }
                if let subhead = result.narrativeSubhead {
                    Text(subhead)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
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
            case 0.85...: return .cyan
            case 0.65...: return .yellow
            default:      return .pink
            }
        }()
        return VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
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
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var headlineGradient: LinearGradient {
        if outcome.isNewBestScore {
            return LinearGradient(
                colors: [Color.yellow, Color.pink],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        if outcome.didLevelUp {
            return LinearGradient(
                colors: [Color.cyan, Color.blue],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color.white.opacity(0.85), Color.white.opacity(0.6)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var scoreCounter: some View {
        Text("\(displayScore)")
            .font(.system(size: 96, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .cyan.opacity(0.5), radius: 16, x: 0, y: 0)
            .contentTransition(.numericText())
            .monospacedDigit()
    }

    private var statsGrid: some View {
        HStack(spacing: 14) {
            statTile(value: "\(result.maxCombo)", label: "Max Combo", tint: .cyan)
            statTile(value: "\(Int((result.accuracy * 100).rounded()))%", label: "Accuracy", tint: .cyan)
            statTile(value: "\(result.perfectHits)", label: "Perfects", tint: .pink)
        }
        .opacity(statsIn ? 1 : 0)
        .offset(y: statsIn ? 0 : 12)
    }

    private func statTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var rewardsStrip: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                rewardChip(
                    icon: "circle.hexagongrid.fill",
                    text: "+\(outcome.coinsEarned)",
                    sub: "coins",
                    tint: .yellow
                )
                rewardChip(
                    icon: "bolt.fill",
                    text: "+\(outcome.xpEarned)",
                    sub: "xp",
                    tint: .cyan
                )
            }
            if outcome.streakIncreased && outcome.newStreak > 1 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.pink)
                    Text("Day \(outcome.newStreak) of your streak — bonus coins added")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color.pink.opacity(0.12))
                )
                .overlay(
                    Capsule().stroke(Color.pink.opacity(0.35), lineWidth: 1)
                )
            }
        }
        .opacity(statsIn ? 1 : 0)
        .offset(y: statsIn ? 0 : 18)
    }

    private func rewardChip(icon: String, text: String, sub: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(sub)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: onPlayAgain) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                    Text("Play Again")
                }
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(
                            colors: [Color.cyan, Color(red: 0.4, green: 0.95, blue: 1.0)],
                            startPoint: .top, endPoint: .bottom
                        ))
                )
            }
            if let onLogReflection = onLogReflection {
                Button(action: onLogReflection) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                        Text("Log how it felt")
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.cyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                    )
                }
            }
            Button(action: onExit) {
                Text("Back to Home")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .opacity(actionsIn ? 1 : 0)
        .offset(y: actionsIn ? 0 : 16)
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
