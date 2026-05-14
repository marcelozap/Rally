import SwiftUI
import SwiftData
import SpriteKit

// MARK: - Tab identity

enum RallyTab: Hashable {
    case home, play, logs, journal, shop
}

// MARK: - Root

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var avatarConfigs: [AvatarConfig]

    @State private var selectedTab: RallyTab = .home
    @State private var logsSection: LogsSection = .training

    var body: some View {
        Group {
            if let avatar = avatarConfigs.first {
                if avatar.hasCompletedSetup {
                    mainTabs
                } else {
                    NavigationStack {
                        AvatarCustomizerView(config: avatar, isFirstLaunch: true)
                    }
                    .transition(.opacity)
                }
            } else {
                // Defensive fallback — `RallyApp.seedIfNeeded` should already
                // have inserted one before this view appears.
                ProgressView()
                    .tint(.cyan)
                    .onAppear {
                        let cfg = AvatarConfig()
                        modelContext.insert(cfg)
                        try? modelContext.save()
                    }
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: avatarConfigs.first?.hasCompletedSetup ?? false)
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab, logsSection: $logsSection)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(RallyTab.home)

            GameContainerView()
                .tabItem { Label("Play", systemImage: "tennis.racket") }
                .tag(RallyTab.play)

            LogsView(section: $logsSection)
                .tabItem { Label("Logs", systemImage: "list.clipboard.fill") }
                .tag(RallyTab.logs)

            JournalView()
                .tabItem { Label("Journal", systemImage: "book.fill") }
                .tag(RallyTab.journal)

            ShopView()
                .tabItem { Label("Shop", systemImage: "bag.fill") }
                .tag(RallyTab.shop)
        }
        .tint(.cyan)
    }
}

// MARK: - Game container

/// Hosts the SpriteKit `GameScene`. Lives inside the Play tab. The scene is
/// (re)created when this view appears so each visit starts a fresh session.
struct GameContainerView: View {
    @State private var scene: GameScene? = nil
    @State private var sessionKey = UUID()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let scene = scene {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .id(sessionKey)
            }

            Button {
                sessionKey = UUID()
                scene = makeScene()
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding()
            }
        }
        .onAppear {
            if scene == nil {
                scene = makeScene()
            }
        }
    }

    private func makeScene() -> GameScene {
        let s = GameScene(size: UIScreen.main.bounds.size)
        s.scaleMode = .resizeFill
        return s
    }
}
