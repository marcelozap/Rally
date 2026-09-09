import XCTest
import SpriteKit
@testable import Rally

@MainActor
final class RallyVisualIntegrationTests: XCTestCase {
    func testServeClockWaitsForContact() {
        let (scene, view) = makeScene()
        defer { scene.willMove(from: view) }
        scene.update(100.5)
        XCTAssertEqual(scene.servePhase, .toss)
        XCTAssertEqual(scene.buildResult().elapsedSeconds, 0)
        XCTAssertEqual(balls(in: scene).count, 0)
        scene.update(101.25)
        scene.attemptServe(at: 101.25)
        XCTAssertEqual(scene.servePhase, .rally)
        XCTAssertEqual(balls(in: scene).count, 1)
        XCTAssertEqual(scene.buildResult().elapsedSeconds, 0)
        scene.update(101.5)
        XCTAssertEqual(scene.buildResult().elapsedSeconds, 0.25, accuracy: 0.001)
    }

    func testRepeatedContactCannotCreateTwoBalls() {
        let (scene, view) = makeScene()
        defer { scene.willMove(from: view) }
        scene.update(101.25)
        scene.attemptServe(at: 101.25)
        scene.attemptServe(at: 101.25)
        scene.attemptServe(at: 101.4)
        XCTAssertEqual(balls(in: scene).count, 1)
        XCTAssertNil(scene.childNode(withName: "serve.toss"))
    }

    func testEarlyServeHasFriendlyRetryAndNoBall() {
        let (scene, view) = makeScene()
        defer { scene.willMove(from: view) }
        scene.update(100.3)
        scene.attemptServe(at: 100.3)
        XCTAssertEqual(scene.servePhase, .retry)
        XCTAssertTrue(balls(in: scene).isEmpty)
        XCTAssertEqual(scene.buildResult().elapsedSeconds, 0)
        scene.update(101.3)
        XCTAssertEqual(scene.servePhase, .preparing)
    }

    func testLateServeIsCountedOnceInServePractice() {
        let (scene, view) = makeScene(mode: .servePractice)
        defer { scene.willMove(from: view) }
        scene.update(100.5)
        scene.update(101.6)
        scene.update(101.7)
        XCTAssertEqual(scene.practiceAttempts, 1)
        XCTAssertEqual(scene.servePhase, .retry)
        XCTAssertTrue(balls(in: scene).isEmpty)
    }

    func testPauseDoesNotConsumeTossWindow() {
        let (scene, view) = makeScene()
        defer { scene.willMove(from: view) }
        scene.update(100.6)
        scene.pauseSession()
        scene.update(900)
        scene.resumeSession()
        scene.update(901)
        XCTAssertEqual(scene.servePhase, .toss)
        XCTAssertEqual(scene.buildResult().elapsedSeconds, 0)
        scene.update(901.65)
        scene.attemptServe(at: 101.25)
        XCTAssertEqual(scene.servePhase, .rally)
        XCTAssertEqual(balls(in: scene).count, 1)
    }

    func testTargetPracticeIsNotTwentySecondRankedChallenge() {
        let (scene, view) = makeScene(mode: .targetPractice)
        defer { scene.willMove(from: view) }
        scene.update(101.25)
        scene.attemptServe(at: 101.25)
        scene.update(125)
        XCTAssertFalse(scene.sessionIsOver)
        XCTAssertFalse(scene.buildResult().isMirrorRally)
    }

    func testExitingDoesNotPublishCompletedChallenge() {
        let (scene, view) = makeScene()
        scene.willMove(from: view)
        XCTAssertTrue(balls(in: scene).isEmpty)
        XCTAssertNil(scene.childNode(withName: "serve.toss"))
        XCTAssertEqual(scene.servePhase, .stopped)
        XCTAssertFalse(scene.buildResult().completedMirrorRally)
    }

