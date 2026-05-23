import SpriteKit
import UIKit
import os.signpost

/// Core SpriteKit scene. The single publisher of `GameEvent`s. Tennis-style
/// play: incoming balls from the far court, fixed racket, swipe to aim.
/// Feedback (audio, haptics, particles, shake) is decoupled via `GameEventBus`.
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

    /// Wall-clock length of a rally session before `sessionEnd` is fired.
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
    /// Wall-clock deadline at which `isDying` clears. Replaces the prior
    /// `DispatchQueue.main.asyncAfter` cooldown so app-backgrounding or
    /// scene-pause can't lose the recovery clock.
    private var dyingUntil: TimeInterval = 0
    private var sessionEnded = false

    /// Set to `true` for the first `countdownSeconds` after the scene
    /// appears. Spawner is paused and input is ignored during this window
    /// so the player has time to settle. We don't gate gestures with a
    /// flag inside `handlePan`; we simply don't start the spawner clock
    /// until the countdown is done.
    private var isCountingDown = true

    private var ballFeed: TennisBallFeed?
    /// Drives adaptive music stems only (no gameplay spawn logic).
    private var lastMusicPhase: MatchFlowPhase = .warmUp
    /// "Echo Trail" — neon path drawn through every perfect hit once the
    /// player crosses tier-1 combo. Owned by the scene so it can be
    /// reset on session restart.
    private let echoTrail = EchoTrail()

    private var cameraNode: SKCameraNode!
    private var scoreLabel: SKLabelNode!
    private var comboLabel: SKLabelNode!
    private var timeLabel: SKLabelNode!
    private var strikeLine: SKShapeNode!
    private var strikePulse: StrikeLinePulse!
    private var racketNode: SKNode!
    private var courtBackdrop: TennisCourtBackdrop!
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
    //
    // Rally commits a swing the **first frame** the drag distance crosses
    // `Tunables.swingMinDistance`, not on finger-lift. Committing on
    // `.ended` adds ~50–150 ms of input lag vs. the ball (finger-lift
    // latency); committing on threshold-crossing puts the strike-quality
    // decision inside the same vsync as the player's intent.
    //
    // `swingCommitted` is true between commit and the next `.began`. While
    // it's true, further `.changed` ticks only update the trail (so the
    // visual still tracks the finger), and `.ended` is a no-op.
    private var swingOriginScene: CGPoint?
    private var swingCommitted: Bool = false
    private var swingTrailNode: SKShapeNode?
    private weak var swingPanRecognizer: UIPanGestureRecognizer?

    #if DEBUG
    /// Dispatch-latency instrumentation: from `.began` (touch-down) to the
    /// moment `.hit` (or `.miss`) is published on the event bus. Targets:
    /// <8 ms (half a vsync at 60 Hz). View in Instruments → Points of Interest.
    private static let inputSignposter = OSSignposter(subsystem: "rally.game", category: "input")
    private var inputSignpostID: OSSignpostID?
    private var inputSignpostState: OSSignpostIntervalState?
    #endif

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = CGVector(dx: 0, dy: Tunables.tennisGravityDy)
        anchorPoint = CGPoint(x: 0, y: 0)

        setupCamera()
        setupCourtBackdrop()
        setupRacket()
        setupStrikeLine()
        setupHUD()
        setupSwipeRecognizers(in: view)

        ParticleManager.shared.attach(scene: self, shakeTarget: cameraNode)
        echoTrail.attach(scene: self)

        ballFeed = TennisBallFeed(
            travelSeconds: Tunables.live.ballTravelSeconds,
            sessionDurationSeconds: sessionDurationSeconds
        ) { [weak self] arrival in
            self?.enqueueIncomingBall(arrivalTime: arrival)
        }
        lastMusicPhase = .warmUp

        #if DEBUG
        installPhaseDebugLabel()
        #endif

        // Pre-set startTime so update() can run without crashing, but the
        // spawner won't advance until we flip `isCountingDown = false`
        // below. After the countdown we re-anchor `startTime` so trackTime
        // begins at zero from the player's perspective.
        startTime = CACurrentMediaTime()
        sessionStartWallTime = startTime
        GameEventBus.shared.publish(.sessionStart)
        layoutCamera()
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
        })
        label.run(.sequence(seq))
    }

    private func setupCamera() {
        let cam = SKCameraNode()
        addChild(cam)
        camera = cam
        cameraNode = cam
        layoutCamera()
    }

    /// With anchorPoint (0,0), the camera must sit at scene-center so the
    /// full playfield fills the view. Off-center camera = content shoved to
    /// a corner (the top-right bug after the tennis redesign).
    private func layoutCamera() {
        anchorPoint = CGPoint(x: 0, y: 0)
        cameraNode?.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    /// Re-centers the camera after SwiftUI resizes the hosted scene. Safe to
    /// call any time after `didMove(to:)`.
    func relayoutForPresentation() {
        layoutCamera()
    }

    /// Marks the session finished without publishing `.sessionEnd`. Call
    /// before tearing down the scene when the player exits voluntarily so
    /// we don't flash the game-over overlay during `fullScreenCover` dismiss.
    func abortSessionSilently() {
        sessionEnded = true
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutCamera()

        // Re-layout strike line if it exists.
        if let line = strikeLine {
            line.position = CGPoint(x: size.width / 2, y: size.height * Tunables.strikeLineYRatio)
            line.path = CGPath(
                rect: CGRect(x: -size.width / 2, y: -1, width: size.width, height: 2),
                transform: nil
            )
        }
        if let pulse = strikePulse {
            pulse.position = CGPoint(x: size.width / 2, y: size.height * Tunables.strikeLineYRatio)
            pulse.resize(toWidth: size.width)
        }
        courtBackdrop?.resize(to: size)
        layoutRacket()
        layoutHUD()
    }

    private func setupCourtBackdrop() {
        let backdrop = TennisCourtBackdrop(
            size: size,
            strikeYRatio: Tunables.strikeLineYRatio,
            surface: CourtVenue.current
        )
        addChild(backdrop)
        courtBackdrop = backdrop
    }

    /// Fixed racket at center baseline — character does not move; aim with swipe angle.
    private func setupRacket() {
        let racket = SKNode()
        let frameColor = UIColor(white: 0.95, alpha: 1)
        let fillColor = UIColor(white: 0.14, alpha: 0.55)
        let stringColor = UIColor(white: 0.88, alpha: 0.38)

        let head = SKShapeNode(ellipseIn: CGRect(x: -28, y: 6, width: 56, height: 64))
        head.strokeColor = frameColor
        head.fillColor = fillColor
        head.lineWidth = 2.8
        head.glowWidth = 4
        head.zPosition = 1
        racket.addChild(head)

        for i in 0..<6 {
            let x = -22 + CGFloat(i) * 8.8
            let string = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: 12))
            path.addLine(to: CGPoint(x: x, y: 62))
            string.path = path
            string.strokeColor = stringColor
            string.lineWidth = 0.9
            string.lineCap = .round
            string.zPosition = 2
            racket.addChild(string)
        }
        for i in 0..<5 {
            let y = 16 + CGFloat(i) * 11.5
            let string = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -24, y: y))
            path.addLine(to: CGPoint(x: 24, y: y))
            string.path = path
            string.strokeColor = stringColor
            string.lineWidth = 0.9
            string.lineCap = .round
            string.zPosition = 2
            racket.addChild(string)
        }

        let throatLeft = SKShapeNode()
        var throatPath = CGMutablePath()
        throatPath.move(to: CGPoint(x: -10, y: 8))
        throatPath.addLine(to: CGPoint(x: -4, y: -8))
        throatLeft.path = throatPath
        throatLeft.strokeColor = frameColor
        throatLeft.lineWidth = 2.4
        throatLeft.lineCap = .round
        throatLeft.zPosition = 1
        racket.addChild(throatLeft)

        let throatRight = SKShapeNode()
        throatPath = CGMutablePath()
        throatPath.move(to: CGPoint(x: 10, y: 8))
        throatPath.addLine(to: CGPoint(x: 4, y: -8))
        throatRight.path = throatPath
        throatRight.strokeColor = frameColor
        throatRight.lineWidth = 2.4
        throatRight.lineCap = .round
        throatRight.zPosition = 1
        racket.addChild(throatRight)

        let handle = SKShapeNode(rect: CGRect(x: -5, y: -54, width: 10, height: 46), cornerRadius: 3)
        handle.strokeColor = frameColor
        handle.fillColor = UIColor(white: 0.22, alpha: 0.85)
        handle.lineWidth = 2
        handle.zPosition = 1
        racket.addChild(handle)

        for i in 0..<5 {
            let grip = SKShapeNode(rectOf: CGSize(width: 8, height: 2.2), cornerRadius: 1)
            grip.fillColor = UIColor(white: 0.08, alpha: 0.55)
            grip.strokeColor = .clear
            grip.position = CGPoint(x: 0, y: -14 - CGFloat(i) * 7.5)
            grip.zPosition = 2
            racket.addChild(grip)
        }

        let buttCap = SKShapeNode(circleOfRadius: 4.5)
        buttCap.fillColor = UIColor(white: 0.28, alpha: 1)
        buttCap.strokeColor = frameColor
        buttCap.lineWidth = 1.5
        buttCap.position = CGPoint(x: 0, y: -56)
        buttCap.zPosition = 1
        racket.addChild(buttCap)

        racket.zPosition = 45
        addChild(racket)
        racketNode = racket
        layoutRacket()
    }

    private func layoutRacket() {
        guard let racket = racketNode else { return }
        let strikeY = size.height * Tunables.strikeLineYRatio
        racket.position = CGPoint(x: size.width / 2, y: strikeY - 22)
    }

    private func setupStrikeLine() {
        let y = size.height * Tunables.strikeLineYRatio
        let line = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -1, width: size.width, height: 2))
        line.position = CGPoint(x: size.width / 2, y: y)
        line.strokeColor = .clear
        line.fillColor = UIColor(white: 1, alpha: 0.55)
        line.glowWidth = 6
        line.zPosition = 12
        addChild(line)
        strikeLine = line

        // Anticipation pulse — colocated with the static line, pulsed once
        // per inbound ball so the player's timing read isn't depth-scale-only.
        let pulse = StrikeLinePulse(
            width: size.width,
            color: UIColor(red: 0, green: 1, blue: 1, alpha: 1)
        )
        pulse.position = line.position
        addChild(pulse)
        strikePulse = pulse
    }

    /// HUD lives as children of `cameraNode` so the world can shake under
    /// the HUD without the HUD jittering with it. Positions are in
    /// camera-local coordinates — `(0,0)` is the view center.
    private func setupHUD() {
        let score = SKLabelNode(fontNamed: "AvenirNext-Bold")
        score.text = "0"
        score.fontSize = 48
        score.fontColor = .white
        score.zPosition = 50
        score.horizontalAlignmentMode = .center
        cameraNode.addChild(score)
        scoreLabel = score

        let combo = SKLabelNode(fontNamed: "AvenirNext-Medium")
        combo.text = ""
        combo.fontSize = 22
        combo.fontColor = UIColor(white: 1, alpha: 0.6)
        combo.zPosition = 50
        combo.horizontalAlignmentMode = .center
        cameraNode.addChild(combo)
        comboLabel = combo

        let time = SKLabelNode(fontNamed: "AvenirNext-Medium")
        time.text = "3:00"
        time.fontSize = 18
        time.fontColor = UIColor(white: 1, alpha: 0.5)
        time.zPosition = 50
        time.horizontalAlignmentMode = .center
        cameraNode.addChild(time)
        timeLabel = time

        layoutHUD()
    }

    /// Position the camera-attached HUD labels. Called from `setupHUD()`
    /// and `didChangeSize(_:)`.
    ///
    /// Camera-local origin `(0, 0)` is the center of the view, so a label
    /// at `(0, +size.height * (ratio - 0.5))` reads as "ratio % from the
    /// bottom of the screen" the same way the old scene-coord positions did.
    private func layoutHUD() {
        guard cameraNode != nil else { return }
        scoreLabel?.position = CGPoint(x: 0, y: size.height * (0.88 - 0.5))
        comboLabel?.position = CGPoint(x: 0, y: size.height * (0.82 - 0.5))
        timeLabel?.position  = CGPoint(x: 0, y: size.height * (0.93 - 0.5))
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
        view.isUserInteractionEnabled = true
        view.isMultipleTouchEnabled = false

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delegate = self
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

        // Pause-safe death recovery: clear `isDying` once we're past the
        // wall-clock deadline set in `triggerDeathSequence`. This is
        // checked *after* the frame-stop early-return so the cooldown
        // never expires while the scene is frozen.
        if isDying, currentTime >= dyingUntil {
            isDying = false
        }

        let trackTime = currentTime - startTime

        if !sessionEnded, !isCountingDown {
            let scalar = sessionDifficultyScalars(trackTime: trackTime)
            ballFeed?.travelSeconds = Tunables.live.ballTravelSeconds * scalar.travel
            ballFeed?.tick(trackTime: trackTime)
            updateMusicPhaseIfNeeded(trackTime: trackTime)
        }
        moveBalls(trackTime: trackTime)
        cullMissedBalls(trackTime: trackTime)
        updateTimeLabel(trackTime: trackTime)

        if !sessionEnded, trackTime >= sessionDurationSeconds, activeBalls.isEmpty {
            sessionEnded = true
            GameEventBus.shared.publish(.sessionEnd(buildResult()))
        }
    }

    /// Time-based difficulty: faster inbound balls and tighter timing windows in the late session.
    private func sessionDifficultyScalars(trackTime: Double) -> (travel: Double, timing: Double) {
        let denom = max(sessionDurationSeconds, 1)
        let p = min(1, max(0, trackTime / denom))
        let travel = Tunables.sessionTravelScalarStart
            + (Tunables.sessionTravelScalarEnd - Tunables.sessionTravelScalarStart) * p
        let timing = Tunables.sessionTimingWindowScalarStart
            + (Tunables.sessionTimingWindowEnd - Tunables.sessionTimingWindowScalarStart) * p
        return (travel, timing)
    }

    /// Keeps adaptive music aligned with session arcs (no rhythm chart).
    private func updateMusicPhaseIfNeeded(trackTime: Double) {
        let denom = max(sessionDurationSeconds, 0.01)
        let progress = min(1, max(0, trackTime / denom))
        let newPhase: MatchFlowPhase
        switch progress {
        case ..<Tunables.sessionPhaseWarmUpCutoff:   newPhase = .warmUp
        case ..<Tunables.sessionPhaseExchangeCutoff: newPhase = .exchange
        case ..<Tunables.sessionPhasePressureCutoff: newPhase = .pressure
        default:                                      newPhase = .breaker
        }
        guard newPhase != lastMusicPhase else { return }
        GameEventBus.shared.publish(.phaseChanged(from: lastMusicPhase, to: newPhase))
        #if DEBUG
        phaseDebugLabel?.text = "Phase: \(newPhase.rawValue)"
        #endif
        lastMusicPhase = newPhase
    }

    private func enqueueIncomingBall(arrivalTime: Double) {
        guard !sessionEnded, !isCountingDown, !isDying else { return }
        if activeBalls.contains(where: { !$0.isLaunched }) { return }
        spawnBall(arrivalTime: arrivalTime)
    }

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

        for ball in activeBalls where !ball.isLaunched {
            let progress = max(0, min(1, (trackTime - ball.spawnTime) / ball.travelDuration))
            ball.position.y = spawnY - distance * CGFloat(progress)
            ball.position.x = ball.approachStartX + (ball.approachEndX - ball.approachStartX) * CGFloat(progress)
            let depth = Tunables.ballDepthScaleFar
                + (Tunables.ballDepthScaleNear - Tunables.ballDepthScaleFar) * CGFloat(progress)
            ball.setScale(depth)
        }
    }

    private func cullMissedBalls(trackTime: Double) {
        let strikeY = size.height * Tunables.strikeLineYRatio
        let margin: CGFloat = 100
        var stillAlive: [BallNode] = []
        for ball in activeBalls {
            if ball.isLaunched {
                if ball.position.y > size.height + margin * 2
                    || ball.position.y < -margin * 4
                    || ball.position.x < -margin * 2
                    || ball.position.x > size.width + margin * 2 {
                    ball.removeFromParent()
                } else {
                    stillAlive.append(ball)
                }
                continue
            }
            if ball.position.y < strikeY - Tunables.cullBelowStrikePoints {
                ball.removeFromParent()
                // Ball fell past the strike line untouched — no swing was
                // made, so we have no timing delta to ghost.
                registerMiss(lane: .left, signedDelta: nil)
            } else {
                stillAlive.append(ball)
            }
        }
        activeBalls = stillAlive
    }

    // MARK: - Spawning (TennisBallFeed)

    private func spawnBall(arrivalTime: Double) {
        let travel = ballFeed?.travelSeconds ?? Tunables.ballTravelSeconds
        let spawnTime = arrivalTime - travel
        let cx = size.width / 2
        let jitter = CGFloat.random(in: -Tunables.tennisSpawnJitterX...Tunables.tennisSpawnJitterX)
        let approachStartX = cx + jitter * 1.12
        let approachEndX = cx + CGFloat.random(in: -20...20)
        let ball = BallNode(
            spawnTime: spawnTime,
            travelDuration: travel,
            approachStartX: approachStartX,
            approachEndX: approachEndX
        )
        ball.position = CGPoint(x: approachStartX, y: size.height * Tunables.spawnLineYRatio)
        ball.zPosition = 30
        ball.setScale(Tunables.ballDepthScaleFar)
        addChild(ball)
        activeBalls.append(ball)

        // Anticipation pulse on the strike line, peaking at arrival time.
        let trackTime = CACurrentMediaTime() - startTime
        strikePulse?.schedule(arrivalTime: arrivalTime, currentTrackTime: trackTime)
    }

    // MARK: - Input — single-finger aim (pan)

    /// Drag and release: **direction** picks where the ball goes; **timing**
    /// vs. arrival sets hit quality. Horizontal sign is kept as a coarse
    /// `Lane` for audio pan / combo-break SFX only.
    ///
    /// Commit happens the first frame the drag distance crosses
    /// `Tunables.swingMinDistance` during `.changed` — NOT on finger-lift.
    /// Finger-lift commit adds ~50–150 ms of input latency vs. the ball,
    /// which is the dominant per-tap feel problem in a rhythm-swipe game.
    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let view = self.view else { return }
        let viewPoint = pan.location(in: view)
        let scenePoint = convertPoint(fromView: viewPoint)

        switch pan.state {
        case .began:
            swingOriginScene = scenePoint
            swingCommitted = false
            installSwingTrail(at: scenePoint)
            // Fire touch-down haptic on the same vsync the finger lands —
            // the swing has a tactile *start*, not just a tactile end.
            HapticManager.shared.playTouchDown()
            #if DEBUG
            let id = Self.inputSignposter.makeSignpostID()
            inputSignpostID = id
            inputSignpostState = Self.inputSignposter.beginInterval("swing", id: id)
            #endif

        case .changed:
            guard let origin = swingOriginScene else { return }
            updateSwingTrail(from: origin, to: scenePoint)
            if swingCommitted { return }

            let dx = scenePoint.x - origin.x
            let dy = scenePoint.y - origin.y
            let distance = hypot(dx, dy)
            guard distance >= Tunables.live.swingMinDistance else { return }

            // Threshold crossed — commit the swing on THIS vsync.
            swingCommitted = true
            let v = pan.velocity(in: view)
            let speed = hypot(v.x, v.y)
            let lane: Lane = dx < 0 ? .left : .right
            resolveSwing(lane: lane, swingSpeed: speed, dx: dx, dy: dy)

            #if DEBUG
            if let state = inputSignpostState {
                Self.inputSignposter.endInterval("swing", state, "committed")
                inputSignpostState = nil
                inputSignpostID = nil
            }
            #endif

        case .ended:
            // Swing already resolved on threshold-crossing; finger-lift is
            // just cleanup.
            swingOriginScene = nil
            swingCommitted = false
            fadeSwingTrail()
            #if DEBUG
            if let state = inputSignpostState {
                // No commit fired — close the signpost so Instruments doesn't
                // report an open-ended interval.
                Self.inputSignposter.endInterval("swing", state, "uncommitted")
                inputSignpostState = nil
                inputSignpostID = nil
            }
            #endif

        case .cancelled, .failed:
            swingOriginScene = nil
            swingCommitted = false
            fadeSwingTrail()
            #if DEBUG
            if let state = inputSignpostState {
                Self.inputSignposter.endInterval("swing", state, "cancelled")
                inputSignpostState = nil
                inputSignpostID = nil
            }
            #endif

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

    private func resolveSwing(lane: Lane, swingSpeed: CGFloat, dx: CGFloat, dy: CGFloat) {
        guard !isDying, !isCountingDown, !sessionEnded else { return }

        guard let target = nearestIncomingBall() else {
            registerMiss(lane: lane, signedDelta: nil)
            return
        }
        let trackTime = CACurrentMediaTime() - startTime
        let timingScalar = sessionDifficultyScalars(trackTime: trackTime).timing
        let arrivalTime = target.spawnTime + target.travelDuration
        let signedDelta = trackTime - arrivalTime    // negative = early, positive = late
        let delta = abs(signedDelta)

        var quality = HitQuality.grade(absDelta: delta, windowScalar: timingScalar)

        if quality == .great,
           swingSpeed >= Tunables.swingFastVelocity,
           delta <= HitQuality.perfect.windowSeconds * timingScalar * 1.25
        {
            quality = .perfect
        }

        if quality == .miss {
            registerMiss(lane: lane, signedDelta: signedDelta)
            return
        }
        registerTennisHit(ball: target, quality: quality, lane: lane, dx: dx, dy: dy, swingSpeed: swingSpeed)
    }

    private func nearestIncomingBall() -> BallNode? {
        let strikeY = size.height * Tunables.strikeLineYRatio
        return activeBalls
            .filter { !$0.isLaunched }
            .min { abs($0.position.y - strikeY) < abs($1.position.y - strikeY) }
    }

    // MARK: - Hit / miss

    private func registerTennisHit(
        ball: BallNode,
        quality: HitQuality,
        lane: Lane,
        dx: CGFloat,
        dy: CGFloat,
        swingSpeed: CGFloat
    ) {
        let vecLen = hypot(dx, dy)
        guard vecLen > 2 else {
            // Degenerate swing vector; no usable timing delta.
            registerMiss(lane: lane, signedDelta: nil)
            return
        }
        // UIKit/SpriteKit y grows downward; physics +Y is toward the opponent (up-screen).
        var aimX = dx / vecLen
        var aimY = -dy / vecLen

        // Flat horizontal swipes still need a touch of lift; otherwise every
        // return dies into the net. Angle-driven shots keep most of the vector.
        let minUp: CGFloat = 0.18
        if aimY < minUp {
            aimY = minUp
            let norm = hypot(aimX, aimY)
            aimX /= norm
            aimY /= norm
        }

        let surface = CourtVenue.current
        ball.attachPhysicsAndLaunch(surface: surface)

        let qualityMul: CGFloat
        switch quality {
        case .perfect: qualityMul = 1.28
        case .great:   qualityMul = 1.12
        case .good:    qualityMul = 1.0
        case .miss:    qualityMul = 0.9
        }
        let speedBoost = min(1.42, 0.84 + swingSpeed / 2800)
        let mag = Tunables.tennisImpulseBase * qualityMul * speedBoost

        let impulseX = aimX * mag
        let impulseY = aimY * mag + Tunables.tennisImpulseUpBias * qualityMul * 0.12
        ball.physicsBody?.applyImpulse(CGVector(dx: impulseX, dy: impulseY))

        flashRacket(quality: quality)

        combo += 1
        maxCombo = max(maxCombo, combo)
        let scoreAwarded = quality.baseScore * max(1, combo / 5)
        let previousScore = score
        score += scoreAwarded
        switch quality {
        case .perfect: perfectHits += 1
        case .great:   greatHits   += 1
        case .good:    goodHits    += 1
        case .miss:    break
        }
        recordInCurrentSegment(quality: quality)
        updateHUD(from: previousScore, to: score)
        emitScorePopup(amount: scoreAwarded, quality: quality, at: ball.position)

        // Frame-stop scales lightly with combo tier so streak hits feel a
        // bit weightier without ever blocking a 16th-note flow. The tier-0
        // values are the GDD spec (6 / 3 / 0 ms); a tier-4 perfect lands
        // at ~10 ms.
        let baseFreezeMs: Double
        switch quality {
        case .perfect: baseFreezeMs = Tunables.live.frameStopPerfectMs
        case .great:   baseFreezeMs = Tunables.live.frameStopGreatMs
        case .good:    baseFreezeMs = Tunables.frameStopGoodMs
        case .miss:    baseFreezeMs = Tunables.frameStopMissMs
        }
        let tier = Tunables.comboTier(forCombo: combo)
        let freezeMs = baseFreezeMs * Double(Tunables.tierJuiceMultiplier(tier: tier))
        if freezeMs > 0 {
            frameStopUntil = CACurrentMediaTime() + freezeMs.seconds
        }

        GameEventBus.shared.publish(
            .hit(quality: quality, lane: lane, position: ball.position, combo: combo)
        )

        let newTier = comboTier(for: combo)
        if newTier != lastComboTier {
            lastComboTier = newTier
            GameEventBus.shared.publish(.comboTier(newTier))
        }

        if quality == .perfect {
            courtBackdrop?.pulseHorizon(intensity: 1.0)
        }
    }

    private func flashRacket(quality: HitQuality) {
        guard let racket = racketNode else { return }
        let peak: CGFloat
        let durationUp: TimeInterval
        let durationDown: TimeInterval
        switch quality {
        case .perfect:
            peak = 0.45
            durationUp = 0.04
            durationDown = 0.28
        case .great:
            peak = 0.28
            durationUp = 0.05
            durationDown = 0.22
        case .good:
            peak = 0.18
            durationUp = 0.06
            durationDown = 0.18
        case .miss:
            return
        }
        racket.removeAllActions()
        racket.alpha = 1
        racket.run(.sequence([
            .group([
                .fadeAlpha(to: peak, duration: durationUp),
                .scale(to: 1.06, duration: durationUp)
            ]),
            .group([
                .fadeAlpha(to: 1.0, duration: durationDown),
                .scale(to: 1.0, duration: durationDown)
            ])
        ]))
    }

    /// `signedDelta` is `trackTime - arrivalTime`. Negative = the player
    /// swung early, positive = the player swung late. `nil` means there
    /// was no ball to grade against (pure airswing).
    private func registerMiss(lane: Lane, signedDelta: Double?) {
        totalMisses += 1
        recordInCurrentSegment(quality: .miss)
        let previous = combo

        // Near-miss visual cue: if the swing landed within 1.5× the .good
        // window, draw a faint timing ghost so the player learns *how*
        // they were off, not just *that* they were off.
        if let d = signedDelta,
           abs(d) <= HitQuality.good.windowSeconds * 1.5 {
            emitTimingGhost(signedDelta: d)
        }

        if combo > 0 {
            // The Flappy moment.
            triggerDeathSequence(previousCombo: previous)
        } else {
            // Soft miss — no combo to break, just a little buzz.
            GameEventBus.shared.publish(.miss(lane: lane))
        }
    }

    /// Place a small "ghost" mark on the strike line indicating *which side*
    /// of the timing window the player landed on:
    ///
    /// - `signedDelta < 0` (swung early) — mark above the line.
    /// - `signedDelta > 0` (swung late)  — mark below the line.
    ///
    /// Warm gray so it never competes with the cyan/magenta/yellow palette
    /// of an actual graded hit.
    private func emitTimingGhost(signedDelta: Double) {
        let strikeY = size.height * Tunables.strikeLineYRatio
        let offset: CGFloat = 14
        let y = signedDelta < 0 ? strikeY + offset : strikeY - offset
        let mark = SKShapeNode(rectOf: CGSize(width: 22, height: 4), cornerRadius: 2)
        mark.position = CGPoint(x: size.width / 2, y: y)
        mark.fillColor = UIColor(white: 0.85, alpha: 1)
        mark.strokeColor = .clear
        mark.glowWidth = 6
        mark.zPosition = 88
        mark.alpha = 0
        addChild(mark)

        let fadeIn  = SKAction.fadeAlpha(to: 0.55, duration: 0.04)
        let dwell   = SKAction.wait(forDuration: 0.20)
        let fadeOut = SKAction.fadeAlpha(to: 0.0,  duration: 0.10)
        mark.run(.sequence([fadeIn, dwell, fadeOut, .removeFromParent()]))
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

        // Kill any pending anticipation pulses; the player isn't getting
        // those balls.
        strikePulse?.cancelAll()

        let now = CACurrentMediaTime()
        frameStopUntil = now + Tunables.live.frameStopDeathMs.seconds
        // Cooldown deadline checked in `update(_:)`; pause-safe.
        dyingUntil     = now + Tunables.live.frameStopDeathMs.seconds + 0.15

        GameEventBus.shared.publish(.comboBreak(previous: previousCombo))

        // Clear in-flight balls with a shatter — the field reads as
        // "you broke this", not "balls disappeared." The death freeze
        // pauses the scene; once it lifts, the shatter actions play.
        for ball in activeBalls {
            shatter(ball: ball)
        }
        activeBalls.removeAll()
    }

    /// Replace a ball with a quick radial shape-shatter at the ball's
    /// position. Cheap (8 shape nodes) and shape-distinct from the hit
    /// burst so the player visually parses it as "destroyed" rather
    /// than "scored".
    private func shatter(ball: BallNode) {
        let center = ball.position
        let parent = ball.parent ?? self
        let shrapnelCount = 8
        let baseRadius = Tunables.ballRadiusPoints * 0.45

        for i in 0..<shrapnelCount {
            let angle = (CGFloat(i) / CGFloat(shrapnelCount)) * 2 * .pi
            let frag = SKShapeNode(circleOfRadius: baseRadius)
            frag.fillColor = UIColor(red: 1, green: 0.25, blue: 0.35, alpha: 1)
            frag.strokeColor = .clear
            frag.glowWidth = 4
            frag.position = center
            frag.zPosition = ball.zPosition
            parent.addChild(frag)

            let distance: CGFloat = 70 + CGFloat.random(in: -10...18)
            let target = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )
            let move = SKAction.move(to: target, duration: 0.32)
            move.timingMode = .easeOut
            let shrink = SKAction.scale(to: 0.1, duration: 0.32)
            let fade = SKAction.fadeOut(withDuration: 0.32)
            frag.run(.sequence([.group([move, shrink, fade]), .removeFromParent()]))
        }
        ball.removeFromParent()
    }

    // MARK: - Public score accessors (for SwiftUI overlays)

    var currentScore: Int { score }
    var currentCombo: Int { combo }
    var currentMaxCombo: Int { maxCombo }
    var sessionIsOver: Bool { sessionEnded }

    /// Snap the HUD to a known score immediately. Used outside of hit
    /// resolution (death sequence, reset).
    private func updateHUD() {
        scoreLabel?.text = "\(score)"
        if combo > 1 {
            comboLabel?.text = "x\(combo)"
        } else {
            comboLabel?.text = ""
        }
        punchHUD()
    }

    /// Animate the score label from `from` to `to` so the score visibly
    /// *flows in* over `Tunables.scoreTweenDurationMs`. Each hit therefore
    /// reads as "this many points landed in the HUD" instead of just
    /// replacing the digits.
    private func updateHUD(from: Int, to: Int) {
        if let label = scoreLabel, from != to {
            label.removeAction(forKey: "scoreTicker")
            let dur = Tunables.scoreTweenDurationMs.seconds
            let tick = SKAction.customAction(withDuration: dur) { _, elapsed in
                let p = min(1, Double(elapsed) / dur)
                let eased = 1 - pow(1 - p, 3)   // easeOutCubic
                let shown = from + Int((Double(to - from) * eased).rounded())
                label.text = "\(shown)"
            }
            let settle = SKAction.run { label.text = "\(to)" }
            label.run(.sequence([tick, settle]), withKey: "scoreTicker")
        } else {
            scoreLabel?.text = "\(to)"
        }
        if combo > 1 {
            comboLabel?.text = "x\(combo)"
        } else {
            comboLabel?.text = ""
        }
        punchHUD()
    }

    /// Floating "+N" popup at the hit point. Rises 60 pt, fades over the
    /// score-tween duration. Coloured to match the burst color so the
    /// player visually links the popup to the strike.
    private func emitScorePopup(amount: Int, quality: HitQuality, at point: CGPoint) {
        guard amount > 0 else { return }
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "+\(amount)"
        label.fontSize = quality == .perfect ? 30 : 22
        label.fontColor = popupColor(for: quality)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 95
        label.position = point
        label.alpha = 0
        addChild(label)

        let dur = Tunables.scoreTweenDurationMs.seconds
        let rise = SKAction.moveBy(x: 0, y: 60, duration: dur)
        rise.timingMode = .easeOut
        let fadeIn  = SKAction.fadeAlpha(to: 1.0, duration: dur * 0.18)
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: dur * 0.62)
        let kick    = SKAction.sequence([
            .scale(to: quality == .perfect ? 1.25 : 1.10, duration: dur * 0.18),
            .scale(to: 1.0, duration: dur * 0.32)
        ])
        label.run(.group([rise, .sequence([fadeIn, fadeOut]), kick]))
        label.run(.sequence([.wait(forDuration: dur * 1.05), .removeFromParent()]))
    }

    private func popupColor(for quality: HitQuality) -> UIColor {
        switch quality {
        case .perfect: return UIColor(red: 0,   green: 1,   blue: 1,   alpha: 1)
        case .great:   return UIColor(red: 0.9, green: 0.4, blue: 1,   alpha: 1)
        case .good:    return UIColor(red: 1,   green: 1,   blue: 0.55,alpha: 1)
        case .miss:    return .gray
        }
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

    private func comboTier(for combo: Int) -> Int {
        Tunables.comboTier(forCombo: combo)
    }

    // MARK: - Teardown

    override func willMove(from view: SKView) {
        if let pan = swingPanRecognizer {
            view.removeGestureRecognizer(pan)
            swingPanRecognizer = nil
        }
        cameraNode?.removeAction(forKey: "shake")
        layoutCamera()

        if !sessionEnded {
            sessionEnded = true
            GameEventBus.shared.publish(.sessionEnd(buildResult()))
        }
    }
}

