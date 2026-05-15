import XCTest
@testable import Rally

/// Locks in the phase-resolution rules and the segmented headline strings.
/// These are pure-Swift, so they run without spinning up a SpriteKit scene.
final class MatchFlowTests: XCTestCase {

    // MARK: - MatchFlowCoordinator

    func testWarmUpAtZeroComboEarlySession() {
        let c = MatchFlowCoordinator(sessionDurationSeconds: 180)
        c.update(trackTime: 5, combo: 0)
        XCTAssertEqual(c.currentPhase, .warmUp)
    }

    func testExchangeAfterWarmUpClockMark() {
        let c = MatchFlowCoordinator(sessionDurationSeconds: 180)
        // 0.20 of session is past the 0.15 warm-up mark — clock alone is enough.
        c.update(trackTime: 36, combo: 0)
        XCTAssertEqual(c.currentPhase, .exchange)
    }

    func testComboCanEscalateAheadOfClock() {
        let c = MatchFlowCoordinator(sessionDurationSeconds: 180)
        // Still in the warm-up clock window, but combo is already in tier 2.
        c.update(trackTime: 5, combo: Tunables.comboTier2)
        XCTAssertEqual(c.currentPhase, .pressure)
    }

    func testClockNeverDowngradesPhaseEvenAtZeroCombo() {
        let c = MatchFlowCoordinator(sessionDurationSeconds: 180)
        // Deep into breaker territory by clock; combo of 0 must not pull us
        // back down to warm-up.
        c.update(trackTime: 170, combo: 0)
        XCTAssertEqual(c.currentPhase, .breaker)
    }

    func testComboBreakDropsIntoRecoveryThenResumes() {
        let c = MatchFlowCoordinator(sessionDurationSeconds: 180)
        c.update(trackTime: 90, combo: 20)
        XCTAssertEqual(c.currentPhase, .pressure)

        c.registerComboBreak(at: 90)
        c.update(trackTime: 91, combo: 0)
        XCTAssertEqual(c.currentPhase, .recovery)

        // After the recovery window, we should land back on the clock-driven phase.
        c.update(trackTime: 90 + Tunables.MatchFlow.recoverySeconds + 0.1, combo: 0)
        XCTAssertNotEqual(c.currentPhase, .recovery)
    }

    func testPhaseChangeCallbackFires() {
        let c = MatchFlowCoordinator(sessionDurationSeconds: 180)
        var transitions: [(MatchFlowPhase, MatchFlowPhase)] = []
        c.onPhaseChange = { from, to in transitions.append((from, to)) }
        c.update(trackTime: 5, combo: 0)
        c.update(trackTime: 36, combo: 0)
        XCTAssertFalse(transitions.isEmpty)
        XCTAssertEqual(transitions.last?.1, .exchange)
    }

    func testProfileBpmRisesWithPhase() {
        let c = MatchFlowCoordinator(sessionDurationSeconds: 180)
        let warm = c.profile(for: .warmUp).bpm
        let exch = c.profile(for: .exchange).bpm
        let pres = c.profile(for: .pressure).bpm
        let brk  = c.profile(for: .breaker).bpm
        XCTAssertLessThan(warm, exch)
        XCTAssertLessThan(exch, pres)
        XCTAssertLessThan(pres, brk)
    }

    // MARK: - GameResult narrative

    func testClutchFinalStretchHeadline() {
        let r = GameResult(
            finalScore: 0, maxCombo: 0,
            perfectHits: 0, greatHits: 0, goodHits: 0, misses: 0,
            segments: [
                SegmentStats(perfectHits: 1, greatHits: 1, goodHits: 1, misses: 7),
                SegmentStats(perfectHits: 2, greatHits: 2, goodHits: 1, misses: 5),
                SegmentStats(perfectHits: 8, greatHits: 1, goodHits: 1, misses: 0)
            ]
        )
        XCTAssertEqual(r.narrativeHeadline, "Clutch final stretch")
    }

    func testWireToWireHeadline() {
        let solid = SegmentStats(perfectHits: 6, greatHits: 2, goodHits: 1, misses: 1)
        let r = GameResult(
            finalScore: 0, maxCombo: 0,
            perfectHits: 0, greatHits: 0, goodHits: 0, misses: 0,
            segments: [solid, solid, solid]
        )
        XCTAssertEqual(r.narrativeHeadline, "Wire-to-wire")
    }

    func testFallbackHeadlineWithoutSegments() {
        let r = GameResult.empty
        XCTAssertEqual(r.narrativeHeadline, "Run complete")
    }

    func testSubheadCallsOutPeakSegment() {
        let r = GameResult(
            finalScore: 0, maxCombo: 0,
            perfectHits: 0, greatHits: 0, goodHits: 0, misses: 0,
            segments: [
                SegmentStats(perfectHits: 1, greatHits: 0, goodHits: 0, misses: 0),
                SegmentStats(perfectHits: 12, greatHits: 0, goodHits: 0, misses: 0),
                SegmentStats(perfectHits: 1, greatHits: 0, goodHits: 0, misses: 0)
            ]
        )
        XCTAssertEqual(r.narrativeSubhead, "Most Perfects landed mid-match")
    }
}
