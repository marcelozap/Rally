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
    @State private var logbookSection: LogbookSection = .training
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            RallyUIKit.screenBackground

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
                    setupFallback
                }
            }
            .opacity(hasAppeared ? 1 : 0.01)
            .scaleEffect(hasAppeared ? 1 : 0.985)
        }
        .preferredColorScheme(.dark)
        .task {
            if avatarConfigs.isEmpty {
                let cfg = AvatarConfig()
                modelContext.insert(cfg)
                try? modelContext.save()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) {
                hasAppeared = true
            }
        }
        .animation(.easeInOut(duration: 0.3), value: avatarConfigs.first?.hasCompletedSetup ?? false)
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab, logbookSection: $logbookSection)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(RallyTab.home)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity))

            GameSessionView(onExit: { selectedTab = .home })
                .tabItem { Label("Play", systemImage: "tennis.racket") }
                .tag(RallyTab.play)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity))

            LogbookView(section: $logbookSection)
                .tabItem { Label("Logbook", systemImage: "book.pages.fill") }
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
        .tint(RallyUIKit.Palette.cyan)
        .toolbarBackground(
            LinearGradient(
                colors: [
                    RallyUIKit.Palette.obsidian.opacity(0.98),
                    RallyUIKit.Palette.ink.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .tabBar
        )
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
    }

    private var setupFallback: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.cyan)

            VStack(spacing: 8) {
                Text("Setting up Rally")
                    .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(.white)

                Text("Preparing your avatar profile and loading the season dashboard.")
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.68))
            }

            ProgressView()
                .tint(RallyUIKit.Palette.cyan)
        }
        .padding(28)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(RallyUIKit.Palette.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 24, x: 0, y: 18)
    }
}
