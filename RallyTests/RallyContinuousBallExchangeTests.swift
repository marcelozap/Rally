import XCTest
import SpriteKit
@testable import Rally

@MainActor
final class RallyContinuousBallExchangeTests: XCTestCase {
    private let originTime: TimeInterval = 1_000
    private let farPoint = CGPoint(x: 276, y: 710)

    func testFarContactDeadlineMatchesFirstTouchForOriginalAndStretchedFlights() {
        for duration in [0.22, 0.95, 1.45] {
            var config = RallyExchangeConfig.rallyDefault
            config.wall.totalDuration = duration
            let exchange = makeExchange(config: config)
            XCTAssertEqual(exchange.startTime, originTime)
            XCTAssertEqual(exchange.farContactPoint, farPoint)
            XCTAssertEqual(exchange.farContactTime,
                           originTime + config.racket.totalDuration + config.wall.approachDuration,
                           accuracy: 0.000_001)
            XCTAssertFalse(exchange.frame(at: exchange.farContactTime - 0.001).didBeginWallImpact)

            let touch = exchange.frame(at: exchange.farContactTime)
            XCTAssertTrue(touch.didBeginWallImpact)
            XCTAssertEqual(touch.point.x, farPoint.x, accuracy: 0.001)
            XCTAssertEqual(touch.point.y, farPoint.y, accuracy: 0.001)
            XCTAssertFalse(touch.isComplete)
            XCTAssertFalse(exchange.frame(at: exchange.farContactTime).didBeginWallImpact,
                           "Reading the same timestamp twice must not replay the contact")
        }
    }

    func testNormalDisplayTimelinesEmitExactlyOneFarContact() {
        for framesPerSecond in [30.0, 60.0, 120.0] {
            let exchange = makeExchange()
            let frameCount = Int(ceil(exchange.totalDuration * framesPerSecond)) + 2
            var contactTimes: [TimeInterval] = []
            var completed = false
            for frame in 0...frameCount {
                let time = originTime + Double(frame) / framesPerSecond
                let sample = exchange.frame(at: time)
                if sample.didBeginWallImpact { contactTimes.append(time) }
                if time < originTime + exchange.totalDuration {
                    XCTAssertFalse(sample.isComplete)
                }
                completed = completed || sample.isComplete
            }
            XCTAssertEqual(contactTimes.count, 1)
            if let time = contactTimes.first {
                XCTAssertGreaterThanOrEqual(time, exchange.farContactTime)
                XCTAssertLessThanOrEqual(time - exchange.farContactTime, 1 / framesPerSecond + 0.000_001)
            }
            XCTAssertTrue(completed)
        }
    }

    func testFrameSkippingCompressionAndTwentyEightMillisecondDwellStillEmitsContact() {
        var config = RallyExchangeConfig.rallyDefault
        config.wall.dwellDuration = 0.028
        let exchange = makeExchange(config: config)
        let before = exchange.frame(at: exchange.farContactTime - 0.002)
        XCTAssertEqual(before.phase, .wallApproach)
        XCTAssertFalse(before.didBeginWallImpact)

        let afterDwell = exchange.farContactTime + config.wall.compressionDuration
            + config.wall.dwellDuration + 0.002
        let after = exchange.frame(at: afterDwell)
        XCTAssertEqual(after.phase, .wallDecompression)
        XCTAssertTrue(after.didBeginWallImpact)
        XCTAssertFalse(after.isComplete)
        XCTAssertFalse(exchange.frame(at: afterDwell + 0.01).didBeginWallImpact)
    }

    func testSkippedFarLegReportsPendingContactAndStableTerminalHandoffTogether() {
        let exchange = makeExchange()
        let owner = SKNode()
        owner.addChild(exchange.ball)
        exchange.ball.ownershipPhase = .racketExchange
        let originalBallPosition = exchange.ball.position
        XCTAssertFalse(exchange.frame(at: originTime).didBeginWallImpact)

        // The consumer can process contact and then hand this same ball into
        // reentry, even when no intermediate far-end frame was rendered.
        let lateTime = originTime + exchange.totalDuration + 0.10
        let handoff = exchange.frame(at: lateTime)
        XCTAssertEqual(handoff.phase, .complete)
        XCTAssertTrue(handoff.didBeginWallImpact)
        XCTAssertTrue(handoff.isComplete)
        for time in [lateTime, lateTime + 0.25, lateTime + 1] {
            let terminal = exchange.frame(at: time)
            XCTAssertTrue(terminal.isComplete)
            XCTAssertFalse(terminal.didBeginWallImpact)
            XCTAssertEqual(terminal.point, handoff.point)
            XCTAssertEqual(terminal.xScale, handoff.xScale)
            XCTAssertEqual(terminal.yScale, handoff.yScale)
        }
        // frame(at:) leaves ownership/position to GameScene's single consumer.
        XCTAssertTrue(exchange.ball.parent === owner)
        XCTAssertEqual(exchange.ball.ownershipPhase, .racketExchange)
        XCTAssertEqual(exchange.ball.position, originalBallPosition)
    }

    private func makeExchange(config: RallyExchangeConfig = .rallyDefault) -> RallyContinuousBallExchange {
        let start = CGPoint(x: 310, y: 236)
        let contact = CGPoint(x: 320, y: 230)
        let ball = BallNode(
            lane: .right, kind: .normal, role: .returnBall, wallStyleMode: true, shotShape: .drive,
            arrivalTime: 4, spawnTime: 3, travelSeconds: 1,
            spawnPoint: start, strikePoint: contact,
            spawnScale: 0.4, strikeScale: 1, overrunScale: 1.2, curveAmount: 0
        )
        return RallyContinuousBallExchange(
            ball: ball, startPoint: start, contactPoint: contact, wallContactPoint: farPoint,
            direction: 1, inboundSpeed: 480, offsetFromCenter: 0,
            startTime: originTime, config: config
        )
    }
}