    func testServeStateHandlesIrregularClockAndStop() {
        var cycle = RallyServeCycle()
        cycle.begin(at: 1)
        cycle.advance(at: 2.25)
        XCTAssertTrue(cycle.hit(at: 2.25))
        XCTAssertFalse(cycle.hit(at: 2.3))
        cycle.stop()
        cycle.begin(at: 9)
        XCTAssertEqual(cycle.phase, .stopped)
    }

    func testTargetsRejectInvalidValuesAndRotate() {
        XCTAssertTrue(RallyPracticeTarget.isHit(x: 34, width: 100, attempt: 0))
        XCTAssertFalse(RallyPracticeTarget.isHit(x: 66, width: 100, attempt: 0))
        XCTAssertTrue(RallyPracticeTarget.isHit(x: 66, width: 100, attempt: 1))
        XCTAssertFalse(RallyPracticeTarget.isHit(x: .nan, width: 100, attempt: 0))
        XCTAssertFalse(RallyPracticeTarget.isHit(x: 34, width: 0, attempt: 0))
    }

    func testOutlineIsUnavailableBetweenSamplesAndAcrossGap() {
        let frame = CoachPoseFrame(timestamp: 1, points: torso())
        XCTAssertEqual(CoachOutline.points(at: 1, frames: [frame]).count, 4)
        XCTAssertTrue(CoachOutline.points(at: 1.2, frames: [frame]).isEmpty)
        XCTAssertTrue(CoachOutline.points(at: .nan, frames: [frame]).isEmpty)
        XCTAssertTrue(CoachOutline.points(at: 1.1, frames: [frame, .init(timestamp: 1.1, points: [:])]).isEmpty)
    }

    func testLowConfidenceAndMissingTorsoNeverDrawOutline() {
        var points = torso()
        points[.leftShoulder] = .init(x: 0.4, y: 0.2, confidence: 0.2)
        XCTAssertTrue(CoachOutline.points(at: 0, frames: [.init(timestamp: 0, points: points)]).isEmpty)
        points[.leftShoulder] = nil
        XCTAssertTrue(CoachOutline.points(at: 0, frames: [.init(timestamp: 0, points: points)]).isEmpty)
    }

    func testFourModesHaveDistinctPlayerInstructions() {
        XCTAssertEqual(RallyPlayMode.allCases.count, 4)
        XCTAssertEqual(Set(RallyPlayMode.allCases.map(\.cue)).count, 4)
    }

    func testSharedLessonRigKeepsModelAndRacketForBothHands() {
        for preset in [RallyAthletePreset.maleEuropean, .femaleEuropean] {
            let rig = RallyAvatarRig(appearance: .init(athletePreset: preset))
            XCTAssertNil(rig.assetError)
            for left in [false, true] {
                for p: Float in [0, 0.25, 0.5, 0.75, 1] {
                    rig.animateLesson(progress: p, leftHanded: left)
                    XCTAssertTrue(rig.racketHeadWorldPosition.x.isFinite)
                    rig.animateLesson(progress: p, leftHanded: left, serve: true)
                    XCTAssertTrue(rig.racketHeadWorldPosition.y.isFinite)
                    XCTAssertFalse(rig.root.isHidden)
                }
            }
        }
    }

    private func torso() -> [CoachJoint: CoachKeypoint] {
        [.leftShoulder: .init(x: 0.4, y: 0.2, confidence: 0.9),
         .rightShoulder: .init(x: 0.6, y: 0.2, confidence: 0.9),
         .leftHip: .init(x: 0.4, y: 0.6, confidence: 0.9),
         .rightHip: .init(x: 0.6, y: 0.6, confidence: 0.9)]
    }
    private func makeScene(mode: RallyPlayMode = .rallyChallenge) -> (GameScene, SKView) {
        let size = CGSize(width: 402, height: 874)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = GameScene(size: size)
        scene.practiceMode = mode
        scene.didMove(to: view)
        scene.beginServePoint(at: 100)
        return (scene, view)
    }
    private func balls(in node: SKNode) -> [BallNode] {
        (node as? BallNode).map { [$0] } ?? node.children.flatMap { balls(in: $0) }
    }
}
