import XCTest
import CoreGraphics
@testable import Rally

final class RallyBallNormalizationStateTests: XCTestCase {
    func testScheduledHandoffRetainsItsPoseAndOriginalContactDeadline() {
        let reentry = makeReentry()
        let scheduled = reentry.startTime + reentry.travelSeconds * 0.70
        let expected = reentry.frame(at: scheduled)
        let normalization = RallyBallNormalizationState(reentry: reentry, at: scheduled + 0.012)

        XCTAssertEqual(normalization.startTime, scheduled, accuracy: 0.000_001)
        XCTAssertEqual(normalization.arrivalTime, reentry.arrivalTime)
        XCTAssertEqual(normalization.strikeTime, reentry.arrivalTime)
        XCTAssertEqual(normalization.strikePoint, reentry.strikePoint)
        XCTAssertEqual(normalization.startPoint, expected.point)
        XCTAssertEqual(normalization.startXScale, expected.xScale)
        XCTAssertEqual(normalization.startYScale, expected.yScale)
        XCTAssertEqual(normalization.startShadowAlpha, expected.shadowAlpha)
        XCTAssertEqual(normalization.config.travelDuration, reentry.arrivalTime - scheduled, accuracy: 0.000_001)
        XCTAssertEqual(normalization.config.settleDuration,
                       min(0.12, (reentry.arrivalTime - scheduled) * 0.6), accuracy: 0.000_001)
        let initial = normalization.frame(at: scheduled)
        XCTAssertEqual(initial.point, expected.point)
        XCTAssertEqual(initial.xScale, expected.xScale)
        XCTAssertEqual(initial.yScale, expected.yScale)
        let contact = normalization.frame(at: reentry.arrivalTime)
        XCTAssertEqual(contact.point.x, reentry.strikePoint.x, accuracy: 0.000_001)
        XCTAssertEqual(contact.point.y, reentry.strikePoint.y, accuracy: 0.000_001)
    }

    func testLateFirstSamplesKeepTheSameTrajectoryAndDoNotRenewTheTimingWindow() {
        let reentry = makeReentry()
        let onTime = RallyBallNormalizationState(
            reentry: reentry, at: reentry.startTime + reentry.travelSeconds * 0.70
        )
        for lateness in [0.10, 0.30, 0.40] {
            let now = reentry.arrivalTime + lateness
            let late = RallyBallNormalizationState(reentry: reentry, at: now)
            XCTAssertEqual(late.normalizedArrivalTime, reentry.arrivalTime)
            XCTAssertEqual(now - late.normalizedArrivalTime, lateness, accuracy: 0.000_001)
            XCTAssertEqual(late.startTime, onTime.startTime)
            XCTAssertEqual(late.startPoint, onTime.startPoint)
            XCTAssertEqual(late.strikePoint, onTime.strikePoint)
            XCTAssertEqual(late.expirationTime, onTime.expirationTime)
            let actualFrame = late.frame(at: now)
            let expectedFrame = onTime.frame(at: now)
            XCTAssertEqual(actualFrame.point, expectedFrame.point)
            XCTAssertEqual(actualFrame.xScale, expectedFrame.xScale)
            XCTAssertEqual(actualFrame.yScale, expectedFrame.yScale)
            XCTAssertEqual(actualFrame.isExpired, lateness >= 0.34)
            XCTAssertTrue(actualFrame.point.x.isFinite && actualFrame.point.y.isFinite)
        }
    }

    func testEarlyHandoffUsesCurrentPoseAndPreservesArmingAndArrival() {
        let reentry = makeReentry()
        let now = reentry.startTime + 0.01
        let expected = reentry.frame(at: now)
        let normalization = RallyBallNormalizationState(reentry: reentry, at: now)
        XCTAssertEqual(normalization.startTime, now)
        XCTAssertEqual(normalization.startPoint, expected.point)
        XCTAssertEqual(normalization.frame(at: now).point, expected.point)
        XCTAssertEqual(normalization.arrivalTime, reentry.arrivalTime)
        XCTAssertFalse(normalization.frame(at: now).armed)
        XCTAssertTrue(normalization.frame(at: reentry.rearmTime + 0.000_001).armed)
    }

    func testLiveBaselineKeepsTheDeadlineAndExplicitLaneDirectionAfterLateHandoff() {
        let reentry = makeReentry()
        let normalization = RallyBallNormalizationState(
            reentry: reentry, at: reentry.arrivalTime + 0.30, laneDirection: 1
        )
        // Lane is authoritative even if a diagonal trajectory approaches from
        // the other side; overrun must follow the caller's lane direction.
        XCTAssertEqual(normalization.laneDirection, 1)
        XCTAssertGreaterThan(normalization.frame(at: reentry.arrivalTime + 0.1).point.x, reentry.strikePoint.x)
        let baseline = normalization.makeLiveTravelBaseline(spawnScale: 0.45, overrunScale: 1.2)
        XCTAssertEqual(baseline.arrivalTime, reentry.arrivalTime)
        XCTAssertEqual(baseline.spawnTime, normalization.startTime)
        XCTAssertEqual(baseline.travelSeconds, normalization.travelSeconds)
        XCTAssertEqual(baseline.strikePoint, reentry.strikePoint)
    }

    private func makeReentry() -> RallyReentryBallState {
        RallyReentryBallState(
            startTime: 10, arrivalTime: 10.54, strikeTime: 10.495,
            startPoint: CGPoint(x: 250, y: 610), strikePoint: CGPoint(x: 80, y: 205),
            config: .rallyDefault,
            handoffXScale: 0.58, handoffYScale: 0.62, handoffShadowAlpha: 0.18
        )
    }
}
