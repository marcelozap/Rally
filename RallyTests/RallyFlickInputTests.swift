import CoreGraphics
import XCTest
@testable import Rally

final class RallyFlickInputTests: XCTestCase {
    private func flick(
        start: CGPoint = CGPoint(x: 90, y: 100),
        end: CGPoint = CGPoint(x: 90, y: 180),
        velocity: CGVector = CGVector(dx: 0, dy: 500),
        duration: TimeInterval = 0.2,
        width: CGFloat = 390,
        incomingLane: Lane? = nil
    ) -> RallyFlickInput.Result? {
        RallyFlickInput.evaluate(
            start: start,
            end: end,
            velocity: velocity,
            duration: duration,
            viewportWidth: width,
            incomingLane: incomingLane
        )
    }

    func testUpwardAndDiagonalFlicksProduceDifferentStrokes() throws {
        let up = try XCTUnwrap(flick())
        XCTAssertEqual(up.lane, .left)
        XCTAssertEqual(up.stroke, .topspin)
        XCTAssertEqual(up.direction, 0)

        let diagonal = try XCTUnwrap(flick(end: CGPoint(x: 160, y: 145)))
        XCTAssertEqual(diagonal.stroke, .drive)
        XCTAssertGreaterThan(diagonal.direction, 0)
        XCTAssertGreaterThan(up.lift, diagonal.lift)
    }

    func testPanRecognitionRetainsEarlyTravelAndTheOriginalLane() throws {
        // Recognition arrives after most of this real left-side diagonal has
        // crossed the midpoint. Only 11 points remain before the finger lifts.
        let recognizedInView = CGPoint(x: 230, y: 620)
        let translation = CGPoint(x: 140, y: -80)
        let releaseInView = CGPoint(x: 240, y: 615)
        let startInView = RallyFlickInput.panStart(location: recognizedInView, translation: translation)
        let toScene: (CGPoint) -> CGPoint = { CGPoint(x: $0.x, y: 800 - $0.y) }
        XCTAssertNil(flick(start: toScene(recognizedInView), end: toScene(releaseInView)))
        for duration in [0.08, 0.001] {
            let result = try XCTUnwrap(flick(
                start: toScene(startInView), end: toScene(releaseInView),
                velocity: .zero, duration: duration
            ))
            XCTAssertEqual(result.lane, .left)
            XCTAssertEqual(result.stroke, .drive)
            XCTAssertGreaterThan(result.direction, 0)
            XCTAssertGreaterThan(result.lift, 0.5)
        }
    }

    func testTapsAndTinyFastSwipesCannotCommit() {
        XCTAssertNil(flick(end: CGPoint(x: 90, y: 100)))
        XCTAssertNil(flick(end: CGPoint(x: 90, y: 119), velocity: CGVector(dx: 0, dy: 9_000)))
        XCTAssertNil(flick(end: CGPoint(x: 90, y: 127.99), velocity: CGVector(dx: 0, dy: 9_000)))
        XCTAssertNil(flick(end: CGPoint(x: 190, y: 119.99)))
        XCTAssertNotNil(flick(end: CGPoint(x: 90, y: 128), velocity: .zero, duration: 0.2))
        XCTAssertNotNil(flick(end: CGPoint(x: 111, y: 120)))
    }

    func testDownwardAndSidewaysMotionsNeverCommit() {
        for end in [CGPoint(x: 90, y: 20), CGPoint(x: 190, y: 100), CGPoint(x: 190, y: 80)] {
            XCTAssertNil(flick(end: end, velocity: CGVector(dx: 8_000, dy: 8_000)))
        }
    }

    func testNearHorizontalFlickNeedsMeaningfulUpwardDirection() {
        XCTAssertNil(flick(end: CGPoint(x: 390, y: 120), velocity: CGVector(dx: 8_000, dy: 8_000)))
        XCTAssertNil(flick(end: CGPoint(x: -210, y: 120), velocity: CGVector(dx: -8_000, dy: 8_000)))
        let belowConeHorizontal = CGFloat(8_844).squareRoot()
        let insideConeHorizontal = CGFloat(8_704).squareRoot()
        for direction: CGFloat in [-1, 1] {
            let belowCone = CGPoint(x: 90 + direction * belowConeHorizontal, y: 134)
            let insideCone = CGPoint(x: 90 + direction * insideConeHorizontal, y: 136)
            XCTAssertNil(flick(end: belowCone))
            XCTAssertNotNil(flick(end: insideCone))
        }
    }

