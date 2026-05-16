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

    @StateObject private var viewModel = GameSessionViewModel()
    @State private var scene: GameScene? = nil
    @State private var sessionKey = UUID()
    @State private var reflectionPrompt: JournalPrompt? = nil

    /// Called when the player taps "Back to Home" from the overlay.
    /// Wired by `ContentView` so we can switch the selected tab.
    var onExit: () -> Void = {}

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let scene = scene {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .id(sessionKey)
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
                        // Build the prefilled prompt lazily so the body
                        // reflects whatever the latest run was, not the one
                        // that opened the view.
                        reflectionPrompt = JournalPromptLibrary
                            .sessionReflectionPrompt(for: result, outcome: outcome)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
                .zIndex(10)
            }
        }
        .onAppear {
            if scene == nil { scene = makeScene() }
            // Generate today's challenges if they don't exist yet
            DailyChallengeMgr.generateDailyIfNeeded(modelContext: modelContext)
            viewModel.bindIfNeeded { result in
                handleSessionEnded(result: result)
            }
        }
        .sheet(item: $reflectionPrompt) { prompt in
            NavigationStack {
                JournalEditorView(entry: nil, seedPrompt: prompt)
            }
        }
        .animation(.easeOut(duration: 0.35), value: viewModel.lastResult != nil)
    }

    // MARK: - Lifecycle helpers

    private func makeScene() -> GameScene {
        let s = GameScene(size: UIScreen.main.bounds.size)
        s.scaleMode = .resizeFill
        return s
    }

    private func restart() {
        viewModel.dismiss()
        sessionKey = UUID()
        scene = makeScene()
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
        
        // Update daily challenges
        DailyChallengeMgr.updateChallenges(from: result, modelContext: modelContext)
        
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
