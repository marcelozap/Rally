import SwiftUI

@main
struct RallyApp: App {
    init() {
        // Wire managers to the event bus exactly once, at process start.
        // Order does not matter — all three subscribe independently.
        _ = HapticManager.shared
        _ = AudioManager.shared
        _ = ParticleManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
