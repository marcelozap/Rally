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
    @EnvironmentObject private var avatarAppearanceStore: RallyAvatarAppearanceStore
    @Query private var progressRecords: [PlayerProgress]
    @Query private var avatarConfigs: [AvatarConfig]

    @StateObject private var viewModel = GameSessionViewModel()
    @StateObject private var atmosphere = SessionAtmosphereModel()
    @StateObject private var gamePreferences = GamePreferences.shared
    @State private var scene: GameScene? = nil
    @State private var sessionKey = UUID()
    @State private var reflectionPrompt: JournalPrompt? = nil
    @State private var viewportSize: CGSize = .zero
    @State private var autoPlayEnabled = ProcessInfo.processInfo.arguments.contains("-RallyAutoPlay")

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
                        .overlay {
                            matchAtmosphere
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
                if scene == nil, isUsableViewport(size) {
                    scene = makeScene(for: size)
                } else {
                    syncSceneSize(to: size)
                }
                applyPreferences()
                DailyChallengeMgr.generateDailyIfNeeded(modelContext: modelContext)
                viewModel.bindIfNeeded { result in
                    handleSessionEnded(result: result)
                }
                atmosphere.bindIfNeeded()
            }
            .onChange(of: size.width) { _, _ in
                viewportSize = size
                if scene == nil, isUsableViewport(size) {
                    scene = makeScene(for: size)
                }
                syncSceneSize(to: size)
            }
            .onChange(of: size.height) { _, _ in
                viewportSize = size
                if scene == nil, isUsableViewport(size) {
                    scene = makeScene(for: size)
                }
                syncSceneSize(to: size)
            }
        }
        .onChange(of: gamePreferences.dominantHand) { _, _ in
            applyPreferences()
        }
        .onChange(of: gamePreferences.showCoachingCues) { _, _ in
            applyPreferences()
        }
        .onChange(of: gamePreferences.matchPace) { _, _ in
            applyPreferences()
        }
        .onChange(of: avatarAppearanceStore.appearance) { _, appearance in
            scene?.applyAvatarAppearance(appearance)
        }
        .sheet(item: $reflectionPrompt) { prompt in
            NavigationStack {
                JournalEditorView(entry: nil, seedPrompt: prompt)
            }
        }
        .animation(.easeOut(duration: 0.35), value: viewModel.lastResult != nil)
    }

    private var sessionChrome: some View {
        HStack(alignment: .top) {
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                exitButton
                if autoPlayEnabled {
                    aiButton
                        .scaleEffect(0.88)
                        .opacity(0.78)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
        .padding(.trailing, 14)
        .padding(.top, 42)
    }

    private var topInfoStrip: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Wall Rally")
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.gold)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 8) {
                infoPill(CourtVenue.current.displayName)
                infoPill(gamePreferences.dominantHand == .right ? "Right Hand" : "Left Hand")
                infoPill(gamePreferences.matchPace.title)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 330)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func infoPill(_ text: String) -> some View {
        Text(text)
            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
            .foregroundStyle(RallyUIKit.Palette.frost.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
    }

    private var matchAtmosphere: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.10 + atmosphere.intensity * 0.04),
                    .clear,
                    Color.black.opacity(0.16 + atmosphere.intensity * 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    atmosphere.accentColor.opacity(atmosphere.intensity * 0.22),
                    .clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: max(viewportSize.width, viewportSize.height) * 0.72
            )

            if atmosphere.breakFlash > 0.01 {
                Color.red.opacity(atmosphere.breakFlash * 0.18)
                    .transition(.opacity)
            }

            LinearGradient(
                colors: [.clear, atmosphere.accentColor.opacity(atmosphere.intensity * 0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.28), value: atmosphere.intensity)
        .animation(.easeOut(duration: 0.22), value: atmosphere.breakFlash)
    }

    private var loadingState: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.champagne) {
            VStack(spacing: 18) {
                RallyUIKit.IconBadge(systemName: "tennisball.fill", tint: RallyUIKit.Palette.gold, size: 60)
                Text("Stepping onto court")
                    .font(RallyUIKit.Typography.display(30, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                ProgressView()
                    .tint(RallyUIKit.Palette.cyan)
            }
            .frame(maxWidth: 420)
        }
        .padding(28)
    }

    private var exitButton: some View {
        Button(action: onExit) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(RallyUIKit.Palette.frost.opacity(0.82))
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.18))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.10), radius: 4, y: 2)
        .accessibilityLabel("Exit match")
    }

    private var aiButton: some View {
        Button {
            autoPlayEnabled.toggle()
            scene?.autoPlayEnabled = autoPlayEnabled
        } label: {
            Image(systemName: autoPlayEnabled ? "sparkles.rectangle.stack.fill" : "sparkles")
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(autoPlayEnabled ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.cyan)
                .frame(width: 42, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(autoPlayEnabled ? RallyUIKit.Palette.cyan : Color.black.opacity(0.40))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            autoPlayEnabled
                                ? Color.white.opacity(0.24)
                                : RallyUIKit.Palette.cyan.opacity(0.28),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .shadow(color: autoPlayEnabled ? RallyUIKit.Palette.cyan.opacity(0.18) : Color.black.opacity(0.18), radius: 14, y: 8)
        .accessibilityLabel("Toggle autoplay")
    }

    // MARK: - Lifecycle helpers

    private func makeScene(for size: CGSize) -> GameScene {
        let s = GameScene(size: size)
        s.scaleMode = .resizeFill
        if let avatar = avatarConfigs.first {
            let appearance = RallyAvatarAppearance(config: avatar)
            avatarAppearanceStore.appearance = appearance
            s.avatarAppearance = appearance
        } else {
            s.avatarAppearance = avatarAppearanceStore.appearance
        }
        if let equippedRacketID = avatarConfigs.first?.equippedRacketID,
           let profile = ShopCatalog.racketProfile(id: equippedRacketID) {
            s.racketTuning = profile.gameplayTuning
        }
        applyPreferences(to: s)
        s.autoPlayEnabled = autoPlayEnabled
        return s
    }

    private func syncSceneSize(to size: CGSize) {
        guard let scene else { return }
        guard isUsableViewport(size) else { return }
        guard scene.size != size else { return }
        scene.size = size
        scene.scaleMode = .resizeFill
    }

    private func isUsableViewport(_ size: CGSize) -> Bool {
        size.width > 0 && size.height > 0
    }

    private func restart() {
        viewModel.dismiss()
        sessionKey = UUID()
        scene = makeScene(for: viewportSize)
    }

    private func applyPreferences() {
        guard let scene else { return }
        applyPreferences(to: scene)
    }

    private func applyPreferences(to scene: GameScene) {
        scene.dominantHand = gamePreferences.dominantHand
        scene.showCoachingCues = gamePreferences.showCoachingCues
        scene.matchPace = gamePreferences.matchPace
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
        // North Star §Journal: "A played session creates a useful entry."
        JournalAutoLogger.logRallySession(
            result: result,
            modelContext: modelContext,
            appearance: avatarAppearanceStore.appearance
        )
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

private struct GameSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var preferences: GamePreferences

    let onRestartMatch: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.champagne) {
                        VStack(alignment: .leading, spacing: 12) {
                            RallyUIKit.EditorialEyebrow(text: "Match Settings", tint: RallyUIKit.Palette.champagne)
                            Text("Shape the live court around how you actually want Rally to play.")
                                .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.84))

                            HStack(spacing: 10) {
                                metaChip(icon: "hand.raised.fill", text: preferences.dominantHand.title)
                                metaChip(icon: "speedometer", text: preferences.matchPace.title)
                                metaChip(icon: preferences.isHapticsEnabled ? "waveform.path" : "waveform.path.badge.minus", text: preferences.isHapticsEnabled ? "Haptics On" : "Haptics Off")
                            }
                        }
                    }

                    RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.line) {
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader(icon: "slider.horizontal.3", title: "Controls", copy: "Fix the way the rally reads in your hands.")
                            labeledPicker("Dominant hand", selection: $preferences.dominantHand)
                            supportingCopy(preferences.dominantHand.coachingCopy)
                            labeledPicker("Match pace", selection: $preferences.matchPace)
                            supportingCopy(preferences.matchPace.subtitle)
                        }
                    }

                    RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.cyan.opacity(0.45)) {
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader(icon: "sparkles", title: "Feedback", copy: "Keep the live guidance you want and cut the noise you do not.")

                            Toggle(isOn: $preferences.showCoachingCues) {
                                toggleLabel(
                                    title: "Coaching cues",
                                    copy: "Show bottom court-read cards and in-rally guidance prompts."
                                )
                            }
                            .tint(RallyUIKit.Palette.cyan)

                            Toggle(isOn: $preferences.isHapticsEnabled) {
                                toggleLabel(
                                    title: "Vibration",
                                    copy: "Fire contact and pressure haptics during live play."
                                )
                            }
                            .tint(RallyUIKit.Palette.champagne)
                        }
                    }

                    VStack(spacing: 10) {
                        Button(action: onRestartMatch) {
                            Label("Restart Match", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.cyan))

                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 22)
            }
            .background(RallyUIKit.screenBackground.ignoresSafeArea())
            .navigationTitle("Game Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func sectionHeader(icon: String, title: String, copy: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RallyUIKit.IconBadge(systemName: icon, tint: RallyUIKit.Palette.cyan, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(copy)
                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
            }
            Spacer(minLength: 0)
        }
    }

    private func labeledPicker<T: Hashable & CaseIterable & Identifiable>(_ title: String, selection: Binding<T>) -> some View where T.AllCases == Array<T>, T: RawRepresentable, T.RawValue == String {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            HStack(spacing: RallyUIKit.Spacing.xs) {
                ForEach(Array(T.allCases)) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selection.wrappedValue = option
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.rawValue.capitalized)
                                .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                                .foregroundStyle(
                                    selection.wrappedValue == option
                                    ? RallyUIKit.Palette.obsidian
                                    : RallyUIKit.Palette.frost
                                )
                            optionSubtitle(option)
                                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                .foregroundStyle(
                                    selection.wrappedValue == option
                                    ? RallyUIKit.Palette.obsidian.opacity(0.7)
                                    : RallyUIKit.Palette.cloud.opacity(0.62)
                                )
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, RallyUIKit.Spacing.sm)
                        .padding(.vertical, RallyUIKit.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md, style: .continuous)
                                .fill(
                                    selection.wrappedValue == option
                                    ? AnyShapeStyle(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan))
                                    : AnyShapeStyle(Color.white.opacity(0.04))
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md, style: .continuous)
                                .stroke(
                                    selection.wrappedValue == option
                                    ? Color.white.opacity(0.16)
                                    : RallyUIKit.Palette.line.opacity(0.7),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func optionSubtitle<T: RawRepresentable>(_ option: T) -> Text where T.RawValue == String {
        switch option.rawValue.lowercased() {
        case "right":
            return Text("Classic read")
        case "left":
            return Text("Flip forehand side")
        case "calm":
            return Text("Longer reads")
        case "standard":
            return Text("Balanced tempo")
        case "quick":
            return Text("Sharper pressure")
        default:
            return Text("Live setting")
        }
    }

    private func supportingCopy(_ text: String) -> some View {
        Text(text)
            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.7))
    }

    private func toggleLabel(title: String, copy: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Text(copy)
                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
        }
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
            Text(text)
        }
        .font(RallyUIKit.Typography.label(.caption, weight: .bold))
        .foregroundStyle(RallyUIKit.Palette.frost)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(RallyUIKit.Palette.line, lineWidth: 1)
        )
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

