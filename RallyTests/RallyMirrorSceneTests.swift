import SpriteKit
import XCTest
@testable import Rally

/// Advances the real scene clock without rendering or relying on GUI gestures.
@MainActor
final class RallyMirrorSceneTests: XCTestCase {
    func testIncomingBallLoadsEitherStrokeWithoutStartingAHit() {
        for hand in GamePreferences.DominantHand.allCases {
            for lane in [Lane.left, .right] {
                let (scene, view) = makeScene(autoPlay: false)
                defer { removeSceneContents(scene, retaining: view) }
                scene.dominantHand = hand
                scene.spawnBall(BeatmapNote(arrivalTime: 1.1, lane: lane, kind: .normal, role: .rally))

                for frame in 0...30 { scene.update(100 + Double(frame) / 60) }
                XCTAssertEqual(scene.playerPreparationProgress, 0, "An early ball should leave the player ready")
                var previous: Float = 0
                for frame in 31...66 {
                    scene.update(100 + Double(frame) / 60)
                    XCTAssertGreaterThanOrEqual(scene.playerPreparationProgress, previous)
                    XCTAssertLessThanOrEqual(scene.playerPreparationProgress, 0.48,
                                             "Anticipation must never manufacture contact at phase 0.5")
                    previous = scene.playerPreparationProgress
                }
                XCTAssertGreaterThan(scene.playerPreparationProgress, 0.46,
                                     "The final approach should avoid snapping from load straight to contact")
                XCTAssertEqual(scene.playerPreparationLane, lane)
                XCTAssertEqual(scene.buildResult().totalHits, 0)
                XCTAssertEqual(scene.buildResult().misses, 0)
                XCTAssertFalse(scene.sessionIsOver)
            }
        }
    }

    func testLoadedStrokePausesWithTheRallyClock() {
        let (scene, view) = makeScene(autoPlay: false)
        defer { removeSceneContents(scene, retaining: view) }
        spawnOpeningBall(in: scene)
        for frame in 0...51 { scene.update(100 + Double(frame) / 60) }
        let loaded = scene.playerPreparationProgress
        XCTAssertGreaterThan(loaded, 0)
        scene.pauseSession()
        scene.update(200)
        XCTAssertEqual(scene.playerPreparationProgress, loaded)
        scene.resumeSession()
        scene.update(200.1)
        XCTAssertEqual(scene.playerPreparationProgress, loaded, accuracy: 0.0001,
                       "Resuming rebases time instead of skipping directly to contact")
        scene.update(200.15)
        XCTAssertGreaterThan(scene.playerPreparationProgress, loaded)
        XCTAssertEqual(scene.buildResult().totalHits, 0)
    }

    func testMissedLoadedStrokeSettlesBeforeTheNextServe() {
        let (scene, view) = makeScene(autoPlay: false)
        defer { removeSceneContents(scene, retaining: view) }
        spawnOpeningBall(in: scene)
        for frame in 0...66 { scene.update(100 + Double(frame) / 60) }
        let loaded = scene.playerPreparationProgress
        scene.update(101.45)
        XCTAssertEqual(scene.buildResult().misses, 1)
        XCTAssertEqual(scene.playerPreparationProgress, loaded, accuracy: 0.0001,
                       "A missed ball starts recovery from the visible loaded pose")
        scene.update(101.50)
        XCTAssertGreaterThan(scene.playerPreparationProgress, 0)
        XCTAssertLessThan(scene.playerPreparationProgress, loaded)
        XCTAssertEqual(scene.playerPreparationLane, .right)
        for frame in 1...15 { scene.update(101.50 + Double(frame) / 60) }
        XCTAssertEqual(scene.playerPreparationProgress, 0)
        XCTAssertNil(scene.playerPreparationLane)
        scene.beginServePoint(at: 101.8)
        scene.update(102.0)
        XCTAssertEqual(scene.playerPreparationProgress, 0, "A toss owns the pose without incoming preparation")
        XCTAssertEqual(scene.buildResult().totalHits, 0)
    }