// MARK: - TennisBallFeed

/// Schedules incoming balls — no rhythm beatmap — with feed intervals that tighten over the session.
final class TennisBallFeed {

    var travelSeconds: Double

    private var nextArrivalTime: Double
    private let leadInSeconds: Double
    private let sessionDurationSeconds: Double
    private let sink: (Double) -> Void

    init(
        leadInSeconds: Double = Tunables.tennisFeedLeadInSeconds,
        travelSeconds: Double,
        sessionDurationSeconds: Double,
        sink: @escaping (Double) -> Void
    ) {
        self.travelSeconds = travelSeconds
        self.leadInSeconds = leadInSeconds
        self.sessionDurationSeconds = sessionDurationSeconds
        self.nextArrivalTime = leadInSeconds
        self.sink = sink
    }

    func tick(trackTime: Double) {
        let spawnHorizon = trackTime + travelSeconds
        while nextArrivalTime <= spawnHorizon {
            sink(nextArrivalTime)
            nextArrivalTime += interval(forTrackTime: trackTime)
        }
    }

    private func interval(forTrackTime trackTime: Double) -> Double {
        let denom = max(sessionDurationSeconds, 1)
        let p = min(1, max(0, trackTime / denom))
        let base = Tunables.tennisFeedBaseInterval
        let lo = Tunables.tennisFeedMinInterval
        let t = base - (base - lo) * pow(p, 0.82)
        return max(lo, t)
    }

