import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var avatarConfigs: [AvatarConfig]

    @State private var selectedTab: RallyTab = .locker
    @State private var logbookSection: LogbookSection = .training
    @State private var isPlaying = false
    @State private var gameSessionID = UUID()

    var body: some View {
        Group {
            if let avatar = avatarConfigs.first {
                if avatar.hasCompletedSetup {
                    mainShell
                } else {
                    NavigationStack {
                        AvatarCustomizerView(config: avatar, isFirstLaunch: true)
                    }
                    .transition(.opacity)
                }
            } else {
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

    private var mainShell: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .locker:
                    LockerHubView(onPlay: {
                        gameSessionID = UUID()
                        isPlaying = true
                    })
                case .logbook:
                    LogbookView(section: $logbookSection)
                case .courts:
                    NavigationStack {
                        CourtsMapView()
                            .navigationTitle("Courts")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    SoundToggleButton()
                                }
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 62)

            RallyNavBar(selection: $selectedTab)
                .zIndex(1)
        }
        .background(Color.black.ignoresSafeArea())
        .fullScreenCover(isPresented: $isPlaying, onDismiss: {
            isPlaying = false
            selectedTab = .locker
        }) {
            GameSessionView(onExit: {
                isPlaying = false
                selectedTab = .locker
            })
            .id(gameSessionID)
            .interactiveDismissDisabled(false)
        }
    }
}
