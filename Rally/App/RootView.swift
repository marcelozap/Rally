import SwiftUI
import SwiftData

/// Boots JWT validation before handing off to `ContentView` or `AuthView`.
struct RootView: View {
    @EnvironmentObject private var auth: AuthSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !auth.isBootstrapped {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView("Loading…")
                        .tint(.cyan)
                        .foregroundStyle(.white)
                }
            } else if auth.isAuthenticated {
                ContentView()
            } else {
                AuthView()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await auth.bootstrap(modelContext: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, auth.isAuthenticated, auth.isBootstrapped else { return }
            Task {
                await RallySyncCoordinator.pushIfAuthenticated(modelContext: modelContext)
            }
        }
    }
}
