import SpriteKit
import UIKit

/// Core SpriteKit scene. The only thing in the entire app that publishes
/// `GameEvent`s. Feedback (haptics, audio, particles) is decoupled via
/// `GameEventBus`.
final class GameScene: SKScene {

    // MARK: Tunables

    /// How long a ball takes to travel from spawn line to strike line.
    private var travelSeconds: Double = 1.4

    private let strikeLineYRatio: CGFloat = 0.25
    private let spawnLineYRatio:  CGFloat = 1.05

    // MARK: Runtime state

    private var combo: Int = 0
    private var maxCombo: Int = 0
    private var score: Int = 0
    private var lastComboTier: Int = 0

    private var activeBalls: [BallNode] = []
    private var startTime: TimeInterval = 0
    private var frameStopUntil: TimeInterval = 0

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero

        setupStrikeLine()
        setupSwipeRecognizers(in: view)

        startTime = CACurrentMediaTime()
        GameEventBus.shared.publish(.sessionStart)
    }

    private func setupStrikeLine() {
        let y = size.height * strikeLineYRatio
        let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 1.5))
        line.position = CGPoint(x: size.width / 2, y: y)
        line.strokeColor = .clear
        line.fillColor = UIColor(red: 0, green: 1, blue: 1, alpha: 0.35)
        line.glowWidth = 6
        addChild(line)
    }

    private func setupSwipeRecognizers(in view: SKView) {
        let left = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        left.direction = .left
        let right = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        right.direction = .right
        view.addGestureRecognizer(left)
        view.addGestureRecognizer(right)
    }

    // MARK: Update loop

    override func update(_ currentTime: TimeInterval) {
        if currentTime < frameStopUntil {
            speed = 0
            return
        }
        speed = 1

        let trackTime = currentTime - startTime
        moveBalls(deltaTrackTime: trackTime)
        cullMissedBalls(trackTime: trackTime)

        // TODO: drive RhythmSpawner here once a beatmap is wired up.
    }

    private func moveBalls(deltaTrackTime: Double) {
        let strikeY = size.height * strikeLineYRatio
        let spawnY  = size.height * spawnLineYRatio
        let distance = spawnY - strikeY

        for ball in activeBalls {
            // Linear travel for now; ease-in can come later.
            let progress = max(0, min(1, (deltaTrackTime - ball.spawnTime) / travelSeconds))
            ball.position.y = spawnY - distance * CGFloat(progress)
        }
    }

    private func cullMissedBalls(trackTime: Double) {
        let strikeY = size.height * strikeLineYRatio
        var stillAlive: [BallNode] = []
        for ball in activeBalls {
            if ball.position.y < strikeY - 40 {
                ball.removeFromParent()
                registerMiss(lane: ball.lane)
            } else {
                stillAlive.append(ball)
            }
        }
        activeBalls = stillAlive
    }

    // MARK: Spawning (called by RhythmSpawner)

    /// Spawn a ball that should _arrive_ at the strike line at `arrivalTime`
    /// (track-relative seconds).
    func spawnBall(lane: Lane, arrivalTime: Double) {
        let spawnTime = arrivalTime - travelSeconds
        let ball = BallNode(lane: lane, spawnTime: spawnTime)
        let x = lane == .left ? size.width * 0.3 : size.width * 0.7
        ball.position = CGPoint(x: x, y: size.height * spawnLineYRatio)
        addChild(ball)
        activeBalls.append(ball)
    }

    // MARK: Input

    @objc private func handleSwipeLeft()  { resolveSwipe(lane: .left) }
    @objc private func handleSwipeRight() { resolveSwipe(lane: .right) }

    private func resolveSwipe(lane: Lane) {
        guard let target = nearestBall(in: lane) else {
            registerMiss(lane: lane)
            return
        }
        let trackTime = CACurrentMediaTime() - startTime
        let arrivalTime = target.spawnTime + travelSeconds
        let delta = abs(trackTime - arrivalTime)
        let quality = HitQuality.grade(absDelta: delta)

        if quality == .miss {
            registerMiss(lane: lane)
            return
        }

        registerHit(ball: target, quality: quality)
    }

    private func nearestBall(in lane: Lane) -> BallNode? {
        let strikeY = size.height * strikeLineYRatio
        return activeBalls
            .filter { $0.lane == lane }
            .min { abs($0.position.y - strikeY) < abs($1.position.y - strikeY) }
    }

    // MARK: Hit / miss resolution — the _only_ event publishers

    private func registerHit(ball: BallNode, quality: HitQuality) {
        activeBalls.removeAll { $0 === ball }
        ball.removeFromParent()

        combo += 1
        maxCombo = max(maxCombo, combo)
        score += quality.baseScore * max(1, combo / 5)

        if quality.frameStopSeconds > 0 {
            frameStopUntil = CACurrentMediaTime() + quality.frameStopSeconds
        }

        GameEventBus.shared.publish(
            .hit(quality: quality, lane: ball.lane, position: ball.position, combo: combo)
        )

        let newTier = comboTier(for: combo)
        if newTier != lastComboTier {
            lastComboTier = newTier
            GameEventBus.shared.publish(.comboTier(newTier))
        }
    }

    private func registerMiss(lane: Lane) {
        let previous = combo
        if combo > 0 {
            combo = 0
            lastComboTier = 0
            GameEventBus.shared.publish(.comboBreak(previous: previous))
        }
        GameEventBus.shared.publish(.miss(lane: lane))
    }

    /// 0 → none, 1 → 5+, 2 → 15+, 3 → 30+, 4 → 50+. Used to gate audio stems.
    private func comboTier(for combo: Int) -> Int {
        switch combo {
        case 0..<5:    return 0
        case 5..<15:   return 1
        case 15..<30:  return 2
        case 30..<50:  return 3
        default:       return 4
        }
    }

    // MARK: Cleanup

    override func willMove(from view: SKView) {
        GameEventBus.shared.publish(.sessionEnd(finalScore: score, maxCombo: maxCombo))
    }
}

// MARK: - BallNode

final class BallNode: SKShapeNode {
    let lane: Lane
    /// Track-relative time at which this ball was spawned.
    let spawnTime: Double

    init(lane: Lane, spawnTime: Double) {
        self.lane = lane
        self.spawnTime = spawnTime
        super.init()
        let r: CGFloat = 22
        path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        fillColor = lane == .left
            ? UIColor(red: 0, green: 1, blue: 1, alpha: 1)
            : UIColor(red: 1, green: 0.2, blue: 0.7, alpha: 1)
        strokeColor = .white
        lineWidth = 1
        glowWidth = 10
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }
}
