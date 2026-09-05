import XCTest
@testable import Rally

final class RallyCourtMovementTests: XCTestCase {
    func testWideBallRequiresTravelOnEitherSideForBothHands() {
        for width: CGFloat in [320, 390, 430] {
            for lane in [Lane.left, .right] {
                for reachRatio: CGFloat in [0.125, 0.165] {
                    let reach = (lane == .left ? -1 : 1) * width * reachRatio
                    let contact = RallyCourtMovement.returnContactX(lane: lane, reach: reach, width: width)
                    let stance = RallyCourtMovement.stanceX(contactX: contact, reach: reach, width: width)
                    XCTAssertEqual(stance, width * (lane == .left ? 0.32 : 0.68), accuracy: 0.001)
                    XCTAssertGreaterThan(abs(stance - width / 2), width * 0.15)
                    XCTAssertEqual(stance + reach, contact, accuracy: 0.001)
                }
            }
        }
    }

    func testTravelAtThirtyAndSixtyFPSReachesSameSideThenRecovers() {
        for fps in [30, 60] {
            var x: CGFloat = 195
            let dt = 1.0 / Double(fps)
            for _ in 0..<fps {
                let next = RallyCourtMovement.advance(from: x, toward: 265, deltaTime: dt,
                                                      pointsPerMeter: 100, planted: false)
                XCTAssertGreaterThanOrEqual(next, x)
                XCTAssertLessThanOrEqual(next - x, 135 * CGFloat(dt) + 0.001)
                x = next
            }
            XCTAssertEqual(x, 265, accuracy: 0.5)
            for _ in 0..<fps {
                x = RallyCourtMovement.advance(from: x, toward: 195, deltaTime: dt,
                                               pointsPerMeter: 100, planted: false)
            }
            XCTAssertEqual(x, 195, accuracy: 0.5)
        }
    }

    func testContactAndPauseCannotSlideOrTeleportTheRoot() {
        XCTAssertEqual(RallyCourtMovement.advance(from: 220, toward: 270, deltaTime: 0.03,
                                                  pointsPerMeter: 100, planted: true), 220)
        XCTAssertEqual(RallyCourtMovement.advance(from: 220, toward: 270, deltaTime: -1,
                                                  pointsPerMeter: 100, planted: false), 220)
        let resumed = RallyCourtMovement.advance(from: 220, toward: 270, deltaTime: 30,
                                                 pointsPerMeter: 100, planted: false)
        XCTAssertLessThanOrEqual(resumed - 220, 9.001)
    }

    func testPlannedArrivalReachesContactAtThirtyAndSixtyFPS() {
        let duration: TimeInterval = 0.7
        let pointsPerMeter: CGFloat = 71.4
        for fps in [30, 60] {
            let dt = 1.0 / Double(fps)
            for direction: CGFloat in [-1, 1] {
                var position: CGFloat = 195
                let target = position + 40 * direction
                for frame in 0..<Int((duration * Double(fps)).rounded()) {
                    let next = RallyCourtMovement.arrive(from: position, toward: target, deltaTime: dt,
                                                         secondsRemaining: duration - Double(frame) * dt,
                                                         pointsPerMeter: pointsPerMeter)
                    XCTAssertGreaterThanOrEqual((next - position) * direction, 0)
                    XCTAssertLessThanOrEqual(abs(next - position), pointsPerMeter * 1.35 * CGFloat(dt) + 0.0001)
                    position = next
                }
                XCTAssertEqual(position, target, accuracy: 1,
                               "A feasible 40-point approach must arrive by contact at \(fps)Hz")
            }
        }
    }

    func testUnreachableOrExpiredArrivalStaysSpeedBounded() {
        let dt: TimeInterval = 1.0 / 60.0
        let maximumStep: CGFloat = 71.4 * 1.35 * CGFloat(dt)
        for remaining: TimeInterval in [0.01, 0, -1] {
            for target: CGFloat in [-10_000, 10_000] {
                let next = RallyCourtMovement.arrive(from: 195, toward: target, deltaTime: dt,
                                                     secondsRemaining: remaining, pointsPerMeter: 71.4)
                XCTAssertEqual(abs(next - 195), maximumStep, accuracy: 0.0001)
                XCTAssertGreaterThan((next - 195) * (target - 195), 0)
                XCTAssertNotEqual(next, target)
            }
        }
        XCTAssertEqual(RallyCourtMovement.arrive(from: 195, toward: 195.2, deltaTime: dt,
                                                 secondsRemaining: 0, pointsPerMeter: 71.4), 195.2,
                       accuracy: 0.0001, "The final small step can land exactly without overshooting")
    }

    func testPausedOrInvalidArrivalCannotTeleport() {
        for dt: TimeInterval in [0, -1, .infinity, .nan] {
            XCTAssertEqual(RallyCourtMovement.arrive(from: 220, toward: 270, deltaTime: dt,
                                                     secondsRemaining: -1, pointsPerMeter: 71.4), 220)
        }
        let resumed = RallyCourtMovement.arrive(from: 220, toward: 270, deltaTime: 30,
                                                secondsRemaining: -30, pointsPerMeter: 71.4)
        XCTAssertEqual(resumed - 220, 71.4 * 1.35 / 15, accuracy: 0.0001)
        for remaining: TimeInterval in [.infinity, -.infinity, .nan] {
            XCTAssertEqual(RallyCourtMovement.arrive(from: 220, toward: 270, deltaTime: 0.03,
                                                     secondsRemaining: remaining, pointsPerMeter: 71.4), 220)
        }
        for scale: CGFloat in [0, -1, .infinity, .nan] {
            XCTAssertEqual(RallyCourtMovement.arrive(from: 220, toward: 270, deltaTime: 0.03,
                                                     secondsRemaining: 0.7, pointsPerMeter: scale), 220)
        }
        XCTAssertEqual(RallyCourtMovement.arrive(from: 220, toward: .nan, deltaTime: 0.03,
                                                 secondsRemaining: 0.7, pointsPerMeter: 71.4), 220)
    }
}
