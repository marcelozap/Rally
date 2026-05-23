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

    @AppStorage(CourtVenue.storageKey) private var courtRaw: String = CourtVenue.miamiHard.rawValue

    @StateObject private var viewModel = GameSessionViewModel()
    @State private var scene: GameScene? = nil
    @State private var viewportSize: CGSize = .zero
    @State private var sessionKey = UUID()
    @State private var reflectionPrompt: JournalPrompt? = nil
    #if DEBUG
    @State private var showTunables = false
    #endif

    /// Optional rival opponent when launching a rival challenge session.
    var rivalOpponent: RivalOpponent? = nil

    /// Called when the player taps "Back to Locker" from the overlay.
    /// Wired by `ContentView` so we can switch the selected tab.
    var onExit: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let scene = scene, geo.size.width > 1, geo.size.height > 1 {
                    SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                        .id(sessionKey)
                }

                // Top chrome only — never a full-screen hit target over the playfield.
                sessionTopBar
                    .zIndex(20)

                if let result = viewModel.lastResult, let outcome = viewModel.lastOutcome {
                    GameOverView(
                        result: result,
                        outcome: outcome,
                        onPlayAgain: { restart() },
                        onExit: { exitSession() },
                        onLogReflection: {
                            reflectionPrompt = JournalPromptLibrary
                                .sessionReflectionPrompt(for: result, outcome: outcome)
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(30)
                }
            }
            .onAppear { applyViewportSize(geo.size) }
            .onChange(of: geo.size) { _, newSize in
                applyViewportSize(newSize)
            }
        }
        .onAppear {
            DailyChallengeMgr.generateDailyIfNeeded(modelContext: modelContext)
            viewModel.bindIfNeeded { result in
                handleSessionEnded(result: result)
            }
        }
        .onDisappear {
            tearDownScene(reportResults: false)
            viewModel.prepareForExit()
        }
        .sheet(item: $reflectionPrompt) { prompt in
            NavigationStack {
                JournalEditorView(entry: nil, seedPrompt: prompt)
            }
        }
        #if DEBUG
        .sheet(isPresented: $showTunables) {
            TunablesOverlay()
        }
        #endif
        .animation(.easeOut(duration: 0.35), value: viewModel.lastResult != nil)
    }

    // MARK: - Chrome

    private var sessionTopBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(CourtVenue.allCases) { surface in
                    Button(surface.displayName) {
                        courtRaw = surface.rawValue
                        restart()
                    }
                }
            } label: {
                Label(courtLabel, systemImage: "sportscourt.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer(minLength: 0)

            #if DEBUG
            Button {
                showTunables = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            #endif

            Button(action: exitSession) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Exit game")
        }
        .padding(.horizontal, 16)
        .padding(.top, 52)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Lifecycle helpers

    private func applyViewportSize(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        viewportSize = size
        if scene == nil {
            let newScene = makeScene(size: size)
            newScene.relayoutForPresentation()
            scene = newScene
        } else {
            scene?.size = size
            scene?.relayoutForPresentation()
        }
    }

    private func exitSession() {
        viewModel.prepareForExit()
        tearDownScene(reportResults: false)
        onExit()
    }

    private func tearDownScene(reportResults: Bool) {
        if reportResults {
            scene = nil
        } else {
            scene?.abortSessionSilently()
            scene = nil
        }
    }

    private func makeScene(size: CGSize) -> GameScene {
        let s = GameScene(size: size)
        s.scaleMode = .resizeFill
        return s
    }

    private func restart() {
        viewModel.dismiss()
        sessionKey = UUID()
        guard viewportSize.width > 1, viewportSize.height > 1 else { return }
        scene = makeScene(size: viewportSize)
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
            let fetchDescriptor = FetchDescriptor<Achievement>(predicate: NSPredicate(format: "badgeId == %@", badgeId))
            let existingBadges = (try? modelContext.fetch(fetchDescriptor)) ?? []
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

    private var courtLabel: String {
        CourtVenue(rawValue: courtRaw)?.displayName ?? CourtVenue.miamiHard.displayName
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

    private var ignoresSessionEnd = false

    func bindIfNeeded(_ onEnd: @escaping (GameResult) -> Void) {
        guard !hasBound else { return }
        hasBound = true
        GameEventBus.shared.subscribe(self) { [weak self] event in
            guard let self = self else { return }
            if case .sessionEnd(let result) = event {
                guard !self.ignoresSessionEnd else { return }
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

    /// Suppresses late `.sessionEnd` events while the cover is dismissing.
    func prepareForExit() {
        ignoresSessionEnd = true
        dismiss()
    }
}
