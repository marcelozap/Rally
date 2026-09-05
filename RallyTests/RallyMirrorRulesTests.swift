import XCTest
@testable import Rally

final class RallyMirrorRulesTests: XCTestCase {
    func testBeatChangesOnlyAtFourAndEightSuccessfulShots() {
        let boundaries: [(Int, Double)] = [
            (Int.min, 0.76), (-1, 0.76), (0, 0.76), (3, 0.76),
            (4, 0.70), (7, 0.70), (8, 0.64), (12, 0.64), (Int.max, 0.64),
        ]
        for (combo, expected) in boundaries {
            XCTAssertEqual(RallyMirrorRules.beatSeconds(forCombo: combo), expected, accuracy: 0.00001)
        }
    }

    func testEachFourShotPhraseKeepsAConsistentHalfExchangePulse() {
        for phraseStart in stride(from: 0, through: 20, by: 4) {
            let beat = RallyMirrorRules.beatSeconds(forCombo: phraseStart)
            for combo in phraseStart..<(phraseStart + 4) {
                XCTAssertEqual(RallyMirrorRules.beatSeconds(forCombo: combo), beat)
            }
            XCTAssertGreaterThanOrEqual(beat, 0.64)
            XCTAssertLessThanOrEqual(beat, 0.76)
        }
    }

    func testRunFinishesAtExactlyTwentySeconds() {
        XCTAssertEqual(RallyMirrorRules.durationSeconds, 20)
        XCTAssertFalse(RallyMirrorRules.hasFinished(at: 0))
        XCTAssertFalse(RallyMirrorRules.hasFinished(at: 19.999))
        XCTAssertTrue(RallyMirrorRules.hasFinished(at: 20))
        XCTAssertTrue(RallyMirrorRules.hasFinished(at: 25))
    }

    func testRemainingTimeClampsBeforeStartAndAfterFinish() {
        XCTAssertEqual(RallyMirrorRules.remainingSeconds(at: -3), 20)
        XCTAssertEqual(RallyMirrorRules.remainingSeconds(at: 0), 20)
        XCTAssertEqual(RallyMirrorRules.remainingSeconds(at: 19.25), 0.75)
        XCTAssertEqual(RallyMirrorRules.remainingSeconds(at: 20), 0)
        XCTAssertEqual(RallyMirrorRules.remainingSeconds(at: 25), 0)
    }

    func testIncomingContactMustArriveBeforeTheFinishBoundary() {
        XCTAssertTrue(RallyMirrorRules.canStartIncoming(at: 0, travelSeconds: 1.2))
        XCTAssertTrue(RallyMirrorRules.canStartIncoming(at: 18.5, travelSeconds: 1.4))
        XCTAssertFalse(RallyMirrorRules.canStartIncoming(at: 18.5, travelSeconds: 1.5))
        XCTAssertFalse(RallyMirrorRules.canStartIncoming(at: 19.5, travelSeconds: 1))
        XCTAssertFalse(RallyMirrorRules.canStartIncoming(at: 20, travelSeconds: 0))
        XCTAssertFalse(RallyMirrorRules.canStartIncoming(at: 21, travelSeconds: 0))
    }

    func testInvalidTimingCannotCreateAFeed() {
        XCTAssertFalse(RallyMirrorRules.canStartIncoming(at: -1, travelSeconds: 1))
        XCTAssertFalse(RallyMirrorRules.canStartIncoming(at: 1, travelSeconds: -1))
        XCTAssertFalse(RallyMirrorRules.canStartIncoming(at: .nan, travelSeconds: 1))
        XCTAssertFalse(RallyMirrorRules.canStartIncoming(at: 1, travelSeconds: .infinity))
        XCTAssertEqual(RallyMirrorRules.remainingSeconds(at: .nan), 0)
        XCTAssertTrue(RallyMirrorRules.hasFinished(at: .infinity))
    }

    func testContactExpiresStrictlyAfterItsArrivalGraceWindow() {
        let arrival = 2.5
        let expiry = arrival + 0.34
        XCTAssertFalse(RallyMirrorRules.hasMissedContact(at: arrival - 0.2, arrivalTime: arrival))
        XCTAssertFalse(RallyMirrorRules.hasMissedContact(at: arrival, arrivalTime: arrival))
        XCTAssertFalse(RallyMirrorRules.hasMissedContact(at: expiry, arrivalTime: arrival))
        XCTAssertTrue(RallyMirrorRules.hasMissedContact(at: expiry + 0.0001, arrivalTime: arrival))
    }

    func testNonfiniteTimingCannotDeclareAMissedContact() {
        for invalid: Double in [.nan, .infinity, -.infinity] {
            XCTAssertFalse(RallyMirrorRules.hasMissedContact(at: invalid, arrivalTime: 2.5))
            XCTAssertFalse(RallyMirrorRules.hasMissedContact(at: 3, arrivalTime: invalid))
        }
    }

    func testLegacyResultsKeepDefaultMetadataAndExistingAccuracy() {
        let result = GameResult(finalScore: 100, maxCombo: 4, perfectHits: 2, greatHits: 1, goodHits: 1, misses: 1)
        XCTAssertFalse(result.isMirrorRally)
        XCTAssertFalse(result.completedMirrorRally)
        XCTAssertEqual(result.elapsedSeconds, 0)
        XCTAssertEqual(result.accuracy, 0.8)
    }
}