    func reset() {
        nextArrivalTime = leadInSeconds
    }
}

// MARK: - BallNode

final class BallNode: SKShapeNode {
    let spawnTime: Double
    let travelDuration: TimeInterval
    /// Perspective approach: interpolate from far (wide) toward strike (near).
    let approachStartX: CGFloat
    let approachEndX: CGFloat
    private(set) var isLaunched = false

    init(
        spawnTime: Double,
        travelDuration: TimeInterval,
        approachStartX: CGFloat,
        approachEndX: CGFloat
    ) {
        self.spawnTime = spawnTime
        self.travelDuration = travelDuration
        self.approachStartX = approachStartX
        self.approachEndX = approachEndX
        super.init()
        let r = Tunables.ballRadiusPoints
        path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        fillColor = UIColor(red: 0.94, green: 0.88, blue: 0.22, alpha: 1)
        strokeColor = UIColor(white: 0.25, alpha: 1)
        lineWidth = 1.5
        glowWidth = 8
    }

    /// Switches from kinematic approach to SpriteKit dynamics; surface tunes bounce/drag.
    func attachPhysicsAndLaunch(surface: CourtVenue) {
        guard !isLaunched else { return }
        isLaunched = true
        let r = Tunables.ballRadiusPoints
        physicsBody = SKPhysicsBody(circleOfRadius: r)
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = true
        physicsBody?.allowsRotation = true
        physicsBody?.mass = 0.058
        physicsBody?.restitution = surface.ballRestitution
        physicsBody?.friction = 0.22
        physicsBody?.linearDamping = surface.ballLinearDamping
        physicsBody?.angularDamping = 0.45
        physicsBody?.usesPreciseCollisionDetection = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

// MARK: - Gesture delegate

extension GameScene: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
