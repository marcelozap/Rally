import SwiftUI
import SwiftData

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
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity))

            GameSessionView(onExit: { selectedTab = .home })
                .tabItem { Label("Play", systemImage: "tennis.racket") }
                .tag(RallyTab.play)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity))

            LogsView(section: $logsSection)
                .tabItem { Label("Logs", systemImage: "list.clipboard.fill") }
                .tag(RallyTab.logs)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity))

            JournalView()
                .tabItem { Label("Journal", systemImage: "book.fill") }
                .tag(RallyTab.journal)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity))

            ShopView()
                .tabItem { Label("Shop", systemImage: "bag.fill") }
                .tag(RallyTab.shop)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity))
        }
        .tint(.cyan)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
    }
}

