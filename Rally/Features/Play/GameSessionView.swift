import SwiftUI
import SpriteKit
import SwiftData

/// SwiftUI container that hosts the SpriteKit `GameScene`, listens for the
/// `sessionEnd` event, applies the rewards to `PlayerProgress`, and shows
/// the celebratory `GameOverView`.
///
/// This replaces the old `GameContainerView`. The old container just rebuilt
/// the scene on a UUID change; we still do that, but now the rebuild is
/// triggered by the "Play Again" button on the overlay rather than a manual
/// reload button.
struct GameSessionView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var progressRecords: [PlayerProgress]
    @Query private var avatarConfigs: [AvatarConfig]

    @StateObject private var viewModel = GameSessionViewModel()
    @State private var scene: GameScene? = nil
    @State private var sessionKey = UUID()
    @State private var reflectionPrompt: JournalPrompt? = nil
    @State private var viewportSize: CGSize = .zero

    /// Optional rival opponent when launching a rival challenge session.
    var rivalOpponent: RivalOpponent? = nil

    /// Called when the player taps "Back to Home" from the overlay.
    /// Wired by `ContentView` so we can switch the selected tab.
    var onExit: () -> Void = {}

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RallyUIKit.screenBackground

                if let scene = scene {
                    SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                        .frame(width: size.width, height: size.height)
                        .ignoresSafeArea()
                        .id(sessionKey)
                        .overlay(alignment: .top) {
                            sessionChrome
                        }
                        .overlay(alignment: .bottom) {
                            coachingChrome
                        }
                        .overlay {
                            matchAtmosphere
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 34)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            RallyUIKit.Palette.champagne.opacity(0.14),
                                            Color.white.opacity(0.02),
                                            RallyUIKit.Palette.cyan.opacity(0.12)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                } else {
                    loadingState
                }

                if let result = viewModel.lastResult, let outcome = viewModel.lastOutcome {
                    GameOverView(
                        result: result,
                        outcome: outcome,
                        onPlayAgain: { restart() },
                        onExit: {
                            viewModel.dismiss()
                            onExit()
                        },
                        onLogReflection: {
                            reflectionPrompt = JournalPromptLibrary
                                .sessionReflectionPrompt(for: result, outcome: outcome)
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(10)
                }
            }
            .onAppear {
                viewportSize = size
                if scene == nil {
                    scene = makeScene(for: size)
                } else {
                    syncSceneSize(to: size)
                }
                DailyChallengeMgr.generateDailyIfNeeded(modelContext: modelContext)
                viewModel.bindIfNeeded { result in
                    handleSessionEnded(result: result)
                }
            }
            .onChange(of: size.width) { _, _ in
                viewportSize = size
                syncSceneSize(to: size)
            }
            .onChange(of: size.height) { _, _ in
                viewportSize = size
                syncSceneSize(to: size)
            }
        }
        .sheet(item: $reflectionPrompt) { prompt in
            NavigationStack {
                JournalEditorView(entry: nil, seedPrompt: prompt)
            }
        }
        .animation(.easeOut(duration: 0.35), value: viewModel.lastResult != nil)
    }

    private var sessionChrome: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    RallyUIKit.EditorialEyebrow(
                        text: rivalOpponent == nil ? "Center Court Session" : "Rival Session",
                        tint: RallyUIKit.Palette.champagne
                    )
                    Text(rivalOpponent?.name ?? "Rally Performance Match")
                        .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    statusPill(icon: "dot.radiowaves.left.and.right", text: "Live")
                    statusPill(icon: "tennisball.fill", text: "Hard Court")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.black.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(RallyUIKit.Palette.line.opacity(0.92), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var coachingChrome: some View {
        HStack(spacing: 10) {
            bottomHint(icon: "figure.tennis", title: "Court Read", copy: "Longer balanced swipes shape cleaner replies.")
            bottomHint(icon: "arrow.left.and.right", title: "Recovery", copy: "Recentering fast protects the next ball.")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    private var matchAtmosphere: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.26), .clear, Color.black.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            HStack {
                LinearGradient(
                    colors: [RallyUIKit.Palette.champagne.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 90)

                Spacer()

                LinearGradient(
                    colors: [.clear, RallyUIKit.Palette.cyan.opacity(0.08)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 90)
            }
        }
        .allowsHitTesting(false)
    }

    private var loadingState: some View {
        VStack(spacing: 18) {
            RallyUIKit.IconBadge(systemName: "tennisball.fill", tint: RallyUIKit.Palette.gold, size: 60)
            Text("Preparing center court")
                .font(RallyUIKit.Typography.display(30, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Text("Loading live court, player rig, and match session.")
                .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
            ProgressView()
                .tint(RallyUIKit.Palette.cyan)
        }
        .padding(28)
    }

    private func statusPill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .font(RallyUIKit.Typography.label(.caption, weight: .bold))
        .foregroundStyle(RallyUIKit.Palette.frost)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule()
                .stroke(RallyUIKit.Palette.line, lineWidth: 1)
        )
    }

    private func bottomHint(icon: String, title: String, copy: String) -> some View {
        RallyUIKit.SurfaceTile(tint: RallyUIKit.Palette.cyan) {
            HStack(alignment: .center, spacing: 10) {
                RallyUIKit.IconBadge(systemName: icon, tint: RallyUIKit.Palette.cyan, size: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(RallyUIKit.Palette.champagne)
                    Text(copy)
                        .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Lifecycle helpers

    private func makeScene(for size: CGSize) -> GameScene {
        let initialSize = resolvedViewportSize(from: size)
        let s = GameScene(size: initialSize)
        s.scaleMode = .resizeFill
        if let avatar = avatarConfigs.first {
            s.avatarSpec = AvatarVisualSpec.from(config: avatar, preview: nil)
        }
        if let equippedRacketID = avatarConfigs.first?.equippedRacketID,
           let profile = ShopCatalog.racketProfile(id: equippedRacketID) {
            s.racketTuning = profile.gameplayTuning
        }
        return s
    }

    private func syncSceneSize(to size: CGSize) {
        let resolved = resolvedViewportSize(from: size)
        guard let scene else { return }
        guard resolved.width > 0, resolved.height > 0 else { return }
        guard scene.size != resolved else { return }
        scene.size = resolved
        scene.scaleMode = .resizeFill
    }

    private func resolvedViewportSize(from size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else {
            return UIScreen.main.bounds.size
        }
        return size
    }

    private func restart() {
        viewModel.dismiss()
        sessionKey = UUID()
        scene = makeScene(for: viewportSize)
    }

    private func handleSessionEnded(result: GameResult) {
        guard let progress = progressRecords.first ?? insertProgressIfMissing() else {
            // No persistence available — still show the summary so the run
            // isn't lost; just no rewards.
            viewModel.present(result: result, outcome: Rewards.Outcome(
                coinsEarned: 0, xpEarned: 0,
                isNewBestScore: false, isNewBestCombo: false,
                didLevelUp: false, newLevel: 1,
                newStreak: 0, streakIncreased: false
            ))
            return
        }
        let outcome = Rewards.applying(result: result, to: progress)

        // Update battle pass progression from earned XP.
        BattlePassManager.grantXP(outcome.xpEarned, to: modelContext)

        // Update seasonal event progress for this run.
        SeasonalEventManager.updateProgress(from: result, modelContext: modelContext)

        // Update daily challenges
        DailyChallengeMgr.updateChallenges(from: result, modelContext: modelContext)

        // Store rival results when this session was launched as a rival challenge.
        if let opponent = rivalOpponent {
            let didWin = result.finalScore >= opponent.targetScore
            let challengeResult = RivalChallenge(
                opponentName: opponent.name,
                targetScore: opponent.targetScore,
                playerScore: result.finalScore,
                didWin: didWin
            )
            RivalModeManager.addChallengeResult(challengeResult, modelContext: modelContext)
            if didWin {
                progress.coins += opponent.rewardCoins
            }
        }

        // Award achievements for newly earned badges and avoid duplicates
        for badgeId in outcome.newBadgesEarned {
            let existingBadges = ((try? modelContext.fetch(FetchDescriptor<Achievement>())) ?? [])
                .filter { $0.badgeId == badgeId }
            guard existingBadges.isEmpty, let badgeDef = BadgeDefinition(rawValue: badgeId) else { continue }
            let achievement = badgeDef.create()
            modelContext.insert(achievement)
            NotificationManager.notifyAchievementEarned(achievement)
        }

        try? modelContext.save()
        RallySyncTriggers.pushAfterLocalSave(modelContext: modelContext)
        viewModel.present(result: result, outcome: outcome)
    }

    /// Defensive fallback if the seed didn't run (e.g. older install). Keeps
    /// the loop intact rather than silently dropping the run.
    private func insertProgressIfMissing() -> PlayerProgress? {
        let p = PlayerProgress()
        modelContext.insert(p)
        try? modelContext.save()
        return p
    }
}

// MARK: - View model

/// Observes the `GameEventBus` for `.sessionEnd`. Stores the resulting
/// `GameResult` + computed `Outcome` so the SwiftUI overlay can render.
///
/// The bus is main-thread, and SwiftUI updates happen on the main thread,
/// so we don't need any cross-actor hops here.
@MainActor
final class GameSessionViewModel: ObservableObject {

    @Published private(set) var lastResult: GameResult? = nil
    @Published private(set) var lastOutcome: Rewards.Outcome? = nil

    private var hasBound = false

    func bindIfNeeded(_ onEnd: @escaping (GameResult) -> Void) {
        guard !hasBound else { return }
        hasBound = true
        GameEventBus.shared.subscribe(self) { [weak self] event in
            guard let self = self else { return }
            if case .sessionEnd(let result) = event {
                onEnd(result)
                _ = self // keep reference alive
            }
        }
    }

    func present(result: GameResult, outcome: Rewards.Outcome) {
        self.lastResult = result
        self.lastOutcome = outcome
    }

    func dismiss() {
        self.lastResult = nil
        self.lastOutcome = nil
    }
}