    func testFarFeedStartsAtContactAndRealNearContactClearsPreparation() throws {
        let (scene, view) = makeScene(autoPlay: true)
        defer { removeSceneContents(scene, retaining: view) }
        spawnOpeningBall(in: scene)
        XCTAssertEqual(try XCTUnwrap(scene.opponentStrokeProgress), 0.5, accuracy: 0.0001)
        scene.update(100.09)
        XCTAssertEqual(try XCTUnwrap(scene.opponentStrokeProgress), 0.75, accuracy: 0.0001)
        scene.update(100.19)
        XCTAssertNil(scene.opponentStrokeProgress)

        var sawPreparation = false
        for frame in 12...90 {
            scene.update(100 + Double(frame) / 60)
            sawPreparation = sawPreparation || scene.playerPreparationProgress > 0
            if scene.buildResult().totalHits > 0 { break }
        }
        XCTAssertTrue(sawPreparation)
        XCTAssertEqual(scene.buildResult().totalHits, 1)
        XCTAssertEqual(scene.playerPreparationProgress, 0,
                       "The actual contact pose and hit-stop take priority over preparation")
        XCTAssertNil(scene.playerPreparationLane)
    }

    func testCleanEightUsesRealRallyAndCanReachItsGoal() {
        for hand in GamePreferences.DominantHand.allCases {
            let (scene, view) = makeScene(autoPlay: true)
            defer { removeSceneContents(scene, retaining: view) }
            scene.dominantHand = hand
            scene.practiceMode = .cleanEight
            spawnOpeningBall(in: scene)
            for frame in 0...1212 { scene.update(100 + Double(frame) / 60) }
            XCTAssertTrue(scene.sessionIsOver)
            XCTAssertEqual(RallyChallenge.cleanEight.outcome(for: scene.buildResult()), .goalMet)
            XCTAssertTrue(ballNodes(in: scene).isEmpty)
        }
    }

    func testTwentySecondAutoplayCompletesOnceAndClearsEveryBall() throws {
        let (scene, view) = makeScene(autoPlay: true)
        let recorder = ResultRecorder()
        GameEventBus.shared.subscribe(recorder) { [weak recorder] event in
            if case let .sessionEnd(result) = event { recorder?.results.append(result) }
        }
        defer { removeSceneContents(scene, retaining: view) }
        spawnOpeningBall(in: scene)

        for frame in 0...1212 {
            scene.update(100 + Double(frame) / 60)
        }

        let finished = scene.buildResult()
        XCTAssertTrue(scene.sessionIsOver)
        XCTAssertTrue(finished.isMirrorRally)
        XCTAssertTrue(finished.completedMirrorRally)
        XCTAssertEqual(finished.elapsedSeconds, 20, accuracy: 0.0001)
        XCTAssertGreaterThan(finished.finalScore, 0)
        XCTAssertGreaterThan(finished.totalHits, 0)
        XCTAssertEqual(recorder.results.count, 1)
        XCTAssertEqual(recorder.results.first, finished)
        XCTAssertTrue(ballNodes(in: scene).isEmpty, "Ending a run must remove incoming and outgoing balls")

        for frame in 1213...1320 {
            scene.update(100 + Double(frame) / 60)
        }
        scene.spawnBall(BeatmapNote(arrivalTime: 23, lane: .left, kind: .normal, role: .rally))
        XCTAssertEqual(scene.buildResult(), finished, "Completed results must remain immutable on subsequent updates")
        XCTAssertEqual(recorder.results.count, 1, "The session-end event must be published once")
        XCTAssertTrue(ballNodes(in: scene).isEmpty)
    }

