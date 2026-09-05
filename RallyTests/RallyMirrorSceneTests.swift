import SpriteKit
import XCTest
@testable import Rally

/// Advances the real scene clock without rendering or relying on GUI gestures.
@MainActor
final class RallyMirrorSceneTests: XCTestCase {
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

    private func makeScene(autoPlay: Bool) -> (GameScene, SKView) {
        let size = CGSize(width: 402, height: 874)
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
