import SpriteKit
import UIKit

/// Core SpriteKit scene. The single publisher of `GameEvent`s. All feedback
/// (audio, haptics, particles, shake) is decoupled via `GameEventBus`.
///
/// ## Camera
///
/// We use an `SKCameraNode` even though the world is static, so that screen
/// shake is a single position offset on the camera rather than translating
/// every node. The camera is what `ParticleManager` shakes via
/// `CameraShake.shake(_:)`.
///
/// ## Frame-stop
///
/// `scene.speed = 0` halts all `SKAction`s and the update loop, achieving a
/// classic "hit pause." We use it sparingly on hits (per `Tunables`) and
/// generously on death.
final class GameScene: SKScene {

    // MARK: - Configuration

    /// How long a single rally session lasts before `sessionEnd` is fired.
    /// The procedural beatmap is generated to match.
    var sessionDurationSeconds: Double = 180

    // MARK: - Runtime state

    private var combo: Int = 0
    private var maxCombo: Int = 0
    private var score: Int = 0
    private var lastComboTier: Int = 0

    private var activeBalls: [BallNode] = []
    private var startTime: TimeInterval = 0
    private var frameStopUntil: TimeInterval = 0
    private var isDying = false
    private var sessionEnded = false

    private var spawner: RhythmSpawner?

    private var cameraNode: SKCameraNode!
    private var scoreLabel: SKLabelNode!
    private var comboLabel: SKLabelNode!
    private var timeLabel: SKLabelNode!
    private var strikeLine: SKShapeNode!

    // Pan-gesture swing state — see `handlePan(_:)`.
    private var swingOriginScene: CGPoint?
    private var swingTrailNode: SKShapeNode?
    private weak var swingPanRecognizer: UIPanGestureRecognizer?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero

        setupCamera()
        setupStrikeLine()
        setupHUD()
        setupSwipeRecognizers(in: view)

        ParticleManager.shared.attach(scene: self, shakeTarget: cameraNode)

        let beatmap = Beatmap.procedural(durationSeconds: sessionDurationSeconds)
        spawner = RhythmSpawner(
            beatmap: beatmap,
            travelSeconds: Tunables.ballTravelSeconds
        ) { [weak self] note in
            self?.spawnBall(lane: note.lane, arrivalTime: note.arrivalTime)
        }