    func testOpeningBallSurvivesUntilScheduledContactGraceExpires() throws {
        let (scene, view) = makeScene(autoPlay: false)
        defer { removeSceneContents(scene, retaining: view) }
        spawnOpeningBall(in: scene)
        let openingBall = try XCTUnwrap(ballNodes(in: scene).first)

        for frame in 0...30 { scene.update(100 + Double(frame) / 60) }
        XCTAssertTrue(openingBall.parent === scene)
        XCTAssertEqual(scene.buildResult().misses, 0)

        for frame in 31...57 { scene.update(100 + Double(frame) / 60) }
        XCTAssertTrue(openingBall.parent === scene, "Crossing a global strike-line height must not cull the ball early")
        XCTAssertEqual(scene.buildResult().misses, 0)

        for frame in 58...66 { scene.update(100 + Double(frame) / 60) }
        XCTAssertTrue(openingBall.parent === scene, "The ball must be present at its 1.1-second racket contact")
        XCTAssertEqual(scene.buildResult().misses, 0)

        scene.update(101.439)
        XCTAssertTrue(openingBall.parent === scene)
        XCTAssertEqual(scene.buildResult().misses, 0)

        scene.update(101.45)
        XCTAssertNil(openingBall.parent)
        XCTAssertEqual(scene.buildResult().misses, 1)
        XCTAssertEqual(scene.buildResult().finalScore, 0)
    }

    func testRetryUsesFreshSceneWithZeroScoreAndFullDuration() {
        let (finishedScene, finishedView) = makeScene(autoPlay: true)
        defer { removeSceneContents(finishedScene, retaining: finishedView) }
        spawnOpeningBall(in: finishedScene)
        for frame in 0...1212 { finishedScene.update(100 + Double(frame) / 60) }
        XCTAssertTrue(finishedScene.sessionIsOver)
        XCTAssertGreaterThan(finishedScene.buildResult().finalScore, 0)

        let (retryScene, retryView) = makeScene(autoPlay: false)
        defer { removeSceneContents(retryScene, retaining: retryView) }
        let fresh = retryScene.buildResult()
        XCTAssertFalse(retryScene.sessionIsOver)
        XCTAssertTrue(fresh.isMirrorRally)
        XCTAssertFalse(fresh.completedMirrorRally)
        XCTAssertEqual(fresh.elapsedSeconds, 0)
        XCTAssertEqual(fresh.finalScore, 0)
        XCTAssertEqual(fresh.maxCombo, 0)
        XCTAssertEqual(fresh.totalHits, 0)
        XCTAssertEqual(fresh.misses, 0)
        XCTAssertEqual(RallyMirrorRules.remainingSeconds(at: fresh.elapsedSeconds), 20)
        XCTAssertTrue(ballNodes(in: retryScene).isEmpty)
    }

    func testHumanSwipeCanAimEitherSideFromEitherIncomingLaneAndHand() throws {
        for hand in GamePreferences.DominantHand.allCases {
            for lane in [Lane.left, .right] {
                for direction: CGFloat in [-90, 90] {
                    let (scene, view) = makeScene(autoPlay: false)
                    defer { removeSceneContents(scene, retaining: view) }
                    scene.dominantHand = hand
                    XCTAssertNotNil(view.texture(from: scene))
                    scene.spawnBall(BeatmapNote(arrivalTime: 1.1, lane: lane, kind: .normal, role: .rally))
                    for frame in 0...66 { scene.update(100 + Double(frame) / 60) }
                    let ball = try XCTUnwrap(ballNodes(in: scene).first)
                    let flick = try makeFlick(lane: lane, horizontal: direction, speed: 700, width: scene.size.width)
                    scene.previewRallyFlick(flick)
                    let cue = try XCTUnwrap(scene.childNode(withName: "shot.aim"))
                    let previewX = cue.position.x
                    scene.submitRallyFlick(flick)
                    let shot = try XCTUnwrap(scene.activeExchanges.first)
                    XCTAssertTrue(shot.ball === ball, "A hit retains the same ball")
                    XCTAssertEqual(shot.farContactPoint.x, previewX, accuracy: 0.001)
                    XCTAssertGreaterThan((shot.farContactPoint.x - scene.size.width / 2) * direction, 0,
                                         "The actual projected shot must follow either diagonal from either stroke side")
                    XCTAssertEqual(scene.buildResult().totalHits, 1)
                    XCTAssertEqual(scene.buildResult().misses, 0)
                }
            }
        }
    }

