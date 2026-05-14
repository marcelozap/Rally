import SwiftUI
import SwiftData

@main
struct RallyApp: App {

    /// Shared SwiftData container. Holds the user's avatar config plus all
    /// log entries (training, match, journal). Catalog content (shop items,
    /// vendors) is not in SwiftData — it lives in code.
    let modelContainer: ModelContainer

    @StateObject private var authSession = AuthSession()

    init() {
        // Build the container before touching any view code so first-launch
        // queries don't race the schema bring-up.
        do {
            modelContainer = try ModelContainer(
                for: AvatarConfig.self,
                TrainingSession.self,
                MatchEntry.self,
                JournalEntry.self,
                PlayerProgress.self
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
            RootView()
                .environmentObject(authSession)
        }
        .modelContainer(modelContainer)
    }

    /// Seed the singleton rows on a fresh install:
    ///
    /// - `AvatarConfig` — gates the first-launch customizer.
    /// - `PlayerProgress` — backing record for coins/XP/streak/best scores.
    ///
    /// Both are idempotent: we only insert when the table is empty.
    private static func seedIfNeeded(container: ModelContainer) {
        let context = ModelContext(container)

        let avatars = (try? context.fetch(FetchDescriptor<AvatarConfig>())) ?? []
        if avatars.isEmpty {
            context.insert(AvatarConfig())
        }

        let progress = (try? context.fetch(FetchDescriptor<PlayerProgress>())) ?? []
        if progress.isEmpty {
            context.insert(PlayerProgress())
        }

        try? context.save()
    }
}
