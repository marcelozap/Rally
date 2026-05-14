import SwiftUI
import SwiftData

@main
struct RallyApp: App {

    /// Shared SwiftData container. Holds the user's avatar config plus all
    /// log entries (training, match, journal). Catalog content (shop items,
    /// vendors) is not in SwiftData — it lives in code.
    let modelContainer: ModelContainer

    init() {
        // Build the container before touching any view code so first-launch
        // queries don't race the schema bring-up.
        do {
            modelContainer = try ModelContainer(
                for: AvatarConfig.self,
                TrainingSession.self,
                MatchEntry.self,
                JournalEntry.self
            )
            Self.seedIfNeeded(container: modelContainer)
        } catch {
            fatalError("Rally: failed to bring up SwiftData store — \(error)")
        }

        // Wire managers to the event bus. Order is irrelevant.
        _ = HapticManager.shared
        _ = AudioManager.shared
        _ = ParticleManager.shared

        // Eliminate first-touch latency: prime the audio I/O graph and the
        // haptic engine before the player even sees the menu.
        AudioManager.shared.prewarm()
        HapticManager.shared.prewarm()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }

    /// Insert a single empty `AvatarConfig` row on a fresh install. The
    /// customizer will mark it `hasCompletedSetup = true` once the player
    /// finishes the first-launch flow.
    private static func seedIfNeeded(container: ModelContainer) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AvatarConfig>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }
        context.insert(AvatarConfig())
        try? context.save()
    }
}