    func testHumanSwipeSpeedChangesRealFlightButKeepsReturnBeatAndRacketContact() throws {
        for fps in [30, 60] {
            for hand in GamePreferences.DominantHand.allCases {
                var durations: [Double] = []
                for speed: CGFloat in [200, 1200] {
                    let (scene, view) = makeScene(autoPlay: false)
                    defer { removeSceneContents(scene, retaining: view) }
                    scene.dominantHand = hand
                    XCTAssertNotNil(view.texture(from: scene), "Initialize the real SK3DNode projection before checking racket contact")
                    spawnOpeningBall(in: scene)
                    for frame in 0...Int(1.1 * Double(fps)) { scene.update(100 + Double(frame) / Double(fps)) }
                    let flick = try makeFlick(lane: .right, horizontal: -90, speed: speed, width: scene.size.width)
                    scene.submitRallyFlick(flick)
                    let shot = try XCTUnwrap(scene.activeExchanges.first)
                    durations.append(shot.farContactTime - shot.startTime)
                    var time = shot.startTime
                    while time + 1 / Double(fps) < shot.farContactTime {
                        time += 1 / Double(fps)
                        scene.update(time)
                    }
                    scene.update(shot.farContactTime)
                    let racket = scene.opponentRacketPoint()
                    XCTAssertEqual(racket.x, shot.farContactPoint.x, accuracy: 5,
                                   "The moving far player must meet a wide shot at its scheduled contact")
                    XCTAssertEqual(racket.y, shot.farContactPoint.y, accuracy: 5)
                    time = shot.farContactTime
                    let handoff = shot.startTime + shot.totalDuration + 0.001
                    while time + 1 / Double(fps) < handoff {
                        time += 1 / Double(fps)
                        scene.update(time)
                    }
                    scene.update(handoff)
                    XCTAssertTrue(scene.activeExchanges.isEmpty)
                    XCTAssertEqual(ballNodes(in: scene).count, 1)
                    XCTAssertTrue(shot.ball.parent === scene)
                    XCTAssertEqual(shot.ball.lane, .left)
                    XCTAssertEqual(shot.ball.effectiveArrivalTime + 100 - shot.farContactTime,
                                   RallyMirrorRules.beatSeconds(forCombo: 1), accuracy: 0.001)
                    XCTAssertEqual(scene.buildResult().totalHits, 1, "Far impact and handoff must not score twice")
                    XCTAssertEqual(scene.buildResult().misses, 0)
                }
                XCTAssertGreaterThan(durations[0] - durations[1], 0.2,
                                     "A faster human swipe must produce a materially quicker actual shot")
            }
        }
    }

    func testAimCueAndPendingGestureClearOnCancelPauseAndFinish() throws {
        let (scene, view) = makeScene(autoPlay: false)
        defer { removeSceneContents(scene, retaining: view) }
        spawnOpeningBall(in: scene)
        scene.update(100.8)
        let flick = try makeFlick(lane: .right, horizontal: -90, speed: 700, width: scene.size.width)
        scene.previewRallyFlick(flick)
        XCTAssertNotNil(scene.childNode(withName: "shot.aim"))
        scene.previewRallyFlick(nil)
        XCTAssertNil(scene.childNode(withName: "shot.aim"))
        scene.previewRallyFlick(flick)
        scene.pauseSession()
        XCTAssertNil(scene.childNode(withName: "shot.aim"))
        scene.submitRallyFlick(flick)
        XCTAssertTrue(scene.activeExchanges.isEmpty)
        scene.resumeSession()
        scene.update(110)
        scene.previewRallyFlick(flick)
        XCTAssertNotNil(scene.childNode(withName: "shot.aim"))
        scene.update(130)
        XCTAssertTrue(scene.sessionIsOver)
        XCTAssertNil(scene.childNode(withName: "shot.aim"))
        scene.submitRallyFlick(flick)
        XCTAssertTrue(scene.activeExchanges.isEmpty)
    }

