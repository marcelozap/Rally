import Foundation
import Combine

/// Tracks which iconic courts the player has "checked into" and exposes
/// a published set so SwiftUI views can react.
///
/// ## Persistence
///
/// UserDefaults only — intentionally minimal. The brief is "prefer
/// UserDefaults + shop visibility filter first" so we don't reach for
/// SwiftData yet. Stored as a CSV under the key
/// `CourtUnlocks.userDefaultsKey`.
///
/// ## Privacy
///
/// The unlock action is gated by the user inside `CourtCheckIn`. This type
/// only stores the **result** (a courtID), never coordinates or accuracy
/// data. Forgetting the unlock removes the courtID; no analytics ping.
final class CourtUnlocks: ObservableObject {

    static let shared = CourtUnlocks()
    static let userDefaultsKey = "com.marcelozap.rally.courtUnlocks.v1"

    @Published private(set) var unlockedCourtIDs: Set<String>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.userDefaultsKey) ?? ""
        let ids = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        self.unlockedCourtIDs = Set(ids)
    }

    func unlock(courtID: String) {
        guard !courtID.isEmpty else { return }
        guard !unlockedCourtIDs.contains(courtID) else { return }
        unlockedCourtIDs.insert(courtID)
        persist()
    }

    func forget(courtID: String) {
        guard unlockedCourtIDs.remove(courtID) != nil else { return }
        persist()
    }

    func isUnlocked(courtID: String) -> Bool {
        unlockedCourtIDs.contains(courtID)
    }

    private func persist() {
        let csv = unlockedCourtIDs.sorted().joined(separator: ",")
        defaults.set(csv, forKey: Self.userDefaultsKey)
    }
}
