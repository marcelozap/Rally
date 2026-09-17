import Foundation
import XCTest
@testable import Rally

@MainActor
final class RallyChallengeTests: XCTestCase {
    func testLiveProgressClampsAtEightWithoutLosingReachedGoal() {
        let challenge = RallyChallenge.cleanEight
        for (streak, expected) in [(Int.min, 0), (-1, 0), (0, 0), (7, 7), (8, 8), (9, 8), (Int.max, 8)] {
            XCTAssertEqual(challenge.progress(maxCombo: streak), expected)
        }
        XCTAssertEqual(challenge.durationSeconds, 20)
    }

    func testEightConsecutiveReturnsQualifyButEightScatteredReturnsDoNot() {
        XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: result(streak: 7, hits: 15)), .goalMissed)
        XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: result(streak: 8, hits: 8)), .goalMet)
        XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: result(streak: 11, hits: 14)), .goalMet)
        // The goal is a run's best streak, so missing after reaching it is allowed.
        var recovered = result(streak: 8, hits: 12)
        recovered.misses = 2
        XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: recovered), .goalMet)
    }

    func testHighScoreCannotSubstituteForAStreak() {
        var scattered = result(streak: 3, hits: 12)
        scattered.finalScore = 100_000
        XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: scattered), .goalMissed)
    }

    func testInterruptedLegacyAndPracticeResultsCannotCompleteGoal() {
        var interrupted = result(streak: 8, hits: 8)
        interrupted.completedMirrorRally = false
        XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: interrupted), .ineligible)
        var practice = result(streak: 8, hits: 8)
        practice.isMirrorRally = false
        XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: practice), .ineligible)
        XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: .empty), .ineligible)
    }

    func testInvalidOrUnfinishedTimeCannotCountEvenWithCompletionFlag() {
        for elapsed: Double in [-1, 0, 19.999, 20.001, 40, .nan, .infinity, -.infinity] {
            var invalid = result(streak: 8, hits: 8)
            invalid.elapsedSeconds = elapsed
            XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: invalid), .ineligible)
        }
    }

    func testImpossibleAndOverflowingHitCountersAreRejected() {
        var invalidResults = [result(streak: 8, hits: 7), result(streak: -1, hits: 8), result(streak: 0, hits: 8)]
        for keyPath in [\GameResult.perfectHits, \.greatHits, \.goodHits, \.misses] {
            var invalid = result(streak: 8, hits: 8)
            invalid[keyPath: keyPath] = -1
            invalidResults.append(invalid)
        }
        var firstOverflow = result(streak: 8, hits: 0)
        firstOverflow.perfectHits = Int.max
        firstOverflow.greatHits = 1
        invalidResults.append(firstOverflow)
        var secondOverflow = result(streak: 8, hits: 1)
        secondOverflow.perfectHits = Int.max
        invalidResults.append(secondOverflow)
        for invalid in invalidResults {
            XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: invalid), .ineligible)
        }
    }

    func testCompletedEmptyRunIsAnAttemptWithAnUnmetGoal() {
        withDefaults { defaults in
            let emptyRun = result(streak: 0, hits: 0)
            XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: emptyRun), .goalMissed)
            let record = RallyChallengeStore(defaults: defaults).record(emptyRun, for: .cleanEight, runID: UUID())
            XCTAssertEqual(record, RallyChallengeRecord(bestStreak: 0, attempts: 1, completions: 0))
        }
    }

    func testCompletedRunsPersistStreakAttemptsAndCompletionsSeparately() {
        withDefaults { defaults in
            let store = RallyChallengeStore(defaults: defaults)
            XCTAssertEqual(store.record(for: .cleanEight), RallyChallengeRecord())
            store.record(result(streak: 6, hits: 10), for: .cleanEight, runID: UUID())
            store.record(result(streak: 10, hits: 14), for: .cleanEight, runID: UUID())
            store.record(result(streak: 8, hits: 9), for: .cleanEight, runID: UUID())
            let reloaded = RallyChallengeStore(defaults: defaults).record(for: .cleanEight)
            XCTAssertEqual(reloaded, RallyChallengeRecord(bestStreak: 10, attempts: 3, completions: 2))
        }
    }

    func testDuplicateDeliveryDoesNotCountAgainEvenAfterAnotherRun() {
        withDefaults { defaults in
            let store = RallyChallengeStore(defaults: defaults)
            let firstRun = UUID()
            let won = result(streak: 8, hits: 8)
            store.record(won, for: .cleanEight, runID: firstRun)
            store.record(result(streak: 5, hits: 7), for: .cleanEight, runID: UUID())
            let repeated = store.record(won, for: .cleanEight, runID: firstRun)
            XCTAssertEqual(repeated, RallyChallengeRecord(bestStreak: 8, attempts: 2, completions: 1))
            XCTAssertEqual(RallyChallengeStore(defaults: defaults).record(won, for: .cleanEight, runID: firstRun), repeated)
        }
    }

    func testUnfinishedRunDoesNotWriteOrConsumeItsRunIdentifier() {
        withDefaults { defaults in
            let store = RallyChallengeStore(defaults: defaults)
            let runID = UUID()
            var live = result(streak: 8, hits: 8)
            live.completedMirrorRally = false
            live.elapsedSeconds = 12
            XCTAssertEqual(store.record(live, for: .cleanEight, runID: runID), RallyChallengeRecord())
            XCTAssertNil(defaults.object(forKey: RallyChallengeStore.storageKeyPrefix + RallyChallenge.cleanEight.rawValue))
            XCTAssertEqual(store.record(result(streak: 8, hits: 8), for: .cleanEight, runID: runID).completions, 1)
        }
    }

    func testChallengeStorageLeavesExistingPlayerRecordsAlone() {
        withDefaults { defaults in
            defaults.set(4200, forKey: "rally.survival.bestScore")
            defaults.set("existing player data", forKey: "unrelated.player")
            RallyChallengeStore(defaults: defaults).record(result(streak: 8, hits: 8), for: .cleanEight, runID: UUID())
            XCTAssertEqual(defaults.integer(forKey: "rally.survival.bestScore"), 4200)
            XCTAssertEqual(defaults.string(forKey: "unrelated.player"), "existing player data")
        }
    }

    func testMalformedChallengeStorageRecoversWithoutBlockingANewRun() {
        withDefaults { defaults in
            let key = RallyChallengeStore.storageKeyPrefix + RallyChallenge.cleanEight.rawValue
            defaults.set(Data("not-json".utf8), forKey: key)
            let store = RallyChallengeStore(defaults: defaults)
            XCTAssertEqual(store.record(for: .cleanEight), RallyChallengeRecord())
            let recorded = store.record(result(streak: 8, hits: 8), for: .cleanEight, runID: UUID())
            XCTAssertEqual(recorded, RallyChallengeRecord(bestStreak: 8, attempts: 1, completions: 1))
        }
    }

    private func withDefaults(_ operation: (UserDefaults) -> Void) {
        let suiteName = "RallyChallengeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create an isolated challenge test store")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        operation(defaults)
    }

    private func result(streak: Int, hits: Int) -> GameResult {
        GameResult(finalScore: 100, maxCombo: streak, perfectHits: 0, greatHits: 0,
                   goodHits: hits, misses: 0, isMirrorRally: true,
                   completedMirrorRally: true, elapsedSeconds: 20)
    }
}