/// Tracks combo tier and break flashes so SwiftUI atmosphere can react without
/// touching SpriteKit — readable even with sound off.
@MainActor
final class SessionAtmosphereModel: ObservableObject {
    @Published private(set) var intensity: Double = 0
    @Published private(set) var breakFlash: Double = 0
    @Published private(set) var accentColor: Color = RallyUIKit.Palette.cyan

    private var hasBound = false
    private var decayTask: Task<Void, Never>?

    func bindIfNeeded() {
        guard !hasBound else { return }
        hasBound = true
        GameEventBus.shared.subscribe(self) { [weak self] event in
            guard let self else { return }
            switch event {
            case .sessionStart:
                intensity = 0
                breakFlash = 0
                accentColor = RallyUIKit.Palette.cyan
            case .comboTier(let tier):
                let clamped = min(5, max(1, tier))
                intensity = Double(clamped) / 5.0
                accentColor = tierAccent(clamped)
            case .comboBreak:
                intensity = 0.08
                breakFlash = 1
                accentColor = RallyUIKit.Palette.rose
                scheduleBreakFade()
            case .hit(_, _, _, let combo, _):
                if combo > 0 {
                    let tier = min(5, max(1, (combo - 1) / 3 + 1))
                    intensity = max(intensity, Double(tier) / 5.0)
                    accentColor = tierAccent(tier)
                }
            default:
                break
            }
        }
    }

    private func tierAccent(_ tier: Int) -> Color {
        switch tier {
        case 1: return RallyUIKit.Palette.cyan
        case 2: return RallyUIKit.Palette.lime
        case 3: return RallyUIKit.Palette.gold
        case 4: return RallyUIKit.Palette.rose
        default: return RallyUIKit.Palette.champagne
        }
    }

    private func scheduleBreakFade() {
        decayTask?.cancel()
        decayTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                breakFlash = 0
            }
        }
    }
}
