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
        // Clock alone is enough once the tunable warm-up floor has elapsed.
        c.update(trackTime: 180 * (Tunables.MatchFlow.warmUpProgress + 0.01), combo: 0)
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

        // No previousCombo → scale 1.0 → base window only.
        c.registerComboBreak(at: 90)
        c.update(trackTime: 91, combo: 0)
        XCTAssertEqual(c.currentPhase, .recovery)

        // After the base recovery window, clock-driven phase resumes.
        c.update(trackTime: 90 + Tunables.MatchFlow.recoverySeconds + 0.1, combo: 0)
        XCTAssertNotEqual(c.currentPhase, .recovery)
    }

    func testComboBreakWindowScalesWithPreviousCombo() {
        let base = Tunables.MatchFlow.recoverySeconds

        // Combo 30 → scale 2.0 → window = 2 × base.
        let c1 = MatchFlowCoordinator(sessionDurationSeconds: 180)
        c1.registerComboBreak(at: 0, previousCombo: 30)
        // Still inside the 2× window — must still be recovery.
        c1.update(trackTime: base * 1.5, combo: 0)
        XCTAssertEqual(c1.currentPhase, .recovery)
        // Past the 2× window — recovery should be over.
        c1.update(trackTime: base * 2.0 + 0.1, combo: 0)
        XCTAssertNotEqual(c1.currentPhase, .recovery)

        // Combo 0 → scale 1.0 → window = 1 × base.
        let c2 = MatchFlowCoordinator(sessionDurationSeconds: 180)
        c2.registerComboBreak(at: 0, previousCombo: 0)
        // Past the 1× window — recovery should be over.
        c2.update(trackTime: base + 0.1, combo: 0)
        XCTAssertNotEqual(c2.currentPhase, .recovery)
    }

    func testPhaseChangeCallbackFires() {
        let c = MatchFlowCoordinator(sessionDurationSeconds: 180)
        var transitions: [(MatchFlowPhase, MatchFlowPhase)] = []
        c.onPhaseChange = { from, to in transitions.append((from, to)) }
        c.update(trackTime: 5, combo: 0)
        c.update(trackTime: 180 * (Tunables.MatchFlow.warmUpProgress + 0.01), combo: 0)
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

    func testDailyChallengeAccuracyTreatsZeroHitsAsZeroPercent() {
        XCTAssertEqual(
            DailyChallengeMgr.accuracyPercent(perfectHits: 0, greatHits: 0, totalHits: 0),
            0
        )
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