    func testCommitmentIsMonotonicWithUpwardReleaseSpeed() throws {
        let end = CGPoint(x: 90, y: 132)
        XCTAssertNil(flick(end: end, velocity: .zero, duration: 1))
        XCTAssertNil(flick(end: end, velocity: CGVector(dx: 0, dy: 139.99), duration: 1))
        let threshold = try XCTUnwrap(flick(end: end, velocity: CGVector(dx: 0, dy: 140), duration: 1))
        let fast = try XCTUnwrap(flick(end: end, velocity: CGVector(dx: 0, dy: 700), duration: 1))
        XCTAssertEqual(threshold.speed, 140, accuracy: 0.0001)
        XCTAssertGreaterThan(fast.speed, threshold.speed)
        XCTAssertEqual(fast.stroke, threshold.stroke)
        XCTAssertEqual(fast.lane, threshold.lane)
    }

    func testAverageMotionRecognizesFlickThatSlowsAtRelease() throws {
        XCTAssertNil(flick(velocity: .zero, duration: 1))
        let deliberate = try XCTUnwrap(flick(velocity: .zero, duration: 0.4))
        let faster = try XCTUnwrap(flick(velocity: .zero, duration: 0.2))
        XCTAssertEqual(deliberate.speed, 200, accuracy: 0.0001)
        XCTAssertGreaterThan(faster.speed, deliberate.speed)
    }

    func testOnlyPositiveYReleaseVelocitySuppliesCommitment() {
        let end = CGPoint(x: 90, y: 132)
        XCTAssertNotNil(flick(end: end, velocity: CGVector(dx: 0, dy: 900), duration: 1))
        XCTAssertNil(flick(end: end, velocity: CGVector(dx: 0, dy: -900), duration: 1))
        XCTAssertNil(flick(end: end, velocity: CGVector(dx: 9_000, dy: 0), duration: 1))
    }

    func testMirroredGesturesHaveMirroredLanesAndMatchingStrength() throws {
        let left = try XCTUnwrap(flick(
            start: CGPoint(x: 70, y: 100),
            end: CGPoint(x: 120, y: 180),
            velocity: CGVector(dx: 300, dy: 500)
        ))
        let right = try XCTUnwrap(flick(
            start: CGPoint(x: 320, y: 100),
            end: CGPoint(x: 270, y: 180),
            velocity: CGVector(dx: -300, dy: 500)
        ))
        XCTAssertEqual(left.lane, .left)
        XCTAssertEqual(right.lane, .right)
        XCTAssertEqual(left.stroke, right.stroke)
        XCTAssertEqual(left.speed, right.speed, accuracy: 0.0001)
        XCTAssertEqual(left.lift, right.lift, accuracy: 0.0001)
        XCTAssertEqual(left.direction, -right.direction, accuracy: 0.0001)
    }

    func testCenterGesturesUseTheirOwnDirectionAndStableVerticalFallback() throws {
        let start = CGPoint(x: 195, y: 100)
        XCTAssertEqual(try XCTUnwrap(flick(start: start, end: CGPoint(x: 150, y: 180))).lane, .left)
        XCTAssertEqual(try XCTUnwrap(flick(start: start, end: CGPoint(x: 240, y: 180))).lane, .right)
        XCTAssertEqual(try XCTUnwrap(flick(start: start, end: CGPoint(x: 195, y: 180))).lane, .right)
        XCTAssertEqual(try XCTUnwrap(flick(start: CGPoint(x: 210, y: 100), end: CGPoint(x: 195, y: 180))).lane, .left)
        XCTAssertEqual(try XCTUnwrap(flick(start: CGPoint(x: 180, y: 100), end: CGPoint(x: 195, y: 180))).lane, .right)
    }

    func testStartingSideStillOwnsFlickThatCrossesTheCourt() throws {
        let result = try XCTUnwrap(flick(end: CGPoint(x: 310, y: 210)))
        XCTAssertEqual(result.lane, .left)
        XCTAssertEqual(result.stroke, .drive)
    }

