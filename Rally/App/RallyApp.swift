import SwiftUI

@main
struct RallyApp: App {

    init() {
        // Wire managers to the event bus at process start. Order is
        // irrelevant — each subscribes independently.
        _ = HapticManager.shared
        _ = AudioManager.shared
        _ = ParticleManager.shared

        // Eliminate first-touch latency: force one no-op pass through each
        // engine so the audio I/O graph and the haptic dispatch path are
        // already warm by the time the player taps PLAY.
        AudioManager.shared.prewarm()
        HapticManager.shared.prewarm()
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
