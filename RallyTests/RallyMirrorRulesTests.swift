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

    func testIncreasingShotPowerShortensOutboundFlightInEveryComboTier() {
        for combo in [Int.min, 0, 3, 4, 7, 8, 12, Int.max] {
            let beat = RallyMirrorRules.beatSeconds(forCombo: combo)
            let powers: [Double] = [0, 0.25, 0.5, 0.75, 1]
            let flights = powers.map { RallyMirrorRules.outboundSeconds(forCombo: combo, power: $0) }
            XCTAssertGreaterThan(flights[0], beat, "A soft shot gives the double more time to move")
            XCTAssertEqual(flights[2], beat, accuracy: 0.0001,
                           "Neutral power preserves the established rally pace")
            XCTAssertLessThan(flights[4], beat, "A hard shot must visibly reach the double sooner")
            for index in 1..<flights.count {
                XCTAssertLessThan(flights[index], flights[index - 1])
                XCTAssertGreaterThanOrEqual(flights[index], 0.54)
            }
            XCTAssertLessThanOrEqual(flights[0], 0.912 + 0.0001)
        }
    }

    func testOutboundFlightRemainsBoundedForExtremePowerAndComboValues() {
        for combo in [Int.min, -1, 0, 4, 8, 100, Int.max] {
            let soft = RallyMirrorRules.outboundSeconds(forCombo: combo, power: 0)
            let hard = RallyMirrorRules.outboundSeconds(forCombo: combo, power: 1)
            for power: Double in [-Double.greatestFiniteMagnitude, -100, -0.01] {
                XCTAssertEqual(RallyMirrorRules.outboundSeconds(forCombo: combo, power: power), soft)
            }
            for power: Double in [1.01, 100, Double.greatestFiniteMagnitude] {
                XCTAssertEqual(RallyMirrorRules.outboundSeconds(forCombo: combo, power: power), hard)
            }
            XCTAssertGreaterThanOrEqual(hard, 0.54,
                                        "Even a full-power late-rally shot must leave visible travel time")
            XCTAssertTrue(soft.isFinite)
            XCTAssertTrue(hard.isFinite)
        }
    }

    func testInvalidPowerFallsBackToNeutralOutboundTiming() {
        for combo in [0, 4, 8, Int.max] {
            for invalid: Double in [.nan, .infinity, -.infinity] {
                XCTAssertEqual(RallyMirrorRules.outboundSeconds(forCombo: combo, power: invalid),
                               RallyMirrorRules.beatSeconds(forCombo: combo), accuracy: 0.0001)
            }
        }
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
