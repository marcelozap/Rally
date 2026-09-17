import Foundation

/// An optional goal layered on the existing twenty-second Mirror Rally.
/// A live eight-shot streak can be celebrated immediately; the challenge is
/// recorded only when the player finishes the complete run.
enum RallyChallenge: String, CaseIterable, Identifiable, Codable, Sendable {
    case cleanEight

    var id: String { rawValue }
    var title: String { "Clean Eight" }
    var instruction: String { "Finish 20 seconds with a streak of eight returns." }
    var targetStreak: Int { 8 }
    var durationSeconds: Double { RallyMirrorRules.durationSeconds }

    /// Use the run's best streak, so a later miss does not erase a reached goal.
    func progress(maxCombo: Int) -> Int {
        min(targetStreak, max(0, maxCombo))
    }

    func outcome(for result: GameResult) -> RallyChallengeOutcome {
        // GameScene caps a completed Mirror Rally's elapsed time at exactly 20.
        // Do not turn legacy, interrupted, practice or invalid snapshots into wins.
        guard result.isMirrorRally, result.completedMirrorRally,
              result.elapsedSeconds.isFinite, result.elapsedSeconds == durationSeconds,
              result.maxCombo >= 0, result.misses >= 0,
              result.perfectHits >= 0, result.greatHits >= 0, result.goodHits >= 0 else {
            return .ineligible
        }
        // Avoid GameResult.totalHits here: an invalid imported/synthetic counter
        // must not overflow while we decide whether the result is eligible.
        let (firstTwo, firstOverflow) = result.perfectHits.addingReportingOverflow(result.greatHits)
        guard !firstOverflow else { return .ineligible }
        let (successfulReturns, secondOverflow) = firstTwo.addingReportingOverflow(result.goodHits)
        guard !secondOverflow, result.maxCombo <= successfulReturns,
              successfulReturns == 0 || result.maxCombo > 0 else { return .ineligible }
        return result.maxCombo >= targetStreak ? .goalMet : .goalMissed
    }
}

enum RallyChallengeOutcome: Equatable, Sendable {
    /// The run has not finished, is a different mode, or has invalid counters.
    case ineligible
    /// A valid completed run that did not reach the target streak.
    case goalMissed
    /// The streak was reached at any point in a valid completed run.
    case goalMet
}

/// These counts belong to the challenge; bestStreak never means score.
struct RallyChallengeRecord: Codable, Equatable, Sendable {
    var bestStreak: Int = 0
    var attempts: Int = 0
    var completions: Int = 0
}

/// Isolated local progress: no rewards, SwiftData changes or existing record keys.
/// Call on the main actor with a stable UUID for each run, including repeated
/// delivery of its completion event. A retry must receive a fresh UUID.
@MainActor
final class RallyChallengeStore {
    static let storageKeyPrefix = "rally.challenge.v1."
    private static let maximumRememberedRuns = 64
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(for challenge: RallyChallenge) -> RallyChallengeRecord {
        payload(for: challenge).record
    }

    /// Returns the current record, unchanged for unfinished/invalid runs or an
    /// already-recorded recent run. Both wins and misses count as full attempts.
    @discardableResult
    func record(_ result: GameResult, for challenge: RallyChallenge, runID: UUID) -> RallyChallengeRecord {
        var stored = payload(for: challenge)
        let outcome = challenge.outcome(for: result)
        guard outcome != .ineligible, !stored.recentRunIDs.contains(runID) else {
            return stored.record
        }
        stored.record.bestStreak = max(stored.record.bestStreak, result.maxCombo)
        stored.record.attempts = Self.increment(stored.record.attempts)
        if outcome == .goalMet {
            stored.record.completions = Self.increment(stored.record.completions)
        }
        stored.recentRunIDs.append(runID)
        if stored.recentRunIDs.count > Self.maximumRememberedRuns {
            stored.recentRunIDs.removeFirst(stored.recentRunIDs.count - Self.maximumRememberedRuns)
        }
        guard let encoded = try? JSONEncoder().encode(stored) else {
            return record(for: challenge)
        }
        defaults.set(encoded, forKey: Self.storageKeyPrefix + challenge.rawValue)
        return stored.record
    }

    private struct Payload: Codable {
        var record = RallyChallengeRecord()
        var recentRunIDs: [UUID] = []
    }

    private func payload(for challenge: RallyChallenge) -> Payload {
        guard let data = defaults.data(forKey: Self.storageKeyPrefix + challenge.rawValue),
              let stored = try? JSONDecoder().decode(Payload.self, from: data),
              stored.record.bestStreak >= 0, stored.record.attempts >= 0,
              stored.record.completions >= 0,
              stored.record.completions <= stored.record.attempts,
              stored.recentRunIDs.count <= Self.maximumRememberedRuns else { return Payload() }
        return stored
    }

    private static func increment(_ value: Int) -> Int {
        value == Int.max ? Int.max : value + 1
    }
}