    func testWideTabletRallyReachesAlternatingFastShotsThroughTopTempoTier() throws {
        for hand in GamePreferences.DominantHand.allCases {
            let (scene, view) = makeScene(autoPlay: false, size: CGSize(width: 820, height: 1180))
            defer { removeSceneContents(scene, retaining: view) }
            scene.dominantHand = hand
            XCTAssertNotNil(view.texture(from: scene))
            spawnOpeningBall(in: scene)
            var now = 100.0
            func advance(to deadline: Double) {
                while now + 1.0 / 30 < deadline {
                    now += 1.0 / 30
                    scene.update(now)
                }
                now = deadline
                scene.update(now)
            }
            for index in 0..<10 {
                let incoming = try XCTUnwrap(ballNodes(in: scene).first { $0.ownershipPhase.isHittable })
                advance(to: 100 + incoming.effectiveArrivalTime)
                let flick = try makeFlick(lane: incoming.lane, horizontal: index.isMultiple(of: 2) ? -160 : 160,
                                         speed: 1200, width: scene.size.width)
                scene.submitRallyFlick(flick)
                let shot = try XCTUnwrap(scene.activeExchanges.first)
                advance(to: shot.farContactTime)
                let racket = scene.opponentRacketPoint()
                XCTAssertEqual(racket.x, shot.farContactPoint.x, accuracy: 5,
                               "Tablet shot \(index + 1) must be reachable at its actual contact time")
                XCTAssertEqual(racket.y, shot.farContactPoint.y, accuracy: 5)
                advance(to: shot.startTime + shot.totalDuration + 0.001)
                XCTAssertEqual(ballNodes(in: scene).count, 1)
                XCTAssertEqual(scene.buildResult().totalHits, index + 1)
                XCTAssertEqual(scene.buildResult().misses, 0)
            }
        }
    }

    private func makeFlick(lane: Lane, horizontal: CGFloat, speed: CGFloat,
                           width: CGFloat) throws -> RallyFlickInput.Result {
        let scale = width / 390
        return try XCTUnwrap(RallyFlickInput.evaluate(
            start: CGPoint(x: 195 * scale, y: 100 * scale),
            end: CGPoint(x: (195 + horizontal) * scale, y: 180 * scale),
            velocity: CGVector(dx: 0, dy: speed * scale), duration: 1,
            viewportWidth: width, incomingLane: lane
        ))
    }

    private func makeScene(autoPlay: Bool, size: CGSize = CGSize(width: 402, height: 874)) -> (GameScene, SKView) {
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = GameScene(size: size)
        scene.sessionDurationSeconds = RallyMirrorRules.durationSeconds
        scene.autoPlayEnabled = autoPlay
        scene.didMove(to: view)
        scene.beginActiveRally(at: 100)
        return (scene, view)
    }

    private func spawnOpeningBall(in scene: GameScene) {
        scene.spawnBall(BeatmapNote(arrivalTime: 1.1, lane: .right, kind: .normal, role: .rally))
    }

    private func ballNodes(in node: SKNode) -> [BallNode] {
        var balls: [BallNode] = []
        if let ball = node as? BallNode { balls.append(ball) }
        for child in node.children { balls.append(contentsOf: ballNodes(in: child)) }
        return balls
    }

    private func removeSceneContents(_ scene: GameScene, retaining view: SKView) {
        scene.removeAllActions()
        scene.removeAllChildren()
        // Keep the input host alive throughout every explicit scene update.
        withExtendedLifetime(view) {}
    }

    private final class ResultRecorder {
        var results: [GameResult] = []
    }
}