    func testIncomingLaneAcceptsFlickFromOppositeTouchSide() throws {
        let rightIncoming = try XCTUnwrap(flick(incomingLane: .right))
        XCTAssertEqual(rightIncoming.lane, .right)
        XCTAssertEqual(rightIncoming.direction, 0)

        let leftIncoming = try XCTUnwrap(flick(
            start: CGPoint(x: 300, y: 100), end: CGPoint(x: 300, y: 180), incomingLane: .left
        ))
        XCTAssertEqual(leftIncoming.lane, .left)
        XCTAssertEqual(leftIncoming.direction, 0)
        XCTAssertEqual(try XCTUnwrap(flick()).lane, .left, "Omitting the incoming lane retains legacy selection")
    }

    func testIncomingLanePreservesMeasuredHorizontalAimAndStrength() throws {
        for horizontal: CGFloat in [-70, 70] {
            let end = CGPoint(x: 90 + horizontal, y: 180)
            let original = try XCTUnwrap(flick(end: end))
            let mirror = try XCTUnwrap(flick(end: end, incomingLane: .right))
            XCTAssertEqual(mirror.lane, .right)
            XCTAssertEqual(mirror.direction, original.direction, accuracy: 0.0001)
            XCTAssertEqual(mirror.lift, original.lift, accuracy: 0.0001)
            XCTAssertEqual(mirror.speed, original.speed, accuracy: 0.0001)
            XCTAssertEqual(mirror.stroke, original.stroke)
            let target = RallyFlickInput.wallTargetX(lane: mirror.lane, direction: mirror.direction, viewportWidth: 390)
            let neutral = RallyFlickInput.wallTargetX(lane: .right, direction: 0, viewportWidth: 390)
            if horizontal < 0 { XCTAssertLessThan(target, neutral) }
            else { XCTAssertGreaterThan(target, neutral) }
        }
    }

    func testIncomingLaneDoesNotBypassGestureValidation() {
        for lane in [Lane.left, .right] {
            XCTAssertNil(flick(end: CGPoint(x: 90, y: 119), incomingLane: lane))
            XCTAssertNil(flick(end: CGPoint(x: 90, y: 20), incomingLane: lane))
            XCTAssertNil(flick(end: CGPoint(x: 190, y: 100), incomingLane: lane))
            XCTAssertNil(flick(duration: 0, incomingLane: lane))
            XCTAssertNil(flick(width: .nan, incomingLane: lane))
        }
    }

    func testRelativeScreenSizingPreservesAcceptanceAndStrength() throws {
        let baseline = try XCTUnwrap(flick(end: CGPoint(x: 145, y: 180)))
        for scale: CGFloat in [0.8, 1.1, 2] {
            let result = try XCTUnwrap(flick(
                start: CGPoint(x: 90 * scale, y: 100 * scale),
                end: CGPoint(x: 145 * scale, y: 180 * scale),
                velocity: CGVector(dx: 0, dy: 500 * scale),
                width: 390 * scale
            ))
            XCTAssertEqual(result.lane, baseline.lane)
            XCTAssertEqual(result.stroke, baseline.stroke)
            XCTAssertEqual(result.speed, baseline.speed, accuracy: 0.0001)
            XCTAssertEqual(result.lift, baseline.lift, accuracy: 0.0001)
            XCTAssertEqual(result.direction, baseline.direction, accuracy: 0.0001)
            XCTAssertNil(flick(
                start: CGPoint(x: 90 * scale, y: 100 * scale),
                end: CGPoint(x: 90 * scale, y: 119 * scale),
                velocity: CGVector(dx: 0, dy: 9_000 * scale),
                width: 390 * scale
            ))
        }
    }

    func testLiftAndDirectionStayWithinTheirContracts() throws {
        for end in [CGPoint(x: -40, y: 180), CGPoint(x: 600, y: 900), CGPoint(x: 90, y: 1_000)] {
            let result = try XCTUnwrap(flick(end: end))
            XCTAssertGreaterThanOrEqual(result.lift, 0)
            XCTAssertLessThanOrEqual(result.lift, 1)
            XCTAssertGreaterThanOrEqual(result.direction, -1)
            XCTAssertLessThanOrEqual(result.direction, 1)
        }
        XCTAssertEqual(try XCTUnwrap(flick(end: CGPoint(x: 90, y: 1_000))).lift, 1)
    }

