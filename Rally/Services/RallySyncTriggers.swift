import Foundation
import SwiftData

// MARK: - Sync triggers

/// Central place so logs/journal/game saves stay consistent with `ARCHITECTURE.md` (repo root).
@MainActor
enum RallySyncTriggers {

    /// Fire-and-forget upload after any successful local `modelContext.save()` when logged in.
    static func pushAfterLocalSave(modelContext: ModelContext) {
        Task {
            await RallySyncCoordinator.pushIfAuthenticated(modelContext: modelContext)
        }
    }
}
