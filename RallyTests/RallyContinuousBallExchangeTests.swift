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

    func testWallBallStaysCourtSizedThroughContactReturnAndNormalization() throws {
        for width in [CGFloat(375), 430] {
            for role in [BeatmapNote.Role.serve, .returnBall] {
                let scene = SKScene(size: CGSize(width: width, height: 874))
                let start = CGPoint(x: 310, y: 236)
                let contact = CGPoint(x: 320, y: 230)
                // Match both real constructors: serves begin with unit scale;
                // ordinary incoming feeds already carry their court size.
                let ball = makeVisualBall(width: width, role: role, wallStyle: true)
                scene.addChild(ball)
                ball.updatePresentation(progress: 1)
                let incomingWidth = solidWidth(of: ball)
                let exchange = RallyContinuousBallExchange(
                    ball: ball, startPoint: start, contactPoint: contact, wallContactPoint: farPoint,
                    direction: 1, inboundSpeed: 480, offsetFromCenter: 0,
                    startTime: originTime
                )
                let first = exchange.frame(at: originTime)
                ball.applyLiveExchangeFrame(first)
                let contactWidth = solidWidth(of: ball)
                XCTAssertEqual(contactWidth / incomingWidth, 1, accuracy: 0.08,
                               "Contact must not double the incoming ball's size")
                XCTAssertGreaterThan(solidWidth(of: ball), width * 0.045)
                XCTAssertLessThan(solidWidth(of: ball), width * 0.065)

                for sample in 0...60 {
                    let frame = exchange.frame(at: originTime + exchange.totalDuration * Double(sample) / 60)
                    ball.applyLiveExchangeFrame(frame)
                    // SpriteKit stores transforms as Float32. At this court
                    // size, rounding is <0.000031pt, far below one pixel.
                    XCTAssertEqual(ball.position.x, frame.point.x, accuracy: 0.000_1,
                                   "Display scale must not alter the trajectory")
                    XCTAssertEqual(ball.position.y, frame.point.y, accuracy: 0.000_1,
                                   "Display scale must not alter the trajectory")
                    XCTAssertEqual(ball.xScale / ball.yScale, frame.xScale / frame.yScale, accuracy: 0.000_001,
                                   "Retain the authored squash and stretch")
                    XCTAssertLessThan(solidWidth(of: ball), width * 0.085,
                                      "Contact deformation must stay within a readable ball diameter")
                }

                let terminal = exchange.frame(at: originTime + exchange.totalDuration)
                let exchangeSize = CGSize(width: ball.xScale, height: ball.yScale)
                let reentry = RallyReentryBallState(
                    startTime: 10, arrivalTime: 10.54, strikeTime: 10.495,
                    startPoint: terminal.point, strikePoint: contact, config: .rallyDefault,
                    handoffXScale: terminal.xScale, handoffYScale: terminal.yScale,
                    handoffShadowAlpha: terminal.shadowAlpha
                )
                ball.beginReentry(reentry)
                ball.applyReentryFrame(reentry.frame(at: reentry.startTime), trackTime: reentry.startTime)
                XCTAssertEqual(ball.xScale, exchangeSize.width, accuracy: 0.000_001)
                XCTAssertEqual(ball.yScale, exchangeSize.height, accuracy: 0.000_001)
                XCTAssertFalse(ball.isHittable(at: reentry.startTime))
                XCTAssertTrue(ball.isHittable(at: reentry.rearmTime + 0.001))

                let handoffTime = reentry.startTime + reentry.travelSeconds * 0.70
                ball.applyReentryFrame(reentry.frame(at: handoffTime), trackTime: handoffTime)
                let reentrySize = CGSize(width: ball.xScale, height: ball.yScale)
                let normalization = RallyBallNormalizationState(reentry: reentry, at: handoffTime)
                ball.beginNormalization(normalization)
                ball.updateNormalization(trackTime: handoffTime)
                XCTAssertEqual(ball.xScale, reentrySize.width, accuracy: 0.000_001)
                XCTAssertEqual(ball.yScale, reentrySize.height, accuracy: 0.000_001)
                ball.updateNormalization(trackTime: reentry.arrivalTime)
                XCTAssertEqual(ball.position, normalization.frame(at: reentry.arrivalTime).point)
                XCTAssertEqual(ball.effectiveArrivalTime, reentry.arrivalTime)
                XCTAssertEqual(solidWidth(of: ball), contactWidth, accuracy: 0.000_001,
                               "The next incoming ball returns to its original contact size")
                XCTAssertGreaterThan(solidWidth(of: ball), width * 0.045)
                XCTAssertLessThan(solidWidth(of: ball), width * 0.065)

                ball.updateNormalization(trackTime: normalization.expirationTime + 0.001)
                XCTAssertNil(ball.normalizationState)
                XCTAssertEqual(try XCTUnwrap(ball.liveTravelBaselineOverride).strikeScale, 1,
                               "The model keeps its normalized scale contract")
                ball.updatePresentation(progress: 1.18)
                XCTAssertEqual(ball.effectiveArrivalTime, reentry.arrivalTime)
                XCTAssertLessThan(solidWidth(of: ball), width * 0.075,
                                  "An expired normalization must not restore the old oversized geometry")
                XCTAssertLessThanOrEqual(ball.glowWidth, 0.75)
                XCTAssertGreaterThan(ball.strokeColor.cgColor.alpha, 0.25)
                XCTAssertLessThan(ball.strokeColor.cgColor.alpha, 0.65)
            }
        }
    }

    func testNonWallBallKeepsItsExistingMotionPresentation() {
        let ball = makeVisualBall(width: 375, role: .returnBall, wallStyle: false)
        let exchange = makeExchange()
        for sample in 0...20 {
            let frame = exchange.frame(at: originTime + exchange.totalDuration * Double(sample) / 20)
            ball.applyLiveExchangeFrame(frame)
            // Only allow Float32 transform-storage rounding, not a visual
            // rescale (observed maximum scale error is <0.000000047).
            XCTAssertEqual(ball.xScale, frame.xScale, accuracy: 0.000_000_1)
            XCTAssertEqual(ball.yScale, frame.yScale, accuracy: 0.000_000_1)
            XCTAssertEqual(ball.position.x, frame.point.x, accuracy: 0.000_1)
            XCTAssertEqual(ball.position.y, frame.point.y, accuracy: 0.000_1)
        }
        XCTAssertEqual(ball.glowWidth, 10)
        XCTAssertEqual(ball.strokeColor.cgColor.alpha, 1)
    }

    private func solidWidth(of ball: BallNode) -> CGFloat {
        (ball.path?.boundingBox.width ?? 0) * ball.xScale
    }

    private func makeVisualBall(width: CGFloat, role: BeatmapNote.Role, wallStyle: Bool) -> BallNode {
        BallNode(
            lane: .right, kind: .normal, role: role, wallStyleMode: wallStyle, shotShape: .drive,
            arrivalTime: 4, spawnTime: 3, travelSeconds: 1,
            spawnPoint: CGPoint(x: 310, y: 236), strikePoint: CGPoint(x: 320, y: 230),
            spawnScale: role == .serve ? 1 : 0.4,
            strikeScale: role == .serve ? 1 : width * Tunables.ballStrikeDiameterSceneWidthRatio / 44,
            overrunScale: role == .serve ? 1 : 1.2, curveAmount: 0
        )
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
