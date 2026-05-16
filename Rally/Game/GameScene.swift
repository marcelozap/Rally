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

    // Hit-quality histogram, accumulated across the whole session. Drives
    // the end-of-run accuracy %, perfect rate, and reward math.
    private var perfectHits: Int = 0
    private var greatHits:   Int = 0
    private var goodHits:    Int = 0
    private var totalMisses: Int = 0

    private var activeBalls: [BallNode] = []
    private var startTime: TimeInterval = 0
    private var frameStopUntil: TimeInterval = 0
    private var isDying = false
    private var sessionEnded = false

    /// Set to `true` for the first `countdownSeconds` after the scene
    /// appears. Spawner is paused and input is ignored during this window
    /// so the player has time to settle. We don't gate gestures with a
    /// flag inside `handlePan`; we simply don't start the spawner clock
    /// until the countdown is done.
    private var isCountingDown = true

    private var spawner: RhythmSpawner?
    private var flow: MatchFlowCoordinator?

    private var cameraNode: SKCameraNode!
    private var scoreLabel: SKLabelNode!
    private var comboLabel: SKLabelNode!
    private var timeLabel: SKLabelNode!
    private var strikeLine: SKShapeNode!
    private var leftLaneGlow: SKShapeNode!
    private var rightLaneGlow: SKShapeNode!
    private var background: SynthwaveBackground!
    private var currentBPM: Double = 120
    private var lastBeatTime: TimeInterval = 0
    private var sessionStartWallTime: TimeInterval = 0

    // First-third / middle-third / last-third hit counters, so the end-of-run
    // summary can tell a story ("slow start — strong finish"). We bucket on
    // arrival, not on hit-time, so a missed ball at 2:55 still counts toward
    // the last third.
    private var segmentHits: [HitQuality: [Int]] = [
        .perfect: [0, 0, 0],
        .great:   [0, 0, 0],
        .good:    [0, 0, 0],
        .miss:    [0, 0, 0]
    ]

    #if DEBUG
    private var phaseDebugLabel: SKLabelNode?
    #endif

    // Pan-gesture swing state — see `handlePan(_:)`.
    private var swingOriginScene: CGPoint?
    private var swingTrailNode: SKShapeNode?
    private weak var swingPanRecognizer: UIPanGestureRecognizer?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        anchorPoint = CGPoint(x: 0, y: 0)

        setupCamera()
        setupBackground()
        setupLaneGlow()
        setupStrikeLine()
        setupHUD()
        setupSwipeRecognizers(in: view)

        ParticleManager.shared.attach(scene: self, shakeTarget: cameraNode)

        // Phase coordinator drives BPM, density, timing windows, double-ball
        // probability. The spawner asks it for a profile every time it needs
        // to author the next note. BPM resolution goes through
        // `RemoteTunables` so a live-ops manifest can shift the tempo curve
        // without shipping a build; falls back to bundled `Tunables`.
        let coordinator = MatchFlowCoordinator(
            sessionDurationSeconds: sessionDurationSeconds,
            bpmResolver: { phase in
                MainActor.assumeIsolated {
                    RemoteTunables.shared.bpm(for: phase)
                }
            }
        )
        coordinator.onPhaseChange = { [weak self] from, to in
            self?.handlePhaseChange(from: from, to: to)
        }
        flow = coordinator
        currentBPM = coordinator.currentProfile().bpm

        spawner = RhythmSpawner(
            flow: coordinator,
            travelSeconds: Tunables.ballTravelSeconds
        ) { [weak self] note in
            self?.spawnBall(lane: note.lane, arrivalTime: note.arrivalTime)
        }

        #if DEBUG
        installPhaseDebugLabel()
        #endif

        // Pre-set startTime so update() can run without crashing, but the
        // spawner won't advance until we flip `isCountingDown = false`
        // below. After the countdown we re-anchor `startTime` so trackTime
        // begins at zero from the player's perspective.
        startTime = CACurrentMediaTime()
        sessionStartWallTime = startTime
        lastBeatTime = startTime
        GameEventBus.shared.publish(.sessionStart)
        runCountdown()
    }

    // MARK: - Countdown

    /// Shows a 3-2-1-GO sequence above the strike line. While it's running
    /// the spawner is paused so the player has time to settle. Total
    /// duration: ~1.6s. We re-anchor `startTime` when it ends so the
    /// session timer always begins at 0:0X from the player's point of view.
    private func runCountdown() {
        isCountingDown = true
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.fontSize = 120
        label.fontColor = UIColor(red: 0, green: 1, blue: 1, alpha: 1)
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        label.zPosition = 100
        label.alpha = 0
        addChild(label)

        let steps: [(String, UIColor)] = [
            ("3", UIColor(red: 0, green: 1, blue: 1, alpha: 1)),
            ("2", UIColor(red: 0.4, green: 1, blue: 1, alpha: 1)),
            ("1", UIColor(red: 0.8, green: 1, blue: 0.4, alpha: 1)),
            ("GO", UIColor(red: 1.0, green: 0.2, blue: 0.7, alpha: 1))
        ]
        let perStep: TimeInterval = 0.4
        var seq: [SKAction] = []
        for (text, color) in steps {
            seq.append(.run { [weak label] in
                label?.text = text
                label?.fontColor = color
                label?.setScale(0.6)
            })
            seq.append(.group([
                .fadeAlpha(to: 1.0, duration: 0.08),
                .scale(to: 1.0, duration: 0.18)
            ]))
            seq.append(.fadeAlpha(to: 0.0, duration: perStep - 0.18))
        }
        seq.append(.run { [weak self, weak label] in
            label?.removeFromParent()
            guard let self = self else { return }
            self.isCountingDown = false
            // Re-anchor trackTime so the timer starts fresh.
            self.startTime = CACurrentMediaTime()
            self.lastBeatTime = CACurrentMediaTime()
        })
        label.run(.sequence(seq))
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

    private func setupBackground() {
        let bg = SynthwaveBackground(size: size, strikeYRatio: Tunables.strikeLineYRatio)
        bg.zPosition = -100
        addChild(bg)
        background = bg
    }

    /// Two soft, lane-aligned vertical glows. They sit behind the play
    /// field, just hinting at where each lane lives. Lane glow gives a
    /// "stage track" feel — the player's eye locks to the swipe target
    /// before the ball even arrives.
    private func setupLaneGlow() {
        let strikeY = size.height * Tunables.strikeLineYRatio
        let glowWidth = size.width * 0.18
        let glowHeight = size.height * (Tunables.spawnLineYRatio - Tunables.strikeLineYRatio) + 60

        let left = SKShapeNode(rect: CGRect(
            x: -glowWidth / 2, y: 0,
            width: glowWidth, height: glowHeight
        ), cornerRadius: glowWidth / 2)
        left.position = CGPoint(x: size.width * 0.3, y: strikeY)
        left.strokeColor = .clear
        left.fillColor = UIColor(red: 0, green: 1, blue: 1, alpha: 0.06)
        left.glowWidth = 24
        left.zPosition = -80
        addChild(left)
        leftLaneGlow = left

        let right = SKShapeNode(rect: CGRect(
            x: -glowWidth / 2, y: 0,
            width: glowWidth, height: glowHeight
        ), cornerRadius: glowWidth / 2)
        right.position = CGPoint(x: size.width * 0.7, y: strikeY)
        right.strokeColor = .clear
        right.fillColor = UIColor(red: 1, green: 0.2, blue: 0.7, alpha: 0.06)
        right.glowWidth = 24
        right.zPosition = -80
        addChild(right)
        rightLaneGlow = right
    }

    private func setupStrikeLine() {
        let y = size.height * Tunables.strikeLineYRatio
        let line = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -1.5, width: size.width, height: 3))
        line.position = CGPoint(x: size.width / 2, y: y)
        line.strokeColor = .clear
        line.fillColor = UIColor(red: 0, green: 1, blue: 1, alpha: 0.85)
        line.glowWidth = 12
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

        if !sessionEnded, !isCountingDown {
            flow?.update(trackTime: trackTime, combo: combo)
            if let profile = flow?.currentProfile() {
                // Travel time scales per phase — warm-up balls drift in,
                // breaker balls snap through. Update before the spawner ticks
                // so new spawns get the right horizon.
                spawner?.travelSeconds = Tunables.ballTravelSeconds * profile.travelScalar
                currentBPM = profile.bpm
            }
            spawner?.tick(trackTime: trackTime)
        }
        moveBalls(trackTime: trackTime)
        cullMissedBalls(trackTime: trackTime)
        updateTimeLabel(trackTime: trackTime)
        pulseOnBeatIfDue(currentTime: currentTime)

        if !sessionEnded, trackTime >= sessionDurationSeconds, activeBalls.isEmpty {
            sessionEnded = true
            GameEventBus.shared.publish(.sessionEnd(buildResult()))
        }
    }

    /// Throbs the strike line on every quarter-note tick of the current
    /// beatmap BPM. The pulse is short (`alpha`-only animation, no
    /// position) so it never visually conflicts with shake or frame-stop.
    private func pulseOnBeatIfDue(currentTime: TimeInterval) {
        guard !sessionEnded, currentBPM > 0, strikeLine != nil else { return }
        let beatSeconds = 60.0 / currentBPM
        if currentTime - lastBeatTime >= beatSeconds {
            lastBeatTime = currentTime
            let pulse = SKAction.sequence([
                .group([
                    .fadeAlpha(to: 1.0, duration: 0.05),
                    .scaleY(to: 2.4, duration: 0.05)
                ]),
                .group([
                    .fadeAlpha(to: 0.85, duration: 0.22),
                    .scaleY(to: 1.0, duration: 0.22)
                ])
            ])
            strikeLine.run(pulse)
        }
    }

    /// Snapshot of the current run state. Cheap — just copies counters.
    func buildResult() -> GameResult {
        let segments = (0..<3).map { i in
            SegmentStats(
                perfectHits: segmentHits[.perfect]?[i] ?? 0,
                greatHits:   segmentHits[.great]?[i]   ?? 0,
                goodHits:    segmentHits[.good]?[i]    ?? 0,
                misses:      segmentHits[.miss]?[i]    ?? 0
            )
        }
        return GameResult(
            finalScore: score,
            maxCombo: maxCombo,
            perfectHits: perfectHits,
            greatHits: greatHits,
            goodHits: goodHits,
            misses: totalMisses,
            segments: segments
        )
    }

    // MARK: - Phase handling

    private func handlePhaseChange(from: MatchFlowPhase, to: MatchFlowPhase) {
        GameEventBus.shared.publish(.phaseChanged(from: from, to: to))
        #if DEBUG
        phaseDebugLabel?.text = "Phase: \(to.rawValue)"
        #endif
    }

    #if DEBUG
    private func installPhaseDebugLabel() {
        let label = SKLabelNode(fontNamed: "Menlo")
        label.text = "Phase: WARM-UP"
        label.fontSize = 11
        label.fontColor = UIColor(white: 1, alpha: 0.45)
        label.horizontalAlignmentMode = .left
        label.position = CGPoint(x: 12, y: size.height - 18)
        label.zPosition = 200
        addChild(label)
        phaseDebugLabel = label
    }
    #endif

    private func updateTimeLabel(trackTime: Double) {
        guard let timeLabel = timeLabel else { return }
        // Freeze the timer at the full session length during the countdown
        // so the player doesn't see it tick down before they can even play.
        let effectiveTrackTime = isCountingDown ? 0 : trackTime
        let remaining = max(0, sessionDurationSeconds - effectiveTrackTime)
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
        guard !isDying, !isCountingDown, !sessionEnded else { return }

        guard let target = nearestBall(in: lane) else {
            // No ball to hit — count as a miss so the player feels the cost
            // of mashing.
            registerMiss(lane: lane)
            return
        }
        let trackTime = CACurrentMediaTime() - startTime
        let arrivalTime = target.spawnTime + Tunables.ballTravelSeconds
        let delta = abs(trackTime - arrivalTime)

        // Phase tightens / loosens the timing windows. Warm-up gives the
        // player a 10% wider perfect window; breaker shaves 15% off.
        let windowScalar = flow?.currentProfile().timingWindowScalar ?? 1.0
        var quality = HitQuality.grade(absDelta: delta, windowScalar: windowScalar)

        // A committed (fast) swing nudges a `.great` into `.perfect` when
        // the timing was on the very edge of the perfect window. Casual
        // taps never get this bump — they don't carry enough momentum to
        // earn it.
        if quality == .great,
           swingSpeed >= Tunables.swingFastVelocity,
           delta <= HitQuality.perfect.windowSeconds * windowScalar * 1.25
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
        // Perfect hits get the ball-shatter treatment; other grades just
        // disappear cleanly so the impact-emphasis stays earned.
        if quality == .perfect {
            shatterBall(ball)
        } else {
            ball.removeFromParent()
        }

        flashLaneGlow(lane: ball.lane, quality: quality)

        combo += 1
        maxCombo = max(maxCombo, combo)
        score += quality.baseScore * max(1, combo / 5)
        switch quality {
        case .perfect: perfectHits += 1
        case .great:   greatHits   += 1
        case .good:    goodHits    += 1
        case .miss:    break
        }
        recordInCurrentSegment(quality: quality)
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
        totalMisses += 1
        recordInCurrentSegment(quality: .miss)
        let previous = combo
        if combo > 0 {
            // The Flappy moment.
            triggerDeathSequence(previousCombo: previous)
        } else {
            // Soft miss — no combo to break, just a little buzz.
            GameEventBus.shared.publish(.miss(lane: lane))
        }
    }

    /// Bucket the hit/miss into the third of the session it belongs to.
    /// Drives the segmented stats shown on the end-of-run summary.
    private func recordInCurrentSegment(quality: HitQuality) {
        let trackTime = CACurrentMediaTime() - startTime
        let progress = sessionDurationSeconds <= 0
            ? 0
            : min(1, max(0, trackTime / sessionDurationSeconds))
        let segment: Int
        switch progress {
        case ..<(1.0 / 3.0): segment = 0
        case ..<(2.0 / 3.0): segment = 1
        default:             segment = 2
        }
        segmentHits[quality]?[segment] += 1
    }

    private func triggerDeathSequence(previousCombo: Int) {
        isDying = true
        combo = 0
        lastComboTier = 0
        updateHUD()

        frameStopUntil = CACurrentMediaTime() + Tunables.frameStopDeathMs.seconds
        flow?.registerComboBreak(at: CACurrentMediaTime() - startTime)
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
        punchHUD()
    }

    /// Quick scale-spring on the score label so each hit visibly *lands*
    /// in the HUD. Combo label punches at slightly different rhythm so the
    /// two pieces feel alive rather than synchronized.
    private func punchHUD() {
        if let s = scoreLabel {
            s.removeAction(forKey: "punch")
            let punch = SKAction.sequence([
                .scale(to: 1.18, duration: 0.06),
                .scale(to: 1.0, duration: 0.16)
            ])
            punch.timingMode = .easeOut
            s.run(punch, withKey: "punch")
        }
        if combo > 1, let c = comboLabel {
            c.removeAction(forKey: "punch")
            let punch = SKAction.sequence([
                .scale(to: 1.25, duration: 0.06),
                .scale(to: 1.0, duration: 0.20)
            ])
            punch.timingMode = .easeOut
            c.run(punch, withKey: "punch")
        }
    }

    // MARK: - Premium impact effects

    /// Replaces the ball with N small shards that fan out radially in the
    /// direction of the swing. Runs SKActions, so it respects frame-stop —
    /// the shatter "freezes" with the hit pause and resumes when the
    /// scene's `speed` returns to 1.
    private func shatterBall(_ ball: BallNode) {
        let center = ball.position
        ball.removeFromParent()

        let shardCount = 8
        let baseRadius = Tunables.ballRadiusPoints * 0.6
        let baseColor = ball.fillColor
        for i in 0..<shardCount {
            let shard = SKShapeNode(
                circleOfRadius: baseRadius * CGFloat.random(in: 0.35...0.55)
            )
            shard.fillColor = baseColor
            shard.strokeColor = .white
            shard.lineWidth = 0.5
            shard.glowWidth = 4
            shard.position = center
            shard.zPosition = 25
            addChild(shard)

            // Even angular distribution + small jitter so shards don't look
            // mechanical. Trajectory is upward-fanning (toward the spawn
            // line) to read as "ball powered back into the rally".
            let angle = -CGFloat.pi / 2 + (CGFloat(i) / CGFloat(shardCount) - 0.5) * .pi * 0.9
            let dist  = CGFloat.random(in: 120...220)
            let target = CGPoint(
                x: center.x + cos(angle) * dist,
                y: center.y - sin(angle) * dist
            )
            let dur = TimeInterval.random(in: 0.35...0.55)
            let move = SKAction.move(to: target, duration: dur)
            move.timingMode = .easeOut
            shard.run(.sequence([
                .group([
                    move,
                    .fadeOut(withDuration: dur),
                    .scale(to: 0.2, duration: dur)
                ]),
                .removeFromParent()
            ]))
        }
    }

    /// Brightens the corresponding lane glow for a beat, then fades back.
    /// Perfect hits get a much louder flash than `.great`/`.good`.
    private func flashLaneGlow(lane: Lane, quality: HitQuality) {
        let glow = lane == .left ? leftLaneGlow : rightLaneGlow
        guard let glow else { return }
        let peak: CGFloat
        let durationUp: TimeInterval
        let durationDown: TimeInterval
        switch quality {
        case .perfect:
            peak = 0.35
            durationUp = 0.04
            durationDown = 0.32
        case .great:
            peak = 0.20
            durationUp = 0.05
            durationDown = 0.25
        case .good:
            peak = 0.12
            durationUp = 0.06
            durationDown = 0.20
        case .miss:
            return
        }
        glow.removeAllActions()
        glow.run(.sequence([
            .fadeAlpha(to: peak, duration: durationUp),
            .fadeAlpha(to: 1.0, duration: 0),
            .fadeAlpha(to: 0.4, duration: durationDown)
        ]))
        if quality == .perfect {
            background?.pulseHorizon(intensity: 1.0)
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
            GameEventBus.shared.publish(.sessionEnd(buildResult()))
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
