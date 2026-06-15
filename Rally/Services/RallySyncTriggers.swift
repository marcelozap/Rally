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

    /// Avatar identity and gear edits carry an expected server revision so a
    /// stale device cannot silently overwrite another device's appearance.
    /// Progress and session accruals intentionally use `pushAfterLocalSave`
    /// because the backend merges those fields with max-wins.
    static func pushAvatarAfterLocalSave(modelContext: ModelContext) {
        Task {
            await RallySyncCoordinator.pushIfAuthenticated(
                modelContext: modelContext,
                enforceAvatarRevision: true
            )
        }
    }
}