        startTime = CACurrentMediaTime()
        GameEventBus.shared.publish(.sessionStart)
    }

    private func setupCamera() {
        let cam = SKCameraNode()
        cam.position = CGPoint(x: 0, y: 0)
        addChild(cam)
        camera = cam
        cameraNode = cam
        // Keep the camera at scene-center so position offsets from
        // CameraShake read as "screen shake" rather than "scroll".
        cam.position = CGPoint(x: 0, y: 0)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        // SKCameraNode's position is in scene coordinates. With anchorPoint
        // (0,0), camera at (size.width/2, size.height/2) shows centered.
        anchorPoint = CGPoint(x: 0, y: 0)
        cameraNode?.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // Re-layout strike line if it exists.
        if let line = strikeLine {
            line.position = CGPoint(x: size.width / 2, y: size.height * Tunables.strikeLineYRatio)
            line.path = CGPath(
                rect: CGRect(x: -size.width / 2, y: -1, width: size.width, height: 2),
                transform: nil
            )
        }
        if let label = scoreLabel {
            label.position = CGPoint(x: size.width / 2, y: size.height * 0.88)
        }
        if let combo = comboLabel {
            combo.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        }
    }

    private func setupStrikeLine() {
        let y = size.height * Tunables.strikeLineYRatio
        let line = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -1, width: size.width, height: 2))
        line.position = CGPoint(x: size.width / 2, y: y)
        line.strokeColor = .clear
        line.fillColor = UIColor(red: 0, green: 1, blue: 1, alpha: 0.4)
        line.glowWidth = 8
        line.zPosition = 10
        addChild(line)
        strikeLine = line
    }

    private func setupHUD() {
        let score = SKLabelNode(fontNamed: "AvenirNext-Bold")
        score.text = "0"
        score.fontSize = 48
        score.fontColor = .white
        score.position = CGPoint(x: size.width / 2, y: size.height * 0.88)
        score.zPosition = 50
        score.horizontalAlignmentMode = .center
        addChild(score)
        scoreLabel = score

        let combo = SKLabelNode(fontNamed: "AvenirNext-Medium")
        combo.text = ""
        combo.fontSize = 22
        combo.fontColor = UIColor(white: 1, alpha: 0.6)
        combo.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        combo.zPosition = 50
        combo.horizontalAlignmentMode = .center
        addChild(combo)
        comboLabel = combo

        let time = SKLabelNode(fontNamed: "AvenirNext-Medium")
        time.text = "3:00"
        time.fontSize = 18
        time.fontColor = UIColor(white: 1, alpha: 0.5)
        time.position = CGPoint(x: size.width / 2, y: size.height * 0.93)
        time.zPosition = 50
        time.horizontalAlignmentMode = .center
        addChild(time)
        timeLabel = time
    }

    /// Wires the single-finger pan recognizer used for the swing input. Pan
    /// (vs. discrete `UISwipeGestureRecognizer`) gives us the full touch
    /// trajectory — start point, live position, release velocity — which we
    /// need to render the swing trail and grade swing commitment.
    private func setupSwipeRecognizers(in view: SKView) {
        // Remove any stale recognizer from a previous scene presentation.
        if let stale = swingPanRecognizer {
            view.removeGestureRecognizer(stale)
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        swingPanRecognizer = pan
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        if currentTime < frameStopUntil {
            speed = 0
            return
        }
        speed = 1

        let trackTime = currentTime - startTime

        if !sessionEnded {
            spawner?.tick(trackTime: trackTime)
        }
        moveBalls(trackTime: trackTime)
        cullMissedBalls(trackTime: trackTime)
        updateTimeLabel(trackTime: trackTime)

        if !sessionEnded, trackTime >= sessionDurationSeconds, activeBalls.isEmpty {
            sessionEnded = true
            GameEventBus.shared.publish(.sessionEnd(finalScore: score, maxCombo: maxCombo))
        }
    }

    private func updateTimeLabel(trackTime: Double) {
        guard let timeLabel = timeLabel else { return }
        let remaining = max(0, sessionDurationSeconds - trackTime)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        timeLabel.text = String(format: "%d:%02d", minutes, seconds)
    }

    private func moveBalls(trackTime: Double) {
        let strikeY = size.height * Tunables.strikeLineYRatio
        let spawnY  = size.height * Tunables.spawnLineYRatio
        let distance = spawnY - strikeY

        for ball in activeBalls {
            let progress = max(0, min(1, (trackTime - ball.spawnTime) / Tunables.ballTravelSeconds))
            ball.position.y = spawnY - distance * CGFloat(progress)
        }
    }

    private func cullMissedBalls(trackTime: Double) {
        let strikeY = size.height * Tunables.strikeLineYRatio
        var stillAlive: [BallNode] = []
        for ball in activeBalls {
            if ball.position.y < strikeY - Tunables.cullBelowStrikePoints {
                ball.removeFromParent()
                registerMiss(lane: ball.lane)
            } else {
                stillAlive.append(ball)
            }
        }
        activeBalls = stillAlive
    }

    // MARK: - Spawning (called by RhythmSpawner)

    func spawnBall(lane: Lane, arrivalTime: Double) {
        let spawnTime = arrivalTime - Tunables.ballTravelSeconds
        let ball = BallNode(lane: lane, spawnTime: spawnTime)
        let x = lane == .left ? size.width * 0.3 : size.width * 0.7
        ball.position = CGPoint(x: x, y: size.height * Tunables.spawnLineYRatio)
        addChild(ball)
        activeBalls.append(ball)
    }

    // MARK: - Input — Pokemon-Go-style pan gesture

    /// Single-finger swing recognizer.
    ///
    /// - `.began`: capture the touch origin in scene coords, instantiate the
    ///   swing trail node.
    /// - `.changed`: redraw the trail from origin → current finger position.
    /// - `.ended`: compute the release vector + velocity. If the drag is
    ///   long enough (`Tunables.swingMinDistance`), resolve a swing on the
    ///   lane indicated by the dominant horizontal sign and grade with the
    ///   existing hit-timing logic. Short flicks below the threshold are
    ///   ignored — they're how the player adjusts grip without committing.
    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let view = self.view else { return }
        let viewPoint = pan.location(in: view)
        let scenePoint = convertPoint(fromView: viewPoint)

        switch pan.state {
        case .began:
            swingOriginScene = scenePoint
            installSwingTrail(at: scenePoint)

        case .changed:
            guard let origin = swingOriginScene else { return }
            updateSwingTrail(from: origin, to: scenePoint)

        case .ended:
            defer {
                swingOriginScene = nil
                fadeSwingTrail()
            }
            guard let origin = swingOriginScene else { return }
            let dx = scenePoint.x - origin.x
            let dy = scenePoint.y - origin.y
            let distance = hypot(dx, dy)

            let v = pan.velocity(in: view)
            let speed = hypot(v.x, v.y)

            // Ignore taps and accidental contact — only deliberate motion
            // commits a swing.
            guard distance >= Tunables.swingMinDistance else { return }

            // Lane is decided by the dominant horizontal sign. Verticality
            // is currently informational only (reserved for future "lob" or
            // "drop shot" variants).
            let lane: Lane = dx < 0 ? .left : .right
            resolveSwing(lane: lane, swingSpeed: speed)

        case .cancelled, .failed:
            swingOriginScene = nil
            fadeSwingTrail()

        default:
            break
        }
    }

    // MARK: - Swing trail rendering

    private func installSwingTrail(at origin: CGPoint) {
        let trail = SKShapeNode()
        trail.strokeColor = UIColor(red: 0, green: 1, blue: 1, alpha: 0.85)
        trail.fillColor = .clear
        trail.lineWidth = Tunables.swingTrailLineWidth
        trail.glowWidth = Tunables.swingTrailGlowWidth
        trail.lineCap = .round
        trail.zPosition = 60

        let path = CGMutablePath()
        path.move(to: origin)
        path.addLine(to: origin)
        trail.path = path

        addChild(trail)
        swingTrailNode = trail
    }

    private func updateSwingTrail(from origin: CGPoint, to current: CGPoint) {
        guard let trail = swingTrailNode else { return }
        let path = CGMutablePath()
        path.move(to: origin)
        path.addLine(to: current)
        trail.path = path

        // Trail brightens as the swing gets longer — visual reward for
        // committing.
        let distance = hypot(current.x - origin.x, current.y - origin.y)
        let intensity = min(1, distance / 220)
        trail.strokeColor = UIColor(
            red: 0,
            green: 1,
            blue: 1,
            alpha: 0.4 + 0.5 * intensity
        )
        trail.glowWidth = Tunables.swingTrailGlowWidth + 10 * intensity
    }

    private func fadeSwingTrail() {
        guard let trail = swingTrailNode else { return }
        swingTrailNode = nil
        trail.run(.sequence([
            .fadeOut(withDuration: 0.18),
            .removeFromParent()
        ]))
    }

    // MARK: - Swing resolution

    private func resolveSwing(lane: Lane, swingSpeed: CGFloat) {
        guard !isDying else { return }

        guard let target = nearestBall(in: lane) else {
            // No ball to hit — count as a miss so the player feels the cost
            // of mashing.
            registerMiss(lane: lane)
            return
        }
        let trackTime = CACurrentMediaTime() - startTime
        let arrivalTime = target.spawnTime + Tunables.ballTravelSeconds
        let delta = abs(trackTime - arrivalTime)
        var quality = HitQuality.grade(absDelta: delta)

        // A committed (fast) swing nudges a `.great` into `.perfect` when
        // the timing was on the very edge of the perfect window. Casual
        // taps never get this bump — they don't carry enough momentum to
        // earn it.
        if quality == .great,
           swingSpeed >= Tunables.swingFastVelocity,
           delta <= HitQuality.perfect.windowSeconds * 1.25
        {
            quality = .perfect
        }

        if quality == .miss {
            registerMiss(lane: lane)
            return
        }
        registerHit(ball: target, quality: quality)
    }

    private func nearestBall(in lane: Lane) -> BallNode? {
        let strikeY = size.height * Tunables.strikeLineYRatio
        return activeBalls
            .filter { $0.lane == lane }
            .min { abs($0.position.y - strikeY) < abs($1.position.y - strikeY) }
    }

    // MARK: - Hit / miss

    private func registerHit(ball: BallNode, quality: HitQuality) {
        activeBalls.removeAll { $0 === ball }
        ball.removeFromParent()

        combo += 1
        maxCombo = max(maxCombo, combo)
        score += quality.baseScore * max(1, combo / 5)
        updateHUD()

        let freezeMs: Double
        switch quality {
        case .perfect: freezeMs = Tunables.frameStopPerfectMs
        case .great:   freezeMs = Tunables.frameStopGreatMs
        case .good:    freezeMs = Tunables.frameStopGoodMs
        case .miss:    freezeMs = Tunables.frameStopMissMs
        }
        if freezeMs > 0 {
            frameStopUntil = CACurrentMediaTime() + freezeMs.seconds
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
            // The Flappy moment.
            triggerDeathSequence(previousCombo: previous)
        } else {
            // Soft miss — no combo to break, just a little buzz.
            GameEventBus.shared.publish(.miss(lane: lane))
        }
    }

    private func triggerDeathSequence(previousCombo: Int) {
        isDying = true
        combo = 0
        lastComboTier = 0
        updateHUD()

        frameStopUntil = CACurrentMediaTime() + Tunables.frameStopDeathMs.seconds
        GameEventBus.shared.publish(.comboBreak(previous: previousCombo))

        // Clear in-flight balls so the player isn't immediately killed again
        // when the freeze ends.
        for ball in activeBalls {
            let fade = SKAction.fadeOut(withDuration: 0.18)
            ball.run(.sequence([fade, .removeFromParent()]))
        }
        activeBalls.removeAll()

        // Brief cooldown after the freeze ends before we accept input again.
        DispatchQueue.main.asyncAfter(deadline: .now() + Tunables.frameStopDeathMs.seconds + 0.15) {
            [weak self] in
            self?.isDying = false
        }
    }

    // MARK: - Public score accessors (for SwiftUI overlays)

    var currentScore: Int { score }
    var currentCombo: Int { combo }
    var currentMaxCombo: Int { maxCombo }
    var sessionIsOver: Bool { sessionEnded }

    private func updateHUD() {
        scoreLabel?.text = "\(score)"
        if combo > 1 {
            comboLabel?.text = "x\(combo)"
        } else {
            comboLabel?.text = ""
        }
    }

    private func comboTier(for combo: Int) -> Int {
        switch combo {
        case 0..<Tunables.comboTier1: return 0
        case Tunables.comboTier1..<Tunables.comboTier2: return 1
        case Tunables.comboTier2..<Tunables.comboTier3: return 2
        case Tunables.comboTier3..<Tunables.comboTier4: return 3
        default: return 4
        }
    }

    // MARK: - Teardown

    override func willMove(from view: SKView) {
        if !sessionEnded {
            sessionEnded = true
            GameEventBus.shared.publish(.sessionEnd(finalScore: score, maxCombo: maxCombo))
        }
    }
}

// MARK: - BallNode

final class BallNode: SKShapeNode {
    let lane: Lane
    let spawnTime: Double

    init(lane: Lane, spawnTime: Double) {
        self.lane = lane
        self.spawnTime = spawnTime
        super.init()
        let r = Tunables.ballRadiusPoints
        path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        fillColor = lane == .left
            ? UIColor(red: 0, green: 1, blue: 1, alpha: 1)
            : UIColor(red: 1, green: 0.2, blue: 0.7, alpha: 1)
        strokeColor = .white
        lineWidth = 1
        glowWidth = 10
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