    func testBothLanesRespondToInwardOutwardAndVerticalAim() throws {
        for width: CGFloat in [320, 390, 820] {
            let scale = width / 390
            for lane in [Lane.left, .right] {
                let startX: CGFloat = lane == .left ? 90 : 300
                let neutral = RallyFlickInput.wallTargetX(lane: lane, direction: 0, viewportWidth: width)
                var endpoints: [CGFloat] = []
                for horizontal: CGFloat in [-70, 0, 70] {
                    let gesture = try XCTUnwrap(flick(
                        start: CGPoint(x: startX * scale, y: 100 * scale),
                        end: CGPoint(x: (startX + horizontal) * scale, y: 180 * scale),
                        velocity: CGVector(dx: 0, dy: 500 * scale), width: width
                    ))
                    XCTAssertEqual(gesture.lane, lane)
                    let endpoint = RallyFlickInput.wallTargetX(
                        lane: gesture.lane, direction: gesture.direction, viewportWidth: width
                    )
                    XCTAssertGreaterThanOrEqual(endpoint, width * 0.20)
                    XCTAssertLessThanOrEqual(endpoint, width * 0.80)
                    endpoints.append(endpoint)
                }
                // In particular, an outward flick must not collapse onto the
                // vertical target through boundary clamping.
                XCTAssertLessThan(endpoints[0], neutral - width * 0.04)
                XCTAssertEqual(endpoints[1], neutral, accuracy: 0.0001)
                XCTAssertGreaterThan(endpoints[2], neutral + width * 0.04)
            }
            let left = RallyFlickInput.wallTargetX(lane: .left, direction: -0.7, viewportWidth: width)
            let right = RallyFlickInput.wallTargetX(lane: .right, direction: 0.7, viewportWidth: width)
            XCTAssertEqual(left + right, width, accuracy: 0.0001)
        }
    }

    func testInvalidGeometryVelocityDurationAndViewportAreRejected() {
        for value: CGFloat in [.nan, .infinity, -.infinity] {
            XCTAssertNil(flick(start: CGPoint(x: value, y: 100)))
            XCTAssertNil(flick(start: CGPoint(x: 90, y: value)))
            XCTAssertNil(flick(end: CGPoint(x: value, y: 180)))
            XCTAssertNil(flick(end: CGPoint(x: 90, y: value)))
            XCTAssertNil(flick(velocity: CGVector(dx: value, dy: 500)))
            XCTAssertNil(flick(velocity: CGVector(dx: 0, dy: value)))
            XCTAssertNil(flick(width: value))
        }
        for duration: TimeInterval in [0, -1, .nan, .infinity, -.infinity] {
            XCTAssertNil(flick(duration: duration))
        }
        XCTAssertNil(flick(width: 0))
        XCTAssertNil(flick(width: -390))
    }

    func testTimingFeedbackHasInclusiveSymmetricPerfectBoundaries() {
        let window = 0.033
        XCTAssertEqual(RallyFlickInput.timingFeedback(signedDelta: -0.0331, perfectWindow: window), .early)
        XCTAssertEqual(RallyFlickInput.timingFeedback(signedDelta: -window, perfectWindow: window), .perfect)
        XCTAssertEqual(RallyFlickInput.timingFeedback(signedDelta: 0, perfectWindow: window), .perfect)
        XCTAssertEqual(RallyFlickInput.timingFeedback(signedDelta: window, perfectWindow: window), .perfect)
        XCTAssertEqual(RallyFlickInput.timingFeedback(signedDelta: 0.0331, perfectWindow: window), .late)
        XCTAssertEqual(RallyFlickInput.timingFeedback(signedDelta: 0, perfectWindow: 0), .perfect)
    }

    func testInvalidTimingValuesCannotEarnPerfectFeedback() {
        for delta: Double in [.nan, .infinity, -.infinity] {
            XCTAssertNotEqual(RallyFlickInput.timingFeedback(signedDelta: delta, perfectWindow: 0.033), .perfect)
        }
        for window: Double in [-1, .nan, .infinity, -.infinity] {
            XCTAssertNotEqual(RallyFlickInput.timingFeedback(signedDelta: 0, perfectWindow: window), .perfect)
        }
    }

    func testWallScoreMultiplierStepsEveryFiveHitsAndCapsAtFour() {
        let cases: [(combo: Int, multiplier: Int)] = [
            (-100, 1), (0, 1), (4, 1), (5, 2), (9, 2),
            (10, 3), (14, 3), (15, 4), (16, 4), (1_000, 4), (Int.max, 4)
        ]
        for value in cases {
            XCTAssertEqual(
                Tunables.wallScoreMultiplier(forCombo: value.combo),
                value.multiplier,
                "Unexpected score multiplier at combo \(value.combo)"
            )
        }
    }
}
