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
    private enum WallMissReason {
        case generic
        case side
        case early
        case late
        case reach
    }

    private enum SessionMode {
        case wallRally
        case phasedMatch
    }

    enum ShotShape: String {
        case drive
        case topspin
        case skid
        case floater
    }

    enum SwingIntent {
        case drive
        case topspin
        case slice
    }

    enum StrokeSide {
        case forehand
        case backhand
    }

    private enum PlayerPoseState {
        case ready
        case forehandClean
        case backhandClean
        case stretchForehand
        case stretchBackhand
        case defensiveBlock
        case recovery
    }

    private struct PlayerPoseTargets {
        let torsoRotation: CGFloat
        let headRotation: CGFloat
        let headX: CGFloat
        let leadLegRotation: CGFloat
        let trailLegRotation: CGFloat
        let leadLegX: CGFloat
        let trailLegX: CGFloat
        let leadArmRotation: CGFloat
        let trailArmRotation: CGFloat
        let leadArmX: CGFloat
        let leadArmY: CGFloat
        let trailArmX: CGFloat
        let trailArmY: CGFloat
        let racketHandleRotation: CGFloat
        let racketHeadRotation: CGFloat
        let racketHandleX: CGFloat
        let racketHandleY: CGFloat
        let racketHeadX: CGFloat
        let racketHeadY: CGFloat
        let shadowXScale: CGFloat
        let shadowYScale: CGFloat
        let shadowAlpha: CGFloat
        /// Additional zRotation applied to the racket head for wrist/face angle.
        /// Positive = open face (slice), negative = closed face (topspin).
        let racketFaceAngle: CGFloat

        init(torsoRotation: CGFloat = 0, headRotation: CGFloat = 0, headX: CGFloat = 0,
             leadLegRotation: CGFloat = 0, trailLegRotation: CGFloat = 0,
             leadLegX: CGFloat = 0, trailLegX: CGFloat = 0,
             leadArmRotation: CGFloat = 0, trailArmRotation: CGFloat = 0,
             leadArmX: CGFloat = 0, leadArmY: CGFloat = 0,
             trailArmX: CGFloat = 0, trailArmY: CGFloat = 0,
             racketHandleRotation: CGFloat = 0, racketHeadRotation: CGFloat = 0,
             racketHandleX: CGFloat = 0, racketHandleY: CGFloat = 0,
             racketHeadX: CGFloat = 0, racketHeadY: CGFloat = 0,
             shadowXScale: CGFloat = 1, shadowYScale: CGFloat = 1, shadowAlpha: CGFloat = 0.3,
             racketFaceAngle: CGFloat = 0) {
            self.torsoRotation = torsoRotation
            self.headRotation = headRotation
            self.headX = headX
            self.leadLegRotation = leadLegRotation
            self.trailLegRotation = trailLegRotation
            self.leadLegX = leadLegX
            self.trailLegX = trailLegX
            self.leadArmRotation = leadArmRotation
            self.trailArmRotation = trailArmRotation
            self.leadArmX = leadArmX
            self.leadArmY = leadArmY
            self.trailArmX = trailArmX
            self.trailArmY = trailArmY
            self.racketHandleRotation = racketHandleRotation
            self.racketHeadRotation = racketHeadRotation
            self.racketHandleX = racketHandleX
            self.racketHandleY = racketHandleY
            self.racketHeadX = racketHeadX
            self.racketHeadY = racketHeadY
            self.shadowXScale = shadowXScale
            self.shadowYScale = shadowYScale
            self.shadowAlpha = shadowAlpha
            self.racketFaceAngle = racketFaceAngle
        }
    }

    // MARK: - Configuration

    /// How long a single rally session lasts before `sessionEnd` is fired.
    /// The procedural beatmap is generated to match.
    var sessionDurationSeconds: Double = 180
    var racketTuning: RacketGameplayTuning = .balanced
    var avatarAppearance: RallyAvatarAppearance?
    var dominantHand: GamePreferences.DominantHand = .right {
        didSet { refreshHandednessIfNeeded() }
    }
    var showCoachingCues = true
    var matchPace: GamePreferences.MatchPace = .calm {
        didSet { applyMatchPaceIfNeeded() }
    }
    var autoPlayEnabled = false
    private let sessionMode: SessionMode = .wallRally

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
    private var cleanReturnPickups: Int = 0
    private var changeupWinners: Int = 0
    private var pressureHolds: Int = 0
    private var pressureExchangeStreak: Int = 0
    private var activeBalls: [BallNode] = []
    private var activeExchanges: [RallyContinuousBallExchange] = []
    private var startTime: TimeInterval = 0
    private var currentTimeSnapshot: TimeInterval = 0
    private var currentTrackTime: TimeInterval = 0
    private var frameStopUntil: TimeInterval = 0
    private var pendingWallSpawnToken: UUID?
    private var isDying = false
    private var sessionEnded = false
    private var betweenPointLiftUntil: TimeInterval = 0
    private var recentContactQuality: HitQuality?
    private var recentContactUntil: TimeInterval = 0
    private var recentHUDImpactUntil: TimeInterval = 0
    private var lastAutoPlaySpawnTime: Double = -1

    /// Set to `true` for the first `countdownSeconds` after the scene
    /// appears. Spawner is paused and input is ignored during this window
    /// so the player has time to settle. We don't gate gestures with a
    /// flag inside `handlePan`; we simply don't start the spawner clock
    /// until the countdown is done.
    private var isCountingDown = true

    private var spawner: RhythmSpawner?
    private var flow: MatchFlowCoordinator?

    private var cameraNode: SKCameraNode!
    private var hudTopPlate: SKShapeNode!
    private var hudCaptionLabel: SKLabelNode!
    private var hudPhaseLabel: SKLabelNode!
    private var hudPhaseValueLabel: SKLabelNode!
    private var hudMaxLabel: SKLabelNode!
    private var hudMaxValueLabel: SKLabelNode!
    private var instructionPlate: SKShapeNode!
    private var scoreLabel: SKLabelNode!
    private var comboLabel: SKLabelNode!
    private var timeLabel: SKLabelNode!
    private var phaseBannerLabel: SKLabelNode!
    private var instructionLabel: SKLabelNode!
    private var strikeLine: SKShapeNode!
    private var strikeLinePulse: StrikeLinePulse!
    private var strikeHalo: SKShapeNode!
    private var contactTimingRing: SKShapeNode!
    private var leftStrikeGate: SKShapeNode!
    private var rightStrikeGate: SKShapeNode!
    private var leftContactPocket: SKShapeNode!
    private var rightContactPocket: SKShapeNode!
    private var leftStrokeReadLabel: SKLabelNode!
    private var rightStrokeReadLabel: SKLabelNode!
    private var focusStrokeReadLabel: SKLabelNode!
    private var wallAnticipationBar: SKShapeNode!
    private var wallAnticipationFill: SKShapeNode!
    private var wallReboundBand: SKShapeNode!
    private var wallSurfaceNode: SKShapeNode!
    private var wallTargetNode: SKShapeNode!
    private var wallKickShadowNode: SKShapeNode!
    private var leftLaneGlow: SKShapeNode!
    private var rightLaneGlow: SKShapeNode!
    private var background: TennisCourtBackdrop!
    private var playerRoot: SKNode!
    private var playerTorso: SKShapeNode!
    private var playerNeck: SKShapeNode!
    private var playerHead: SKShapeNode!
    private var playerBackHair: SKShapeNode!
    private var playerHair: SKShapeNode!
    private var playerLeftEye: SKShapeNode!
    private var playerRightEye: SKShapeNode!
    private var playerLeftBrow: SKShapeNode!
    private var playerRightBrow: SKShapeNode!
    private var playerNose: SKShapeNode!
    private var playerLeftLens: SKShapeNode!
    private var playerRightLens: SKShapeNode!
    private var playerGlassesBridge: SKShapeNode!
    private var playerLeftTemple: SKShapeNode!
    private var playerRightTemple: SKShapeNode!
    private var playerMouth: SKShapeNode!
    private var courtAvatarLayout: RallyAvatarRebuildDefaults.CourtLayout?
    private var courtAvatarScale: CGFloat = 0.90
    private var playerPelvis: SKShapeNode!
    private var playerLeadLeg: SKShapeNode!
    private var playerTrailLeg: SKShapeNode!
    private var playerLeadShoe: SKShapeNode!
    private var playerTrailShoe: SKShapeNode!
    private var playerLeadArm: SKShapeNode!
    private var playerTrailArm: SKShapeNode!
    private var playerLeadSleeve: SKShapeNode!
    private var playerTrailSleeve: SKShapeNode!
    private var playerLeadHand: SKShapeNode!
    private var playerTrailHand: SKShapeNode!
    private var playerRacketHandle: SKShapeNode!
    private var playerRacketHead: SKShapeNode!
    private var playerRacketStrings: [SKShapeNode] = []
    private var playerShadow: SKShapeNode!
    private var playerStanceGlow: SKShapeNode!
    private var playerRacketBaseColor: UIColor = UIColor(white: 0.78, alpha: 1)
    private var playerRacketAccentColor: UIColor = UIColor(red: 0, green: 0.9, blue: 1, alpha: 1)
    // Opponent avatar (far end)
    private var opponentRoot: SKNode?
    private var opponentRacketHead: SKShapeNode?
    private var opponentHitTime: TimeInterval = 0
    private var currentBPM: Double = 120
    private var currentTravelSeconds: Double = Tunables.ballTravelSeconds
    private var lastBeatTime: TimeInterval = 0
    private var sessionStartWallTime: TimeInterval = 0
    private var spawnedBallCount: Int = 0
    private var wallNextLane: Lane = .right
    #if DEBUG
    private var hasLoggedAvatarAudit = false
    #endif

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
    private var swingCurrentScene: CGPoint?
    private var swingTrailNode: SKShapeNode?
    private var swingTrailGlowNode: SKShapeNode?
    private var swingTrailTipNode: SKShapeNode?
    private weak var swingPanRecognizer: UIPanGestureRecognizer?
    private var swingVisualLane: Lane = .right
    private var swingVisualIntent: SwingIntent = .drive
    private var swingVisualImpactUntil: TimeInterval = 0
    private var swingVisualReach: CGFloat = 0
    private var contactFlashUntil: TimeInterval = 0
    private var hitStopUntil: TimeInterval = 0
    private var recentContactLane: Lane?

    // MARK: - TopSpin swing body mechanics state
    /// Velocity accumulated during the torso load phase; released as uncoil on contact.
    private var torsoVelocity: CGFloat = 0
    /// Current wrist-snap overshoot offset (points along swing axis), decays exponentially.
    private var wristSnapOffset: CGFloat = 0
    /// Timestamp when the wrist snap was last applied.
    private var wristSnapAppliedAt: TimeInterval = 0
    /// Last resolved ball position at racket contact, stored in player-local coordinates.
    private var lastRacketContactTarget: CGPoint?

    // MARK: - Footwork state
    /// Timestamp until which the split-step animation is active.
    private var splitStepUntil: TimeInterval = 0
    /// Previous frame's approachProgress — used to detect rising edge for split-step trigger.
    private var prevApproachProgress: CGFloat = 0
    /// Weight side: +1 = forehand (left foot planted), -1 = backhand, 0 = neutral.
    private var weightSide: CGFloat = 0
    /// Timestamp of last contact, used to drive foot recovery shuffle.
    private var footContactTime: TimeInterval = 0
    private var recoveryTrackUntil: TimeInterval = 0
    private var recoveryLane: Lane?
    private var recoverySeverity: CGFloat = 0

    private var cameraHomePosition: CGPoint {
        CGPoint(x: size.width / 2, y: size.height * (0.5 + Tunables.gameplayCameraYOffsetRatio))
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        anchorPoint = CGPoint(x: 0, y: 0)

        setupCamera()
        setupBackground()
        setupLaneGlow()
        setupStrikeLine()
        setupOpponentAvatar()
        setupCourtAvatar()
        setupHUD()
        didChangeSize(size)
        #if DEBUG
        runDebugAvatarAuditIfNeeded()
        #endif
        setupSwipeRecognizers(in: view)

        ParticleManager.shared.attach(scene: self, shakeTarget: cameraNode)

        if sessionMode == .phasedMatch {
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
            let initialProfile = coordinator.currentProfile()
            currentBPM = initialProfile.bpm
            currentTravelSeconds = Tunables.ballTravelSeconds * initialProfile.travelScalar * matchPace.travelScalar

            spawner = RhythmSpawner(
                flow: coordinator,
                travelSeconds: currentTravelSeconds
            ) { [weak self] note in
                self?.spawnBall(note)
            }
        } else {
            flow = nil
            spawner = nil
            currentBPM = wallTempoBPM(for: matchPace)
            currentTravelSeconds = Tunables.ballTravelSeconds * 1.08 * matchPace.travelScalar
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
        wallNextLane = dominantHand == .right ? .right : .left
        GameEventBus.shared.publish(.sessionStart)
        runCountdown()
    }

    func applyAvatarAppearance(_ appearance: RallyAvatarAppearance) {
        avatarAppearance = appearance
        guard playerRoot != nil else { return }
        playerRoot.removeFromParent()
        setupCourtAvatar()
    }

    private var usesMinimalWallHUD: Bool {
        sessionMode == .wallRally
    }

    // MARK: - Countdown

    /// Shows a 3-2-1-GO sequence above the strike line. While it's running
    /// the spawner is paused so the player has time to settle. Total
    /// duration: ~1.6s. We re-anchor `startTime` when it ends so the
    /// session timer always begins at 0:0X from the player's point of view.
    private func runCountdown() {
        isCountingDown = true
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.fontSize = 104
        label.fontColor = UIColor(red: 0.82, green: 0.96, blue: 1.0, alpha: 1)
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.54)
        label.zPosition = 102
        label.alpha = 0
        addChild(label)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subtitle.text = sessionMode == .wallRally ? "READY" : "MATCH START"
        subtitle.fontSize = 18
        subtitle.fontColor = UIColor(white: 1.0, alpha: 0.68)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.61)
        subtitle.zPosition = 101
        subtitle.alpha = 0
        addChild(subtitle)

        let ring = SKShapeNode(circleOfRadius: 92)
        ring.strokeColor = UIColor(white: 1.0, alpha: 0.16)
        ring.lineWidth = 2
        ring.glowWidth = 8
        ring.position = CGPoint(x: size.width / 2, y: size.height * 0.54)
        ring.zPosition = 100
        ring.alpha = 0
        addChild(ring)

        let steps: [(String, UIColor)] = [
            ("3", UIColor(red: 0.33, green: 0.88, blue: 0.95, alpha: 1)),
            ("2", UIColor(red: 0.78, green: 0.88, blue: 0.44, alpha: 1)),
            ("1", UIColor(red: 0.87, green: 0.71, blue: 0.43, alpha: 1)),
            ("GO", UIColor(red: 0.80, green: 0.33, blue: 0.55, alpha: 1))
        ]
        let perStep: TimeInterval = 0.4
        var seq: [SKAction] = []
        for (text, color) in steps {
            seq.append(.run { [weak label, weak subtitle, weak ring] in
                label?.text = text
                label?.fontColor = color
                label?.setScale(text == "GO" ? 0.72 : 0.64)
                subtitle?.alpha = 0.72
                ring?.alpha = 0.85
                ring?.strokeColor = color.withAlphaComponent(0.34)
                ring?.setScale(0.84)
            })
            seq.append(.group([
                .fadeAlpha(to: 1.0, duration: 0.08),
                .scale(to: 1.0, duration: 0.18),
                .run { [weak ring] in
                    ring?.run(.sequence([
                        .group([
                            .fadeAlpha(to: 1.0, duration: 0.1),
                            .scale(to: 1.02, duration: 0.18)
                        ]),
                        .fadeAlpha(to: 0.0, duration: 0.18)
                    ]))
                }
            ]))
            seq.append(.fadeAlpha(to: 0.0, duration: perStep - 0.18))
        }
        seq.append(.run { [weak self, weak label, weak subtitle, weak ring] in
            label?.removeFromParent()
            subtitle?.removeFromParent()
            ring?.removeFromParent()
            guard let self = self else { return }
            self.isCountingDown = false
            // Re-anchor trackTime so the timer starts fresh.
            self.startTime = CACurrentMediaTime()
            self.lastBeatTime = CACurrentMediaTime()
            CameraShake.nudge(self.cameraNode, dx: 0, dy: -8, outMs: 90, backMs: 220)
            self.background?.setMomentum(
                tier: 0,
                phase: self.flow?.currentPhase.rawValue.lowercased() ?? "warm-up",
                breaking: false
            )
            self.showInstruction(
                self.sessionMode == .wallRally
                    ? ""
                    : "Meet the ball and release through contact.",
                hold: Tunables.openingHintSeconds * 0.38
            )
            if self.sessionMode == .wallRally {
                self.scheduleWallBall(after: 0.68)
            }
        })
        label.run(.sequence(seq))
    }

    private func setupCamera() {
        let cam = SKCameraNode()
        cam.position = cameraHomePosition
        addChild(cam)
        camera = cam
        cameraNode = cam
        // Keep the camera at scene-center so position offsets from
        // CameraShake read as "screen shake" rather than "scroll".
        cam.position = cameraHomePosition
    }

    override func didChangeSize(_ oldSize: CGSize) {
        // SKCameraNode's position is in scene coordinates. With anchorPoint
        // (0,0), camera at (size.width/2, size.height/2) shows centered.
        anchorPoint = CGPoint(x: 0, y: 0)
        cameraNode?.removeAction(forKey: "shake")
        cameraNode?.removeAction(forKey: "nudge")
        cameraNode?.removeAction(forKey: "drift")
        cameraNode?.position = cameraHomePosition
        background?.resize(to: size, strikeYRatio: Tunables.strikeLineYRatio)

        let strikeY = size.height * Tunables.strikeLineYRatio
        let wallY = size.height * Tunables.wallSurfaceYRatio
        let glowSize = CGSize(width: size.width * 0.30, height: size.height * 0.24)
        let glowRect = CGRect(
            x: -glowSize.width / 2,
            y: -glowSize.height / 2,
            width: glowSize.width,
            height: glowSize.height
        )
        leftLaneGlow?.path = CGPath(ellipseIn: glowRect, transform: nil)
        leftLaneGlow?.position = CGPoint(x: size.width * 0.22, y: wallY - size.height * 0.06)
        rightLaneGlow?.path = CGPath(ellipseIn: glowRect, transform: nil)
        rightLaneGlow?.position = CGPoint(x: size.width * 0.78, y: wallY - size.height * 0.06)

        // Re-layout strike line if it exists.
        if let line = strikeLine {
            line.position = CGPoint(x: size.width / 2, y: strikeY)
            line.path = CGPath(
                rect: CGRect(x: -size.width / 2, y: -1, width: size.width, height: 2),
                transform: nil
            )
        }
        strikeHalo?.position = CGPoint(x: size.width / 2, y: strikeY)
        strikeLinePulse?.resize(toWidth: size.width)
        strikeLinePulse?.position = CGPoint(x: size.width / 2, y: strikeY)
        leftStrikeGate?.position = CGPoint(x: size.width * 0.28, y: strikeY)
        rightStrikeGate?.position = CGPoint(x: size.width * 0.72, y: strikeY)
        leftContactPocket?.position = racketContactPoint(for: .left)
        rightContactPocket?.position = racketContactPoint(for: .right)
        leftStrokeReadLabel?.position = CGPoint(
            x: racketContactPoint(for: .left).x,
            y: racketContactPoint(for: .left).y + Tunables.wallReadLabelLift
        )
        rightStrokeReadLabel?.position = CGPoint(
            x: racketContactPoint(for: .right).x,
            y: racketContactPoint(for: .right).y + Tunables.wallReadLabelLift
        )
        wallAnticipationBar?.position = CGPoint(x: size.width / 2, y: strikeY + Tunables.wallFocusReadLabelLift - 28)
        wallAnticipationFill?.position = wallAnticipationBar?.position ?? .zero
        wallReboundBand?.path = CGPath(
            roundedRect: CGRect(
                x: -(size.width * 0.44) / 2,
                y: -5,
                width: size.width * 0.44,
                height: 10
            ),
            cornerWidth: 5,
            cornerHeight: 5,
            transform: nil
        )
        wallReboundBand?.position = CGPoint(
            x: size.width / 2,
            y: size.height * Tunables.wallSurfaceYRatio - 22
        )
        layoutWallHUDPositions()
        hudTopPlate?.path = CGPath(
            roundedRect: CGRect(
                x: -(usesMinimalWallHUD ? 148.0 / 2 : 288.0 / 2),
                y: -(usesMinimalWallHUD ? 58.0 / 2 : 104.0 / 2),
                width: usesMinimalWallHUD ? 148 : 288,
                height: usesMinimalWallHUD ? 58 : 104
            ),
            cornerWidth: usesMinimalWallHUD ? 22 : 30,
            cornerHeight: usesMinimalWallHUD ? 22 : 30,
            transform: nil
        )
        if !usesMinimalWallHUD {
            hudTopPlate?.position = CGPoint(x: size.width / 2, y: size.height * 0.885)
        }
        hudCaptionLabel?.position = CGPoint(x: size.width / 2, y: size.height * 0.934)
        hudPhaseLabel?.position = CGPoint(x: size.width * 0.27, y: size.height * 0.915)
        hudPhaseValueLabel?.position = CGPoint(x: size.width * 0.27, y: size.height * 0.889)
        if !usesMinimalWallHUD {
            hudMaxLabel?.position = CGPoint(x: size.width * 0.73, y: size.height * 0.915)
            hudMaxValueLabel?.position = CGPoint(x: size.width * 0.73, y: size.height * 0.889)
            comboLabel?.position = CGPoint(x: size.width / 2, y: size.height * 0.838)
        }
        if let time = timeLabel {
            time.position = CGPoint(x: size.width / 2, y: size.height * 0.918)
        }
        if let banner = phaseBannerLabel {
            banner.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        }
        if let plate = instructionPlate {
            plate.path = CGPath(
                roundedRect: CGRect(
                    x: -(min(size.width * 0.74, 328) / 2),
                    y: -20,
                    width: min(size.width * 0.74, 328),
                    height: 40
                ),
                cornerWidth: 20,
                cornerHeight: 20,
                transform: nil
            )
            plate.position = CGPoint(x: size.width / 2, y: size.height * 0.14)
        }
        if let instruction = instructionLabel {
            instruction.position = CGPoint(x: size.width / 2, y: size.height * 0.14)
        }
    }

    private func setupBackground() {
        let bg = TennisCourtBackdrop(
            size: size,
            strikeYRatio: Tunables.strikeLineYRatio,
            surface: .current
        )
        bg.zPosition = -100
        addChild(bg)
        background = bg
    }

    /// Soft side-wall auras. These replace the old lane-track columns so the
    /// scene reads like a court facing a wall, not two neon swim lanes.
    private func setupLaneGlow() {
        let wallY = size.height * Tunables.wallSurfaceYRatio
        let glowSize = CGSize(width: size.width * 0.30, height: size.height * 0.24)

        let left = SKShapeNode(ellipseOf: glowSize)
        left.position = CGPoint(x: size.width * 0.22, y: wallY - size.height * 0.06)
        left.strokeColor = .clear
        left.fillColor = UIColor(red: 0.16, green: 0.56, blue: 0.72, alpha: 0.09)
        left.glowWidth = 16
        left.zPosition = -80
        addChild(left)
        leftLaneGlow = left

        let right = SKShapeNode(ellipseOf: glowSize)
        right.position = CGPoint(x: size.width * 0.78, y: wallY - size.height * 0.06)
        right.strokeColor = .clear
        right.fillColor = UIColor(red: 0.74, green: 0.36, blue: 0.30, alpha: 0.08)
        right.glowWidth = 16
        right.zPosition = -80
        addChild(right)
        rightLaneGlow = right
    }

    private func setupStrikeLine() {
        let y = size.height * Tunables.strikeLineYRatio
        let line = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -0.5, width: size.width, height: 1))
        line.position = CGPoint(x: size.width / 2, y: y)
        line.strokeColor = .clear
        line.fillColor = UIColor(red: 0.88, green: 0.96, blue: 1, alpha: 0.08)
        line.glowWidth = 1.5
        line.zPosition = 10
        addChild(line)
        strikeLine = line

        let pulse = StrikeLinePulse(
            width: size.width,
            color: UIColor(red: 0.88, green: 0.96, blue: 1, alpha: 1)
        )
        pulse.position = CGPoint(x: size.width / 2, y: y)
        addChild(pulse)
        strikeLinePulse = pulse

        let strikeHalo = SKShapeNode(rectOf: CGSize(width: size.width * 0.54, height: 12), cornerRadius: 6)
        strikeHalo.fillColor = UIColor(white: 1.0, alpha: 0.015)
        strikeHalo.strokeColor = .clear
        strikeHalo.position = CGPoint(x: size.width / 2, y: y)
        strikeHalo.zPosition = 9
        addChild(strikeHalo)
        self.strikeHalo = strikeHalo

        let gateSize = CGSize(width: size.width * 0.16, height: 22)
        let leftGate = SKShapeNode(rectOf: gateSize, cornerRadius: 11)
        leftGate.fillColor = UIColor(red: 0.33, green: 0.88, blue: 0.95, alpha: 0.12)
        leftGate.strokeColor = UIColor(red: 0.33, green: 0.88, blue: 0.95, alpha: 0.38)
        leftGate.lineWidth = 1.5
        leftGate.glowWidth = 6
        leftGate.alpha = 0.18
        leftGate.position = CGPoint(x: size.width * 0.28, y: y)
        leftGate.zPosition = 12
        addChild(leftGate)
        leftStrikeGate = leftGate

        let rightGate = SKShapeNode(rectOf: gateSize, cornerRadius: 11)
        rightGate.fillColor = UIColor(red: 0.98, green: 0.52, blue: 0.42, alpha: 0.12)
        rightGate.strokeColor = UIColor(red: 0.98, green: 0.52, blue: 0.42, alpha: 0.40)
        rightGate.lineWidth = 1.5
        rightGate.glowWidth = 6
        rightGate.alpha = 0.18
        rightGate.position = CGPoint(x: size.width * 0.72, y: y)
        rightGate.zPosition = 12
        addChild(rightGate)
        rightStrikeGate = rightGate

        let leftPocket = SKShapeNode(circleOfRadius: 18)
        leftPocket.fillColor = UIColor.clear
        leftPocket.strokeColor = UIColor(red: 0.33, green: 0.88, blue: 0.95, alpha: 0.26)
        leftPocket.lineWidth = 1.4
        leftPocket.glowWidth = 5
        leftPocket.alpha = 0.18
        leftPocket.position = CGPoint(x: size.width * 0.34, y: y)
        leftPocket.zPosition = 15
        addChild(leftPocket)
        leftContactPocket = leftPocket

        let rightPocket = SKShapeNode(circleOfRadius: 18)
        rightPocket.fillColor = UIColor.clear
        rightPocket.strokeColor = UIColor(red: 0.93, green: 0.56, blue: 0.46, alpha: 0.26)
        rightPocket.lineWidth = 1.4
        rightPocket.glowWidth = 5
        rightPocket.alpha = 0.18
        rightPocket.position = CGPoint(x: size.width * 0.66, y: y)
        rightPocket.zPosition = 15
        addChild(rightPocket)
        rightContactPocket = rightPocket

        let anticipationBar = SKShapeNode(
            rectOf: CGSize(
                width: Tunables.wallAnticipationBarWidth,
                height: Tunables.wallAnticipationBarHeight
            ),
            cornerRadius: Tunables.wallAnticipationBarHeight / 2
        )
        anticipationBar.fillColor = UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 0.42)
        anticipationBar.strokeColor = UIColor(white: 1.0, alpha: 0.12)
        anticipationBar.lineWidth = 1
        anticipationBar.glowWidth = 4
        anticipationBar.alpha = 0
        anticipationBar.zPosition = 17
        addChild(anticipationBar)
        wallAnticipationBar = anticipationBar

        let anticipationFill = SKShapeNode(
            rectOf: CGSize(
                width: Tunables.wallAnticipationBarWidth * 0.42,
                height: Tunables.wallAnticipationBarHeight * 0.56
            ),
            cornerRadius: Tunables.wallAnticipationBarHeight * 0.28
        )
        anticipationFill.fillColor = UIColor.white.withAlphaComponent(0.82)
        anticipationFill.strokeColor = .clear
        anticipationFill.glowWidth = 10
        anticipationFill.alpha = 0
        anticipationFill.zPosition = 18
        addChild(anticipationFill)
        wallAnticipationFill = anticipationFill

        let wallSurface = SKShapeNode(
            rectOf: CGSize(
                width: size.width * Tunables.wallSurfaceWidthRatio,
                height: Tunables.wallSurfaceHeight
            ),
            cornerRadius: 12
        )
        wallSurface.fillColor = UIColor(red: 0.07, green: 0.10, blue: 0.12, alpha: 0.055)
        wallSurface.strokeColor = UIColor(red: 0.88, green: 0.93, blue: 0.98, alpha: 0.025)
        wallSurface.lineWidth = 0.6
        wallSurface.glowWidth = 0
        wallSurface.position = CGPoint(
            x: size.width / 2,
            y: size.height * Tunables.wallSurfaceYRatio
        )
        wallSurface.zPosition = 13
        addChild(wallSurface)
        wallSurfaceNode = wallSurface

        let wallTarget = SKShapeNode(
            rectOf: CGSize(
                width: size.width * Tunables.wallTargetPanelWidthRatio,
                height: 28
            ),
            cornerRadius: 10
        )
        wallTarget.fillColor = UIColor.white.withAlphaComponent(0.0)
        wallTarget.strokeColor = UIColor.white.withAlphaComponent(0.0)
        wallTarget.lineWidth = 0
        wallTarget.glowWidth = 0
        wallTarget.position = CGPoint(x: 0, y: -10)
        wallTarget.zPosition = 1
        wallSurface.addChild(wallTarget)
        wallTargetNode = wallTarget

        let wallKickShadow = SKShapeNode(
            rectOf: CGSize(width: size.width * 0.26, height: 14),
            cornerRadius: 7
        )
        wallKickShadow.fillColor = UIColor(red: 0.93, green: 0.97, blue: 0.36, alpha: 0.06)
        wallKickShadow.strokeColor = UIColor.clear
        wallKickShadow.glowWidth = 10
        wallKickShadow.alpha = 0.0
        wallKickShadow.position = CGPoint(
            x: size.width / 2,
            y: size.height * Tunables.wallSurfaceYRatio - 22
        )
        wallKickShadow.zPosition = 14
        addChild(wallKickShadow)
        wallKickShadowNode = wallKickShadow

        let reboundBand = SKShapeNode(
            rectOf: CGSize(width: size.width * 0.44, height: 10),
            cornerRadius: 5
        )
        reboundBand.fillColor = UIColor(red: 0.93, green: 0.97, blue: 0.36, alpha: 0.0)
        reboundBand.strokeColor = UIColor(red: 0.93, green: 0.97, blue: 0.36, alpha: 0.0)
        reboundBand.lineWidth = 0
        reboundBand.glowWidth = 0
        reboundBand.alpha = 0
        reboundBand.position = CGPoint(
            x: size.width / 2,
            y: size.height * Tunables.wallSurfaceYRatio - 22
        )
        reboundBand.zPosition = 16
        addChild(reboundBand)
        wallReboundBand = reboundBand

        let leftRead = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        leftRead.fontSize = 11
        leftRead.fontColor = UIColor(white: 1.0, alpha: 0.34)
        leftRead.horizontalAlignmentMode = .center
        leftRead.position = CGPoint(
            x: leftPocket.position.x,
            y: leftPocket.position.y + Tunables.wallReadLabelLift
        )
        leftRead.zPosition = 19
        addChild(leftRead)
        leftStrokeReadLabel = leftRead

        let rightRead = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        rightRead.fontSize = 11
        rightRead.fontColor = UIColor(white: 1.0, alpha: 0.34)
        rightRead.horizontalAlignmentMode = .center
        rightRead.position = CGPoint(
            x: rightPocket.position.x,
            y: rightPocket.position.y + Tunables.wallReadLabelLift
        )
        rightRead.zPosition = 19
        addChild(rightRead)
        rightStrokeReadLabel = rightRead

        let focusRead = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        focusRead.fontSize = 16
        focusRead.fontColor = UIColor(white: 1.0, alpha: 0.88)
        focusRead.horizontalAlignmentMode = .center
        focusRead.alpha = 0
        focusRead.zPosition = 20
        addChild(focusRead)
        focusStrokeReadLabel = focusRead

        let timingRing = SKShapeNode(circleOfRadius: Tunables.wallContactRingRadius)
        timingRing.fillColor = .clear
        timingRing.strokeColor = UIColor.white.withAlphaComponent(0.22)
        timingRing.lineWidth = 2.2
        timingRing.glowWidth = 6
        timingRing.alpha = 0
        timingRing.zPosition = 16
        addChild(timingRing)
        contactTimingRing = timingRing
    }

    private func layoutWallHUDPositions() {
        guard usesMinimalWallHUD else { return }
        let courtScoreY = size.height * Tunables.minimalHUDScoreYRatio
        scoreLabel?.position = CGPoint(x: size.width / 2, y: courtScoreY)
        hudTopPlate?.position = CGPoint(x: size.width / 2, y: courtScoreY)
        hudMaxLabel?.position = CGPoint(x: size.width * 0.78, y: courtScoreY)
        hudMaxValueLabel?.position = CGPoint(x: size.width * 0.78, y: courtScoreY)
        comboLabel?.position = CGPoint(x: size.width / 2, y: courtScoreY - 30)
    }

    // MARK: - Opponent Avatar

    private func setupOpponentAvatar() {
        let appearance = avatarAppearance ?? RallyAvatarAppearance()
        // Scale relative to court perspective: opponent stands at the far baseline.
        // We compute the same farY the court backdrop uses.
        let farY = size.height * Tunables.gameplayCourtFarYRatio
        // At the far baseline the perspective ratio to the near baseline (~54% vs ~18%
        // of width) gives us ~0.33 shrink. Use 0.42 for a slightly heroic silhouette.
        let oppScale: CGFloat = 0.42
        let s = oppScale
        let skin   = appearance.skinUIColor.withAlphaComponent(0.85)
        let top    = appearance.topUIColor.withAlphaComponent(0.90)
        let bottom = appearance.shortsUIColor.withAlphaComponent(0.90)
        let racket = appearance.racketUIColor

        let root = SKNode()
        // Place root so the figure's feet land on the far baseline.
        // Figure legs extend to -22*s below root, so raise root by that much.
        root.position = CGPoint(x: size.width / 2, y: farY + 22 * s)
        root.zPosition = -89      // just above court backdrop (-95) but behind court lines (-90)
        root.alpha = 1.0
        addChild(root)
        opponentRoot = root

        // Ground shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 42 * s, height: 6 * s))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -22 * s)
        shadow.zPosition = -1
        root.addChild(shadow)

        // Legs (in wide-stance ready position, slightly bent)
        for sign in [-1.0, 1.0] {
            let leg = SKShapeNode(rectOf: CGSize(width: 10 * s, height: 24 * s), cornerRadius: 3 * s)
            leg.fillColor = skin
            leg.strokeColor = .clear
            leg.position = CGPoint(x: sign * 7 * s, y: -9 * s)
            leg.zRotation = sign * 0.12      // slight V-stance
            leg.zPosition = 1
            root.addChild(leg)
            let shoe = SKShapeNode(rectOf: CGSize(width: 13 * s, height: 5 * s), cornerRadius: 2 * s)
            shoe.fillColor = appearance.shoesUIColor.withAlphaComponent(0.90)
            shoe.strokeColor = .clear
            shoe.position = CGPoint(x: sign * 8 * s, y: -21 * s)
            shoe.zPosition = 1
            root.addChild(shoe)
        }

        // Shorts
        let shorts = SKShapeNode(rectOf: CGSize(width: 24 * s, height: 12 * s), cornerRadius: 4 * s)
        shorts.fillColor = bottom
        shorts.strokeColor = .clear
        shorts.position = CGPoint(x: 0, y: -2 * s)
        shorts.zPosition = 2
        root.addChild(shorts)

        // Torso
        let torso = SKShapeNode(rectOf: CGSize(width: 22 * s, height: 28 * s), cornerRadius: 5 * s)
        torso.fillColor = top
        torso.strokeColor = UIColor.white.withAlphaComponent(0.15)
        torso.lineWidth = 0.8 * s
        torso.position = CGPoint(x: 0, y: 18 * s)
        torso.zPosition = 2
        root.addChild(torso)

        // Arms — racket arm (left from opponent's view = right side of screen) raised
        // Non-racket arm slightly out for balance
        let racketArm = SKShapeNode(rectOf: CGSize(width: 8 * s, height: 20 * s), cornerRadius: 3 * s)
        racketArm.fillColor = skin
        racketArm.strokeColor = .clear
        racketArm.position = CGPoint(x: -16 * s, y: 14 * s)
        racketArm.zRotation = -0.55   // raised to hit
        racketArm.zPosition = 1
        root.addChild(racketArm)

        let freeArm = SKShapeNode(rectOf: CGSize(width: 8 * s, height: 20 * s), cornerRadius: 3 * s)
        freeArm.fillColor = skin.withAlphaComponent(0.70)
        freeArm.strokeColor = .clear
        freeArm.position = CGPoint(x: 16 * s, y: 14 * s)
        freeArm.zRotation = 0.30
        freeArm.zPosition = 1
        root.addChild(freeArm)

        // Head
        let head = SKShapeNode(ellipseOf: CGSize(width: 16 * s, height: 18 * s))
        head.fillColor = skin
        head.strokeColor = UIColor.white.withAlphaComponent(0.08)
        head.lineWidth = 0.5 * s
        head.position = CGPoint(x: 0, y: 36 * s)
        head.zPosition = 3
        root.addChild(head)

        // Hair cap
        let hair = SKShapeNode(ellipseOf: CGSize(width: 17 * s, height: 10 * s))
        hair.fillColor = appearance.hairUIColor
        hair.strokeColor = .clear
        hair.position = CGPoint(x: 0, y: 42 * s)
        hair.zPosition = 3.5
        root.addChild(hair)

        // Racket hoop — prominent so it reads clearly
        let hoop = SKShapeNode(ellipseOf: CGSize(width: 14 * s, height: 18 * s))
        hoop.fillColor = UIColor.clear
        hoop.strokeColor = racket
        hoop.lineWidth = 3.0 * s
        hoop.glowWidth = 2
        hoop.position = CGPoint(x: -26 * s, y: 28 * s)
        hoop.zRotation = -0.55
        hoop.zPosition = 3
        root.addChild(hoop)
        opponentRacketHead = hoop

        // Racket strings (cross pattern)
        for i in [-1, 0, 1] {
            let str = SKShapeNode(rectOf: CGSize(width: 1.5 * s, height: 14 * s), cornerRadius: 0.5 * s)
            str.fillColor = UIColor.white.withAlphaComponent(0.42)
            str.strokeColor = .clear
            str.position = CGPoint(x: CGFloat(i) * 4 * s, y: 0)
            hoop.addChild(str)
        }

        let handle = SKShapeNode(rectOf: CGSize(width: 3.5 * s, height: 14 * s), cornerRadius: 1.5 * s)
        handle.fillColor = appearance.racketAccentUIColor
        handle.strokeColor = .clear
        handle.position = CGPoint(x: -22 * s, y: 17 * s)
        handle.zRotation = -0.55
        handle.zPosition = 3
        root.addChild(handle)

        // Subtle idle sway
        root.run(.repeatForever(.sequence([
            .rotate(byAngle: 0.008, duration: 1.2),
            .rotate(byAngle: -0.008, duration: 1.2)
        ])))
    }

    private func animateOpponentHit() {
        guard let hoop = opponentRacketHead, let root = opponentRoot else { return }
        opponentHitTime = currentTimeSnapshot
        hoop.run(.sequence([
            .group([.scale(to: 1.35, duration: 0.06), .fadeAlpha(to: 1.0, duration: 0.06)]),
            .group([.scale(to: 1.0, duration: 0.18), .fadeAlpha(to: 0.72, duration: 0.18)])
        ]))
        root.run(.sequence([
            .moveBy(x: 0, y: 6, duration: 0.05),
            .moveBy(x: 0, y: -6, duration: 0.12)
        ]))
    }

    private func setupCourtAvatar() {
        let appearance = avatarAppearance ?? RallyAvatarAppearance()
        let bodyScale: CGFloat = min(1.14, max(1.00, appearance.bodyScale * 1.08))
        let profile = appearance.bodyProfile
        let layout = RallyAvatarRebuildDefaults.CourtLayout.make(profile: profile, scale: bodyScale)
        courtAvatarLayout = layout
        courtAvatarScale = bodyScale
        // Gameplay must match the Home/Locker identity. Do not hardcode a second
        // player look here; that is how the in-game avatar drifted into "catfish".
        let skin = appearance.skinUIColor
        let top = appearance.topUIColor
        let bottom = appearance.shortsUIColor
        let shoes = appearance.shoesUIColor
        let shoesAccent = appearance.shoesAccentUIColor
        let racket = appearance.racketUIColor
        let racketAccent = appearance.racketAccentUIColor
        playerRacketBaseColor = racket
        playerRacketAccentColor = racketAccent

        let root = SKNode()
        root.zPosition = 14
        root.position = CGPoint(x: size.width / 2, y: size.height * Tunables.gameplayPlayerRootYRatio)
        addChild(root)
        playerRoot = root

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 138 * bodyScale, height: 18 * bodyScale))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.48)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -14 * bodyScale)
        shadow.zPosition = -1
        root.addChild(shadow)
        playerShadow = shadow

        let stanceGlow = SKShapeNode(ellipseOf: CGSize(width: 128 * bodyScale, height: 18 * bodyScale))
        stanceGlow.fillColor = racketAccent.withAlphaComponent(0.018)
        stanceGlow.strokeColor = .clear
        stanceGlow.position = CGPoint(x: 0, y: -12 * bodyScale)
        stanceGlow.zPosition = -2
        root.addChild(stanceGlow)
        playerStanceGlow = stanceGlow

        let legVisualHeight = layout.legHeight * 0.74
        let leadLeg = SKShapeNode(path: RallyAvatarGeometry.athleticLegPath(scale: bodyScale, height: legVisualHeight, side: 1))
        leadLeg.strokeColor = .clear
        leadLeg.position = CGPoint(x: 21 * bodyScale, y: layout.legY + 2 * bodyScale)
        root.addChild(leadLeg)
        playerLeadLeg = leadLeg
        leadLeg.attachRenderedSprite(
            RallyAvatarPartRenderer.legTexture(skinColor: skin, scale: bodyScale, legVisualHeight: legVisualHeight, side: 1)
        )
        addKneeBand(to: leadLeg, skin: skin, width: 13.8 * bodyScale, y: -legVisualHeight * 0.06)

        // Quad highlight on lead leg
        let leadLegHL = SKShapeNode(path: RallyAvatarGeometry.legHighlightPath(scale: bodyScale, legVisualHeight: legVisualHeight))
        leadLegHL.fillColor = UIColor.white.withAlphaComponent(0.09)
        leadLegHL.strokeColor = .clear
        leadLegHL.position = CGPoint(x: 21 * bodyScale, y: layout.legY + 2 * bodyScale + legVisualHeight * 0.16)
        leadLegHL.zPosition = 1.1
        root.addChild(leadLegHL)

        let trailLegVisualHeight = layout.trailLegHeight * 0.74
        let trailLeg = SKShapeNode(path: RallyAvatarGeometry.athleticLegPath(scale: bodyScale, height: trailLegVisualHeight, side: -1))
        trailLeg.strokeColor = .clear
        trailLeg.position = CGPoint(x: -21 * bodyScale, y: layout.legY)
        root.addChild(trailLeg)
        playerTrailLeg = trailLeg
        trailLeg.attachRenderedSprite(
            RallyAvatarPartRenderer.legTexture(skinColor: skin.mixed(with: .black, ratio: 0.04), scale: bodyScale, legVisualHeight: trailLegVisualHeight, side: -1)
        )
        addKneeBand(to: trailLeg, skin: skin, width: 13.5 * bodyScale, y: -trailLegVisualHeight * 0.06)

        // Quad highlight on trail leg (dimmer — in shadow)
        let trailLegHL = SKShapeNode(path: RallyAvatarGeometry.legHighlightPath(scale: bodyScale, legVisualHeight: trailLegVisualHeight))
        trailLegHL.fillColor = UIColor.white.withAlphaComponent(0.05)
        trailLegHL.strokeColor = .clear
        trailLegHL.position = CGPoint(x: -21 * bodyScale, y: layout.legY + trailLegVisualHeight * 0.16)
        trailLegHL.zPosition = 1.1
        root.addChild(trailLegHL)

        let leadShoeY = layout.legY - legVisualHeight * 0.51
        let trailShoeY = layout.legY - trailLegVisualHeight * 0.51
        addDetailedShoe(
            to: root,
            x: 21 * bodyScale, y: leadShoeY,
            bodyScale: bodyScale,
            upper: shoes, accent: shoesAccent,
            zBase: 2,
            primaryRef: &playerLeadShoe
        )
        addDetailedShoe(
            to: root,
            x: -21 * bodyScale, y: trailShoeY,
            bodyScale: bodyScale,
            upper: shoes.mixed(with: .black, ratio: 0.06), accent: shoesAccent,
            zBase: 2,
            xFlip: true,   // left foot: mirror shoe so toe faces outward, not inward-caved
            primaryRef: &playerTrailShoe
        )

        let pelvisY = layout.torsoY - 43 * bodyScale
        let pelvis = SKShapeNode(path: RallyAvatarGeometry.athleticShortsPath(scale: bodyScale))
        pelvis.strokeColor = .clear
        pelvis.lineWidth = 0
        pelvis.position = CGPoint(x: 0, y: pelvisY)
        pelvis.zPosition = 2.05
        pelvis.alpha = 0.96
        root.addChild(pelvis)
        playerPelvis = pelvis
        pelvis.attachRenderedSprite(
            RallyAvatarPartRenderer.shortsTexture(shortsColor: bottom, scale: bodyScale)
        )

        // Elastic waistband at top of shorts
        let waistband = SKShapeNode(path: RallyAvatarGeometry.shortsWaistbandPath(scale: bodyScale))
        waistband.fillColor = bottom.blended(withFraction: 0.22, of: .white) ?? bottom
        waistband.strokeColor = .clear
        waistband.lineWidth = 0
        waistband.position = CGPoint(x: 0, y: pelvisY + 8 * bodyScale)
        waistband.zPosition = 2.06
        root.addChild(waistband)

        let torso = SKShapeNode(path: RallyAvatarGeometry.premiumTorsoPath(scale: bodyScale))
        torso.strokeColor = .clear
        torso.lineWidth = 0
        torso.position = CGPoint(x: 0, y: layout.torsoY - 2 * bodyScale)
        torso.zPosition = 2.2
        root.addChild(torso)
        playerTorso = torso
        // Gradient-rendered torso replaces flat fill
        torso.attachRenderedSprite(
            RallyAvatarPartRenderer.torsoTexture(shirtColor: top, accentColor: racketAccent, scale: bodyScale)
        )

        // V-neck collar (stays as SKShapeNode — thin line detail)
        let collar = SKShapeNode(path: RallyAvatarGeometry.shirtCollarPath(scale: bodyScale))
        collar.fillColor = top.mixed(with: .black, ratio: 0.30)
        collar.strokeColor = .clear
        collar.position = CGPoint(x: 0, y: layout.torsoY + 22 * bodyScale)
        collar.zPosition = 2.3
        root.addChild(collar)

        let faceScale = layout.headPathScale * 0.96
        let neckSize = RallyAvatarGeometry.neckSize(scale: faceScale)
        let neck = SKShapeNode(rectOf: neckSize, cornerRadius: neckSize.width * 0.42)
        neck.fillColor = skin.mixed(with: .black, ratio: 0.03)
        neck.strokeColor = .clear
        neck.position = CGPoint(x: 0, y: layout.neckY - 2 * bodyScale)
        root.addChild(neck)
        playerNeck = neck
        // Keep the same identity language as Home. A rear-only wall-rally puppet
        // hides hair/face and reads like a different player after tapping Play.
        let showsRearAvatar = false

        let head = SKShapeNode(path: RallyAvatarGeometry.premiumHeadPath(scale: layout.headPathScale * 0.96))
        head.strokeColor = .clear
        head.lineWidth = 0
        head.position = CGPoint(x: 0, y: layout.headY + 2 * bodyScale)
        head.zPosition = 6
        root.addChild(head)
        playerHead = head
        head.attachRenderedSprite(
            RallyAvatarPartRenderer.headTexture(skinColor: skin, scale: layout.headPathScale * 0.96),
            zPos: 0
        )

        let hairScale = layout.headPathScale * 0.98
        let backHair = SKShapeNode(path: RallyAvatarGeometry.premiumBackHairPath(scale: hairScale))
        backHair.fillColor = appearance.hairUIColor
        backHair.strokeColor = .clear
        backHair.lineWidth = 0
        backHair.position = CGPoint(x: 0, y: layout.headY + 3.8 * bodyScale)
        backHair.zPosition = showsRearAvatar ? 6.55 : 5.7
        root.addChild(backHair)
        playerBackHair = backHair

        let hair = SKShapeNode(path: RallyAvatarGeometry.premiumHairPath(scale: hairScale))
        hair.fillColor = appearance.hairUIColor
        hair.strokeColor = .clear
        hair.lineWidth = 0
        hair.position = CGPoint(x: 0, y: layout.headY + 7.8 * bodyScale)
        hair.zPosition = 7
        hair.isHidden = showsRearAvatar
        root.addChild(hair)
        playerHair = hair

        let leftEar = SKShapeNode(path: RallyAvatarGeometry.earPath(side: -1, scale: faceScale))
        leftEar.fillColor = skin
        leftEar.strokeColor = UIColor.black.withAlphaComponent(0.06)
        leftEar.lineWidth = 0.35 * bodyScale
        leftEar.position = CGPoint(x: 0, y: layout.headY + 2 * bodyScale)
        leftEar.zPosition = 5.85
        root.addChild(leftEar)

        let rightEar = SKShapeNode(path: RallyAvatarGeometry.earPath(side: 1, scale: faceScale))
        rightEar.fillColor = skin
        rightEar.strokeColor = UIColor.black.withAlphaComponent(0.06)
        rightEar.lineWidth = 0.35 * bodyScale
        rightEar.position = CGPoint(x: 0, y: layout.headY + 2 * bodyScale)
        rightEar.zPosition = 5.85
        root.addChild(rightEar)

        let hairHighlight = SKShapeNode(path: RallyAvatarGeometry.hairHighlightPath(scale: hairScale))
        hairHighlight.fillColor = UIColor(red: 0.165, green: 0.165, blue: 0.188, alpha: 0.42)
        hairHighlight.strokeColor = .clear
        hairHighlight.position = CGPoint(x: 0, y: layout.headY + 7.8 * bodyScale)
        hairHighlight.zPosition = 7.1
        hairHighlight.isHidden = showsRearAvatar
        root.addChild(hairHighlight)

        let eyeFill = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1)
        let showsFrontFace = !showsRearAvatar
        let leftEye = SKShapeNode(path: RallyAvatarGeometry.eyePath(side: -1, scale: faceScale))
        leftEye.fillColor = eyeFill
        leftEye.strokeColor = UIColor.white.withAlphaComponent(0.10)
        leftEye.lineWidth = 0.35 * bodyScale
        leftEye.position = CGPoint(x: 0, y: layout.headY + 2 * bodyScale)
        leftEye.zPosition = 8
        leftEye.isHidden = !showsFrontFace
        root.addChild(leftEye)
        playerLeftEye = leftEye

        let rightEye = SKShapeNode(path: RallyAvatarGeometry.eyePath(side: 1, scale: faceScale))
        rightEye.fillColor = eyeFill
        rightEye.strokeColor = UIColor.white.withAlphaComponent(0.10)
        rightEye.lineWidth = 0.35 * bodyScale
        rightEye.position = CGPoint(x: 0, y: layout.headY + 2 * bodyScale)
        rightEye.zPosition = 8
        rightEye.isHidden = !showsFrontFace
        root.addChild(rightEye)
        playerRightEye = rightEye

        for side in [-1.0, 1.0] {
            let spec = SKShapeNode(path: RallyAvatarGeometry.eyeSpecularPath(side: side, scale: faceScale))
            spec.fillColor = UIColor.white.withAlphaComponent(0.76)
            spec.strokeColor = .clear
            spec.position = CGPoint(x: 0, y: layout.headY + 2 * bodyScale)
            spec.zPosition = 8.1
            spec.isHidden = !showsFrontFace
            root.addChild(spec)
        }

        let browColor = appearance.hairUIColor.withAlphaComponent(0.94)
        let leftBrow = SKShapeNode(path: RallyAvatarGeometry.browPath(side: -1, scale: faceScale))
        leftBrow.fillColor = browColor
        leftBrow.strokeColor = .clear
        leftBrow.position = CGPoint(x: 0, y: layout.headY + 2 * bodyScale)
        leftBrow.zRotation = 0.0
        leftBrow.zPosition = 8
        leftBrow.isHidden = !showsFrontFace
        root.addChild(leftBrow)
        playerLeftBrow = leftBrow

        let rightBrow = SKShapeNode(path: RallyAvatarGeometry.browPath(side: 1, scale: faceScale))
        rightBrow.fillColor = browColor
        rightBrow.strokeColor = .clear
        rightBrow.position = CGPoint(x: 0, y: layout.headY + 2 * bodyScale)
        rightBrow.zRotation = 0.0
        rightBrow.zPosition = 8
        rightBrow.isHidden = !showsFrontFace
        root.addChild(rightBrow)
        playerRightBrow = rightBrow

        let nose = SKShapeNode(path: RallyAvatarGeometry.nosePath(scale: faceScale))
        nose.fillColor = .clear
        nose.strokeColor = skin.mixed(with: .black, ratio: 0.08).withAlphaComponent(0.42)
        nose.lineWidth = 0.85 * bodyScale
        nose.lineCap = .round
        nose.position = CGPoint(x: 0, y: layout.headY + 2 * bodyScale)
        nose.zPosition = 8
        nose.isHidden = !showsFrontFace
        root.addChild(nose)
        playerNose = nose

        let showsGlasses = false
        let lensSize = CGSize(width: 16 * bodyScale, height: 12 * bodyScale)
        let lensStroke = RallyAvatarRebuildDefaults.Face.glassesFrameUIColor
        let leftLens = SKShapeNode(rectOf: lensSize, cornerRadius: 5 * bodyScale)
        leftLens.fillColor = RallyAvatarRebuildDefaults.Face.lensFillUIColor
        leftLens.strokeColor = lensStroke
        leftLens.lineWidth = 1.1 * bodyScale
        leftLens.position = CGPoint(x: -13 * bodyScale, y: layout.headY)
        leftLens.zPosition = 3
        leftLens.isHidden = !showsGlasses
        root.addChild(leftLens)
        playerLeftLens = leftLens

        let rightLens = SKShapeNode(rectOf: lensSize, cornerRadius: 5 * bodyScale)
        rightLens.fillColor = RallyAvatarRebuildDefaults.Face.lensFillUIColor
        rightLens.strokeColor = lensStroke
        rightLens.lineWidth = 1.1 * bodyScale
        rightLens.position = CGPoint(x: 13 * bodyScale, y: layout.headY)
        rightLens.zPosition = 3
        rightLens.isHidden = !showsGlasses
        root.addChild(rightLens)
        playerRightLens = rightLens

        let bridge = SKShapeNode(rectOf: CGSize(width: 7 * bodyScale, height: 1.2 * bodyScale), cornerRadius: 0.6 * bodyScale)
        bridge.fillColor = lensStroke
        bridge.strokeColor = .clear
        bridge.position = CGPoint(x: 0, y: layout.headY)
        bridge.zPosition = 3
        bridge.isHidden = !showsGlasses
        root.addChild(bridge)
        playerGlassesBridge = bridge

        let leftTemple = SKShapeNode(rectOf: CGSize(width: 11 * bodyScale, height: 1.2 * bodyScale), cornerRadius: 0.6 * bodyScale)
        leftTemple.fillColor = lensStroke
        leftTemple.strokeColor = .clear
        leftTemple.position = CGPoint(x: -24 * bodyScale, y: layout.headY)
        leftTemple.zRotation = 0.14
        leftTemple.zPosition = 3
        leftTemple.isHidden = !showsGlasses
        root.addChild(leftTemple)
        playerLeftTemple = leftTemple

        let rightTemple = SKShapeNode(rectOf: CGSize(width: 11 * bodyScale, height: 1.2 * bodyScale), cornerRadius: 0.6 * bodyScale)
        rightTemple.fillColor = lensStroke
        rightTemple.strokeColor = .clear
        rightTemple.position = CGPoint(x: 24 * bodyScale, y: layout.headY)
        rightTemple.zRotation = -0.14
        rightTemple.zPosition = 3
        rightTemple.isHidden = !showsGlasses
        root.addChild(rightTemple)
        playerRightTemple = rightTemple

        let mouth = SKShapeNode(path: RallyAvatarGeometry.friendlyMouthPath(scale: faceScale))
        mouth.strokeColor = UIColor(red: 0.62, green: 0.42, blue: 0.36, alpha: 0.32)
        mouth.fillColor = .clear
        mouth.lineWidth = 1.2 * bodyScale
        mouth.lineCap = .round
        mouth.position = CGPoint(x: 0, y: layout.headY + 2 * bodyScale + RallyAvatarGeometry.mouthCenterY(scale: faceScale))
        mouth.zRotation = RallyAvatarRebuildDefaults.Face.smileRotationDegrees * .pi / 180
        mouth.zPosition = 8
        mouth.alpha = showsFrontFace ? 0.60 : 0
        mouth.isHidden = !showsFrontFace
        root.addChild(mouth)
        playerMouth = mouth

        let leadArm = SKShapeNode(path: RallyAvatarGeometry.armPath(scale: bodyScale, topWidth: 14.2, bottomWidth: 9.8, length: 63))
        leadArm.strokeColor = .clear
        leadArm.position = CGPoint(x: 36 * bodyScale, y: layout.torsoY + 1 * bodyScale)
        leadArm.zRotation = -0.42
        leadArm.zPosition = 3.0  // in front of torso — racket arm is always visible
        root.addChild(leadArm)
        playerLeadArm = leadArm
        leadArm.attachRenderedSprite(
            RallyAvatarPartRenderer.armTexture(skinColor: skin, scale: bodyScale, topWidth: 14.2, bottomWidth: 9.8, length: 63)
        )

        // Sleeve cap over shoulder joint — tracks arm dynamically in updateCourtAvatar
        let leadSleeveR: CGFloat = 11.5 * bodyScale
        let leadSleeve = SKShapeNode(circleOfRadius: leadSleeveR)
        leadSleeve.fillColor = top.blended(withFraction: 0.12, of: .white) ?? top
        leadSleeve.strokeColor = .clear
        leadSleeve.lineWidth = 0
        leadSleeve.position = CGPoint(x: 36 * bodyScale, y: layout.torsoY + 32 * bodyScale)
        leadSleeve.zPosition = 3.1  // just above leadArm (3.0) to cap the joint
        root.addChild(leadSleeve)
        playerLeadSleeve = leadSleeve

        let trailArm = SKShapeNode(path: RallyAvatarGeometry.armPath(scale: bodyScale, topWidth: 13.8, bottomWidth: 9.4, length: 62))
        trailArm.strokeColor = .clear
        trailArm.position = CGPoint(x: -36 * bodyScale, y: layout.torsoY + 4 * bodyScale)
        trailArm.zRotation = 0.30
        trailArm.zPosition = 1.8  // behind torso (trail arm reads as behind body)
        root.addChild(trailArm)
        playerTrailArm = trailArm
        trailArm.attachRenderedSprite(
            RallyAvatarPartRenderer.armTexture(skinColor: skin.mixed(with: .black, ratio: 0.05), scale: bodyScale, topWidth: 13.8, bottomWidth: 9.4, length: 62)
        )

        let trailSleeveR: CGFloat = 11.0 * bodyScale
        let trailSleeve = SKShapeNode(circleOfRadius: trailSleeveR)
        trailSleeve.fillColor = top.blended(withFraction: 0.05, of: .black) ?? top
        trailSleeve.strokeColor = .clear
        trailSleeve.lineWidth = 0
        trailSleeve.position = CGPoint(x: -36 * bodyScale, y: layout.torsoY + 32 * bodyScale)
        trailSleeve.zPosition = 2.1  // just above trailArm (1.8), below torso front
        root.addChild(trailSleeve)
        playerTrailSleeve = trailSleeve

        let leadHand = SKShapeNode(circleOfRadius: RallyAvatarGeometry.handRadius(scale: bodyScale))
        leadHand.fillColor = skin.brightened(0.04)
        leadHand.strokeColor = UIColor.white.withAlphaComponent(0.08)
        leadHand.lineWidth = 0.8 * bodyScale
        leadHand.position = CGPoint(x: 54 * bodyScale, y: 112 * bodyScale)
        leadHand.zPosition = 5
        root.addChild(leadHand)
        playerLeadHand = leadHand

        let trailHand = SKShapeNode(circleOfRadius: RallyAvatarGeometry.handRadius(scale: bodyScale, armThickness: 12.8))
        trailHand.fillColor = skin.brightened(0.035)
        trailHand.strokeColor = UIColor.white.withAlphaComponent(0.08)
        trailHand.lineWidth = 0.8 * bodyScale
        trailHand.position = CGPoint(x: -42 * bodyScale, y: 112 * bodyScale)
        trailHand.zPosition = 5
        trailHand.alpha = 0.75
        root.addChild(trailHand)
        playerTrailHand = trailHand

        let handle = SKShapeNode(rectOf: CGSize(width: 7.2 * bodyScale, height: 58 * bodyScale), cornerRadius: 3.6 * bodyScale)
        handle.fillColor = racketAccent
        handle.strokeColor = .white.withAlphaComponent(0.12)
        handle.lineWidth = 1
        handle.position = CGPoint(x: 54 * bodyScale, y: 125 * bodyScale)
        handle.zRotation = -0.42
        handle.zPosition = 3
        root.addChild(handle)
        playerRacketHandle = handle

        let hoop = SKShapeNode(ellipseOf: CGSize(width: 46 * bodyScale, height: 64 * bodyScale))
        hoop.fillColor = racketAccent.withAlphaComponent(0.006)
        hoop.strokeColor = racket
        hoop.lineWidth = 4.0 * bodyScale
        hoop.glowWidth = 0.25
        hoop.position = CGPoint(x: 74 * bodyScale, y: 164 * bodyScale)
        hoop.zRotation = -0.28
        hoop.zPosition = 3
        root.addChild(hoop)
        playerRacketHead = hoop

        playerRacketStrings.removeAll()
        for offset in [-16, -6, 6, 16] {
            let string = SKShapeNode(rectOf: CGSize(width: 1.2 * bodyScale, height: 52 * bodyScale), cornerRadius: 0.6 * bodyScale)
            string.fillColor = UIColor.white.withAlphaComponent(0.54)
            string.strokeColor = .clear
            string.position = CGPoint(x: CGFloat(offset) * bodyScale, y: 0)
            hoop.addChild(string)
            playerRacketStrings.append(string)
        }
        for offset in [-18, 0, 18] {
            let string = SKShapeNode(rectOf: CGSize(width: 36 * bodyScale, height: 1.2 * bodyScale), cornerRadius: 0.6 * bodyScale)
            string.fillColor = UIColor.white.withAlphaComponent(0.46)
            string.strokeColor = .clear
            string.position = CGPoint(x: 0, y: CGFloat(offset) * bodyScale)
            hoop.addChild(string)
            playerRacketStrings.append(string)
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func addDetailedShoe(
        to root: SKNode,
        x: CGFloat, y: CGFloat,
        bodyScale: CGFloat,
        upper: UIColor, accent: UIColor,
        zBase: CGFloat,
        xFlip: Bool = false,
        primaryRef: inout SKShapeNode?
    ) {
        // Mirror factor: -1 for left foot so toe faces outward, not caved inward.
        let flip: CGFloat = xFlip ? -1 : 1

        // 1. Midsole/outsole — darkest layer, sits lowest (symmetric — no flip needed)
        let sole = SKShapeNode(path: RallyAvatarGeometry.shoeSolePath(scale: bodyScale))
        sole.fillColor = upper.mixed(with: .black, ratio: 0.42) ?? UIColor(white: 0.1, alpha: 1)
        sole.strokeColor = .clear
        sole.position = CGPoint(x: x, y: y - 4.8 * bodyScale)
        sole.zPosition = zBase
        root.addChild(sole)

        // 2. Shoe upper — main body (asymmetric: toe at +x; flip for left foot)
        let body = SKShapeNode(path: RallyAvatarGeometry.shoeBodyPath(scale: bodyScale))
        body.fillColor = upper
        body.strokeColor = accent.withAlphaComponent(0.55)
        body.lineWidth = 1.2 * bodyScale
        body.xScale = flip
        body.position = CGPoint(x: x, y: y)
        body.zPosition = zBase + 0.05
        root.addChild(body)
        primaryRef = body

        // 3. Side brand stripe (asymmetric: stripe on toe side; flip for left foot)
        let stripe = SKShapeNode(path: RallyAvatarGeometry.shoeStripePath(scale: bodyScale))
        stripe.fillColor = accent.withAlphaComponent(0.82)
        stripe.strokeColor = .clear
        stripe.xScale = flip
        stripe.position = CGPoint(x: x, y: y)
        stripe.zPosition = zBase + 0.06
        root.addChild(stripe)

        // 4. Tongue — lighter patch at top centre
        let tongue = SKShapeNode(path: RallyAvatarGeometry.shoeTonguePath(scale: bodyScale))
        tongue.fillColor = upper.blended(withFraction: 0.20, of: .white) ?? upper
        tongue.strokeColor = .clear
        tongue.position = CGPoint(x: x, y: y)
        tongue.zPosition = zBase + 0.07
        root.addChild(tongue)

        // 5. Lace bars
        let laces = SKShapeNode(path: RallyAvatarGeometry.shoeLacePath(scale: bodyScale))
        laces.fillColor = UIColor.white.withAlphaComponent(0.72)
        laces.strokeColor = .clear
        laces.position = CGPoint(x: x, y: y)
        laces.zPosition = zBase + 0.08
        root.addChild(laces)
    }

    private func addKneeBand(to leg: SKShapeNode, skin: UIColor, width: CGFloat, y: CGFloat) {
        let bandHeight = max(1.5, width * 0.13)
        let knee = SKShapeNode(rectOf: CGSize(width: width, height: bandHeight), cornerRadius: bandHeight * 0.5)
        knee.fillColor = skin.mixed(with: .black, ratio: 0.16).withAlphaComponent(0.34)
        knee.strokeColor = UIColor.white.withAlphaComponent(0.05)
        knee.lineWidth = 0.35
        knee.position = CGPoint(x: 0, y: y)
        knee.zPosition = 2
        leg.addChild(knee)
    }

    private func addShortsPanel(to leg: SKShapeNode, color: UIColor, width: CGFloat, height: CGFloat, y: CGFloat) {
        let panel = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: min(width, height) * 0.22)
        panel.fillColor = color.withAlphaComponent(0.96)
        panel.strokeColor = UIColor.white.withAlphaComponent(0.035)
        panel.lineWidth = 0.45
        panel.position = CGPoint(x: 0, y: y)
        panel.zPosition = 3
        leg.addChild(panel)
    }

    private func setupHUD() {
        let topPlateSize = usesMinimalWallHUD
            ? CGSize(width: 148, height: 58)
            : CGSize(width: 288, height: 104)
        let topPlate = SKShapeNode(
            rectOf: topPlateSize,
            cornerRadius: usesMinimalWallHUD ? 22 : 30
        )
        topPlate.fillColor = UIColor(
            red: 0.03,
            green: 0.05,
            blue: 0.09,
            alpha: usesMinimalWallHUD ? 0.28 : 0.42
        )
        topPlate.strokeColor = UIColor(white: 1.0, alpha: usesMinimalWallHUD ? 0.10 : 0.16)
        topPlate.lineWidth = 1.2
        topPlate.glowWidth = usesMinimalWallHUD ? 3 : 6
        topPlate.position = CGPoint(
            x: size.width / 2,
            y: usesMinimalWallHUD
                ? size.height * Tunables.wallReboundBandYRatio + 28
                : size.height * 0.885
        )
        topPlate.zPosition = 46
        addChild(topPlate)
        hudTopPlate = topPlate
        if usesMinimalWallHUD {
            topPlate.alpha = 0
            topPlate.strokeColor = .clear
            topPlate.fillColor = .clear
            topPlate.isHidden = true
        }

        let caption = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        caption.text = usesMinimalWallHUD ? "" : "MATCH SCORE"
        caption.fontSize = 10
        caption.fontColor = UIColor(white: 1.0, alpha: 0.42)
        caption.position = CGPoint(x: size.width / 2, y: size.height * 0.934)
        caption.zPosition = 50
        caption.horizontalAlignmentMode = .center
        addChild(caption)
        hudCaptionLabel = caption

        let phaseLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        phaseLabel.text = usesMinimalWallHUD ? "" : "PHASE"
        phaseLabel.fontSize = 9
        phaseLabel.fontColor = UIColor(white: 1.0, alpha: 0.28)
        phaseLabel.position = CGPoint(x: size.width * 0.27, y: size.height * 0.915)
        phaseLabel.zPosition = 50
        phaseLabel.horizontalAlignmentMode = .left
        addChild(phaseLabel)
        hudPhaseLabel = phaseLabel

        let phaseValue = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        phaseValue.text = usesMinimalWallHUD ? "" : "WARM-UP"
        phaseValue.fontSize = 14
        phaseValue.fontColor = UIColor(white: 1.0, alpha: 0.84)
        phaseValue.position = CGPoint(x: size.width * 0.27, y: size.height * 0.889)
        phaseValue.zPosition = 50
        phaseValue.horizontalAlignmentMode = .left
        addChild(phaseValue)
        hudPhaseValueLabel = phaseValue

        let maxLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        maxLabel.text = usesMinimalWallHUD ? "" : "BEST"
        maxLabel.fontSize = usesMinimalWallHUD ? 8 : 9
        maxLabel.fontColor = UIColor(white: 1.0, alpha: usesMinimalWallHUD ? 0.22 : 0.28)
        maxLabel.position = CGPoint(
            x: usesMinimalWallHUD ? size.width * 0.78 : size.width * 0.73,
            y: usesMinimalWallHUD ? size.height * Tunables.wallReboundBandYRatio + 44 : size.height * 0.915
        )
        maxLabel.zPosition = 50
        maxLabel.horizontalAlignmentMode = .center
        addChild(maxLabel)
        hudMaxLabel = maxLabel

        let maxValue = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        maxValue.text = usesMinimalWallHUD ? "" : "x0"
        maxValue.fontSize = usesMinimalWallHUD ? 12 : 14
        maxValue.fontColor = UIColor(white: 1.0, alpha: usesMinimalWallHUD ? 0.62 : 0.78)
        maxValue.position = CGPoint(
            x: usesMinimalWallHUD ? size.width * 0.78 : size.width * 0.73,
            y: usesMinimalWallHUD ? size.height * Tunables.wallReboundBandYRatio + 26 : size.height * 0.889
        )
        maxValue.zPosition = 50
        maxValue.horizontalAlignmentMode = .center
        addChild(maxValue)
        hudMaxValueLabel = maxValue

        let score = SKLabelNode(fontNamed: "AvenirNext-Bold")
        score.text = "0"
        score.fontSize = usesMinimalWallHUD ? 24 : 46
        score.fontColor = usesMinimalWallHUD
            ? UIColor(white: 1.0, alpha: 0.92)
            : .white
        score.position = CGPoint(
            x: size.width / 2,
            y: usesMinimalWallHUD
                ? size.height * Tunables.minimalHUDScoreYRatio
                : size.height * 0.875
        )
        score.zPosition = 50
        score.horizontalAlignmentMode = .center
        addChild(score)
        scoreLabel = score

        if usesMinimalWallHUD {
            caption.alpha = 0
            phaseLabel.alpha = 0
            phaseValue.alpha = 0
            caption.isHidden = true
            phaseLabel.isHidden = true
            phaseValue.isHidden = true
            maxLabel.alpha = 0
            maxValue.alpha = 0
            maxLabel.isHidden = true
            maxValue.isHidden = true
        }

        let combo = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        combo.text = ""
        combo.fontSize = usesMinimalWallHUD ? 14 : 17
        combo.fontColor = UIColor(white: 1, alpha: usesMinimalWallHUD ? 0.58 : 0.68)
        combo.position = CGPoint(
            x: usesMinimalWallHUD ? size.width * 0.22 : size.width / 2,
            y: usesMinimalWallHUD
                ? size.height * Tunables.wallReboundBandYRatio + 36
                : size.height * 0.838
        )
        combo.zPosition = 50
        combo.horizontalAlignmentMode = .center
        addChild(combo)
        comboLabel = combo

        let time = SKLabelNode(fontNamed: "AvenirNext-Medium")
        time.text = usesMinimalWallHUD ? "" : "3:00"
        time.fontSize = 13
        time.fontColor = UIColor(white: 1, alpha: 0.56)
        time.position = CGPoint(x: size.width / 2, y: size.height * 0.918)
        time.zPosition = 50
        time.horizontalAlignmentMode = .center
        if usesMinimalWallHUD {
            time.alpha = 0
            time.isHidden = true
        }
        addChild(time)
        timeLabel = time

        let phaseBanner = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        phaseBanner.text = "WARM-UP"
        phaseBanner.fontSize = 20
        phaseBanner.fontColor = UIColor(red: 0.95, green: 0.92, blue: 0.72, alpha: 0)
        phaseBanner.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        phaseBanner.zPosition = 55
        phaseBanner.horizontalAlignmentMode = .center
        phaseBanner.isHidden = usesMinimalWallHUD
        addChild(phaseBanner)
        phaseBannerLabel = phaseBanner

        let bottomPlate = SKShapeNode(
            rectOf: CGSize(width: min(size.width * 0.74, 328), height: 40),
            cornerRadius: 20
        )
        bottomPlate.fillColor = UIColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 0.34)
        bottomPlate.strokeColor = UIColor(white: 1.0, alpha: 0.12)
        bottomPlate.lineWidth = 1
        bottomPlate.glowWidth = 4
        bottomPlate.position = CGPoint(x: size.width / 2, y: size.height * 0.14)
        bottomPlate.zPosition = 54
        bottomPlate.alpha = 0
        addChild(bottomPlate)
        instructionPlate = bottomPlate
        if usesMinimalWallHUD {
            bottomPlate.isHidden = true
        }

        let instruction = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        instruction.text = usesMinimalWallHUD ? "" : "Swipe up on the side the ball is arriving"
        instruction.fontSize = 15
        instruction.fontColor = UIColor(white: 1, alpha: 0.82)
        instruction.position = CGPoint(x: size.width / 2, y: size.height * 0.14)
        instruction.zPosition = 55
        instruction.horizontalAlignmentMode = .center
        instruction.verticalAlignmentMode = .center
        instruction.alpha = 0
        addChild(instruction)
        instructionLabel = instruction
        if usesMinimalWallHUD {
            instruction.isHidden = true
        }
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
        recenterCameraIfIdle()

        let trackTime = currentTime - startTime
        currentTimeSnapshot = currentTime
        currentTrackTime = max(0, trackTime)

        if !sessionEnded, !isCountingDown, sessionMode == .phasedMatch {
            flow?.update(trackTime: currentTrackTime, combo: combo)
            if let profile = flow?.currentProfile() {
                // Travel time scales per phase — warm-up balls drift in,
                // breaker balls snap through. Update before the spawner ticks
                // so new spawns get the right horizon.
                currentTravelSeconds = Tunables.ballTravelSeconds
                    * profile.travelScalar
                    * racketTuning.travelScalar
                    * matchPace.travelScalar
                spawner?.travelSeconds = currentTravelSeconds
                currentBPM = profile.bpm
            }
            spawner?.tick(trackTime: currentTrackTime)
        } else if !sessionEnded, !isCountingDown, sessionMode == .wallRally {
            currentBPM = wallTempoBPM(for: matchPace)
            currentTravelSeconds = wallTravelSeconds()
            if activeBalls.isEmpty, activeExchanges.isEmpty, pendingWallSpawnToken == nil {
                scheduleWallBall(after: 0.22)
            }
        }
        moveBalls(trackTime: currentTrackTime)
        updateLiveExchanges(currentTime: currentTime)
        updateTrackingAssist()
        updateCourtAvatar(trackTime: currentTrackTime)
        autoPlayWallBallIfNeeded()
        cullMissedBalls()
        updateTimeLabel(trackTime: currentTrackTime)
        updateInstructionLabel(trackTime: currentTrackTime)
        pulseOnBeatIfDue(currentTime: currentTime)

        if sessionMode == .phasedMatch,
           !sessionEnded,
           currentTrackTime >= sessionDurationSeconds,
           activeBalls.isEmpty {
            completeSession()
        }
    }

    private func recenterCameraIfIdle() {
        guard let cameraNode else { return }
        let isAnimatingCamera =
            cameraNode.action(forKey: "shake") != nil ||
            cameraNode.action(forKey: "nudge") != nil ||
            cameraNode.action(forKey: "drift") != nil
        guard !isAnimatingCamera else { return }
        if cameraNode.position != cameraHomePosition {
            cameraNode.position = cameraHomePosition
        }
    }

    private func autoPlayWallBallIfNeeded() {
        guard autoPlayEnabled, sessionMode == .wallRally, !sessionEnded, !isCountingDown else { return }
        guard let ball = primaryWallBall() else { return }
        guard ball.effectiveSpawnTime != lastAutoPlaySpawnTime else { return }
        let triggerTime = ball.effectiveArrivalTime - 0.02
        guard currentTrackTime >= triggerTime else { return }
        lastAutoPlaySpawnTime = ball.effectiveSpawnTime
        swingVisualLane = ball.lane
        swingVisualIntent = .drive
        swingVisualReach = 150
        swingVisualImpactUntil = currentTimeSnapshot + 0.28
        resolveSwing(
            lane: ball.lane,
            swingSpeed: Tunables.swingFastVelocity * 1.2,
            swingIntent: .drive,
            strokeSide: strokeSide(for: ball.lane)
        )
    }

    /// Throbs the strike line on every quarter-note tick of the current
    /// beatmap BPM. The pulse is short (`alpha`-only animation, no
    /// position) so it never visually conflicts with shake or frame-stop.
    private func pulseOnBeatIfDue(currentTime: TimeInterval) {
        guard !sessionEnded, currentBPM > 0, strikeLine != nil else { return }
        // Ball-approach pulse owns the strike line while a feed is inbound.
        guard activeBalls.isEmpty else { return }
        let beatSeconds = 60.0 / currentBPM
        if currentTime - lastBeatTime >= beatSeconds {
            lastBeatTime = currentTime
            let beatColor = combo > 1
                ? comboAccentColor(for: combo)
                : bannerColor(for: flow?.currentPhase ?? .exchange)
            strikeLine.fillColor = beatColor.withAlphaComponent(0.82)
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
            strikeHalo?.removeAction(forKey: "beat")
            strikeHalo?.fillColor = beatColor.withAlphaComponent(0.08)
            strikeHalo?.run(.sequence([
                .group([
                    .fadeAlpha(to: 0.62, duration: 0.05),
                    .scaleX(to: 1.08, duration: 0.05)
                ]),
                .group([
                    .fadeOut(withDuration: 0.22),
                    .scaleX(to: 1.0, duration: 0.22)
                ])
            ]), withKey: "beat")
        }
    }

    private func resetSwingBodyMechanics() {
        torsoVelocity = 0
        wristSnapOffset = 0
        wristSnapAppliedAt = 0
        lastRacketContactTarget = nil
    }

    private func updateCourtAvatar(trackTime: Double) {
        guard let playerRoot else { return }

        let activeTouch = swingCurrentScene ?? swingOriginScene
        let idleBreath = CGFloat(sin(trackTime * (Double.pi * 2.0 / Tunables.avatarBreathingPeriodSeconds)))
        let recoveryProgressValue = recoveryProgress(at: trackTime)
        let impactProgress = max(0, min(1, (swingVisualImpactUntil - currentTimeSnapshot) / 0.26))
        let swingPhase = max(0, min(1, 1 - impactProgress))
        let focusLane = sessionMode == .wallRally ? wallFocusLane() : swingVisualLane
        let focusBall = sessionMode == .wallRally ? nearestBall(in: focusLane, around: currentTrackTime) : nil
        let approachProgress = max(
            impactProgress,
            focusBall?.approachToStrike(at: currentTrackTime) ?? 0
        )
        let footworkUrgency = sessionMode == .wallRally
            ? min(1, approachProgress * 1.16 + wallOpeningForgivenessBoost() * 0.06)
            : impactProgress
        let desiredX: CGFloat
        if sessionMode == .wallRally {
            let laneTarget = wallStanceTargetX(for: focusLane)
            let center = size.width / 2
            let laneBlend = min(Tunables.footworkLaneBlendMax, max(0, footworkUrgency - 0.20) * 0.62)
            desiredX = center + (laneTarget - center) * laneBlend
        } else if let activeTouch {
            let clamped = min(size.width * 0.78, max(size.width * 0.22, activeTouch.x))
            desiredX = clamped
        } else {
            desiredX = size.width / 2 + recoveryOffsetX(at: trackTime) + sin(trackTime * 0.8) * 10
        }
        let sideCommit = max(
            0,
            min(1, (footworkUrgency - Tunables.footworkSideCommitTrigger) / max(0.001, 1 - Tunables.footworkSideCommitTrigger))
        )
        let committedSide: CGFloat = focusLane == .right ? 1 : -1
        let footworkRootOffset = committedSide * Tunables.footworkRootLoadShiftPoints * sideCommit
        let anticipation = max(0, min(1, (betweenPointLiftUntil - currentTimeSnapshot) / 0.6))
        let movementBlend: CGFloat = sessionMode == .wallRally ? 0.30 + footworkUrgency * 0.18 : 0.18
        playerRoot.position.x += ((desiredX + footworkRootOffset) - playerRoot.position.x) * movementBlend
        playerRoot.position.y = size.height * Tunables.gameplayPlayerRootYRatio - anticipation * 0.65
        let splitCompression = sessionMode == .wallRally ? footworkUrgency * (1 - impactProgress) * 0.025 : 0

        if sessionMode == .wallRally, impactProgress < 0.08 {
            swingVisualLane = focusLane
        }
        let leaningRight = swingVisualLane == .right
        let leanDirection: CGFloat = leaningRight ? 1 : -1
        let reach = swingVisualReach * (0.22 + (1 - impactProgress) * 0.78)
        let contactFlash = max(0, (contactFlashUntil - currentTimeSnapshot) / 0.16)
        let qualityFlash = max(0, (recentContactUntil - currentTimeSnapshot) / 0.22)
        let pose = currentPoseState(
            activeTouch: activeTouch,
            impactProgress: impactProgress,
            recoveryProgress: recoveryProgressValue
        )
        let idleShoulder = sin(currentTrackTime * 2.1) * 0.03
        let idleHeadLift = sin(currentTrackTime * 1.7) * 2.2
        let liveContactTarget = focusBall?.position ?? lastRacketContactTarget.map {
            CGPoint(x: $0.x + playerRoot.position.x, y: $0.y + playerRoot.position.y)
        }
        let localRacketContactTarget = liveContactTarget.map {
            CGPoint(x: $0.x - playerRoot.position.x, y: $0.y - playerRoot.position.y)
        }
        let targets = poseTargets(
            for: pose,
            leanDirection: leanDirection,
            reach: reach,
            recoveryProgress: recoveryProgressValue,
            anticipationProgress: footworkUrgency,
            swingPhase: swingPhase,
            racketContactTarget: localRacketContactTarget
        )

        // ── Split-step: detect rising edge of approachProgress crossing trigger ──
        let splitTrigger = Tunables.splitStepApproachTrigger
        if approachProgress >= splitTrigger && prevApproachProgress < splitTrigger && splitStepUntil < currentTimeSnapshot {
            splitStepUntil = currentTimeSnapshot + Tunables.splitStepDuration
        }
        prevApproachProgress = approachProgress
        let splitPhaseRaw = max(0, min(1, (splitStepUntil - currentTimeSnapshot) / Tunables.splitStepDuration))
        // Triangle wave: 0→1→0 over the duration (rises for first half, falls for second)
        let splitStepLift = Tunables.splitStepHeight * (1 - abs(splitPhaseRaw * 2 - 1))
        let splitStepLanding = splitPhaseRaw > 0 ? max(0, 1 - splitStepLift / max(0.001, Tunables.splitStepHeight)) : 0

        let footLoad = max(0, 1 - swingPhase / Tunables.swingLoadPhaseEnd)
        let footContact = max(0, 1 - abs(swingPhase - Tunables.swingContactPhaseCenter) / Tunables.swingContactPhaseRadius)
        let footFollowRaw = max(0, min(1, (swingPhase - Tunables.swingContactPhaseEnd) / (1 - Tunables.swingContactPhaseEnd)))
        let footFollow = 1 - pow(1 - footFollowRaw, Tunables.followEaseOutPow)

        // ── Weight side from pose ──
        let targetWeightSide: CGFloat
        switch pose {
        case .forehandClean, .stretchForehand: targetWeightSide = 1
        case .backhandClean, .stretchBackhand: targetWeightSide = -1
        default:
            targetWeightSide = sideCommit > 0.02 ? committedSide : 0
        }
        weightSide += (targetWeightSide - weightSide) * Tunables.footworkWeightShiftBlend

        // ── Foot vertical offsets ──
        // Non-planted foot lifts on load, planted foot stomps at contact
        let footRecoveryProgress = footContactTime > 0
            ? max(0, min(1, (currentTimeSnapshot - footContactTime) / Tunables.footRecoveryDuration))
            : 1.0
        let plantPressure = min(1, abs(weightSide)) * max(footLoad * 0.55, footContact + contactFlash)
        let pushLift = Tunables.weightTransferLiftPt * (0.65 * footLoad + 0.45 * footFollow) * abs(weightSide)
        let stompFoot = Tunables.footStompPt * plantPressure
        // Lead foot plants on forehand; trail foot plants on backhand.
        let leadFootY = splitStepLift + (weightSide > 0 ? -stompFoot : pushLift)
        let trailFootY = splitStepLift + (weightSide < 0 ? -stompFoot : pushLift)

        let loadCrouch = Tunables.footworkLoadCrouchScale * abs(weightSide) * footLoad
        let contactCrouch = Tunables.footworkContactCompressionScale * footContact
        let landingCrouch = Tunables.footworkSplitLandCompression * splitStepLanding
        playerRoot.yScale += ((1 - splitCompression - loadCrouch - contactCrouch - landingCrouch) - playerRoot.yScale) * 0.12

        // ── Torso velocity accumulation (load) → release (contact) ──
        let isLoadPhase    = swingPhase < Tunables.swingLoadPhaseEnd && impactProgress > 0.02
        let isContactPhase = swingPhase >= Tunables.swingLoadPhaseEnd && swingPhase < Tunables.swingContactPhaseEnd && impactProgress > 0.02
        let storedTorsoLoad = torsoVelocity
        if isLoadPhase {
            let torsoTarget = targets.torsoRotation
            torsoVelocity += (torsoTarget - torsoVelocity) * Tunables.torsoVelocityAccumRate
        } else if isContactPhase {
            torsoVelocity *= (1 - Tunables.torsoVelocityDecayRate)
        } else {
            torsoVelocity *= 0.85
        }
        let torsoUncoilRelease = isContactPhase
            ? -storedTorsoLoad * Tunables.torsoContactUncoilMultiplier
            : 0
        let effectiveTorsoRotation = targets.torsoRotation + torsoUncoilRelease

        // ── Wrist-snap decay ──
        let wristSnapAge = currentTimeSnapshot - wristSnapAppliedAt
        if wristSnapAppliedAt > 0 {
            if wristSnapAge <= Tunables.wristSnapHoldSeconds {
                wristSnapOffset = Tunables.wristSnapAmplitude
            } else {
                wristSnapOffset = Tunables.wristSnapAmplitude
                    * exp(-CGFloat(wristSnapAge - Tunables.wristSnapHoldSeconds) * Tunables.wristSnapDecayRate)
            }
        } else {
            wristSnapOffset = 0
        }
        if wristSnapOffset < 0.5 { wristSnapOffset = 0 }

        // Hit-stop: when we just registered a perfect/great contact, nearly freeze
        // all pose blends for ~2 frames so the impact frame "holds" visibly.
        let isHitStop = currentTimeSnapshot < hitStopUntil
        let poseBlend: CGFloat = isHitStop ? Tunables.hitStopBlendFraction : 1.0

        // Torso is the initiator — blends fastest (kinetic chain origin)
        playerTorso.zRotation += (effectiveTorsoRotation - playerTorso.zRotation) * 0.24 * poseBlend
        playerTorso.xScale += ((1 + abs(idleShoulder) * 0.03) - playerTorso.xScale) * 0.08
        playerTorso.yScale += ((1 + idleBreath * Tunables.avatarBreathingScaleAmplitude) - playerTorso.yScale) * 0.08
        // Pelvis follows torso with a slight lag — hips lead then stabilise
        playerPelvis.zRotation += ((effectiveTorsoRotation * 0.52) - playerPelvis.zRotation) * 0.22
        playerPelvis.position.x += ((targets.headX * 0.10) - playerPelvis.position.x) * 0.12
        playerHead.zRotation += (targets.headRotation - playerHead.zRotation) * 0.18
        playerHead.position.x += (targets.headX - playerHead.position.x) * 0.14
        let gameplayScale: CGFloat = courtAvatarScale
        let baseHeadY = (courtAvatarLayout?.headY ?? 186) + 2 * gameplayScale + idleHeadLift
        let baseBackHairY = (courtAvatarLayout?.headY ?? 186) + 1 * gameplayScale + idleHeadLift * 0.42
        let baseHairY = (courtAvatarLayout?.hairY ?? 198) + 12 * gameplayScale + idleHeadLift * 0.55
        playerHead.position.y += (baseHeadY - playerHead.position.y) * 0.12
        playerNeck.zRotation += (targets.headRotation * 0.6 - playerNeck.zRotation) * 0.16
        playerBackHair.zRotation += (targets.headRotation * 0.50 - playerBackHair.zRotation) * 0.12
        playerBackHair.position.x += ((targets.headX * 0.42) - playerBackHair.position.x) * 0.10
        playerBackHair.position.y += (baseBackHairY - playerBackHair.position.y) * 0.10
        playerHair.zRotation += (targets.headRotation * 0.72 - playerHair.zRotation) * 0.14
        playerHair.position.x += ((targets.headX * 0.65) - playerHair.position.x) * 0.12
        playerHair.position.y += (baseHairY - playerHair.position.y) * 0.1

        let faceY = baseHeadY - 3 * gameplayScale
        let eyeY = baseHeadY + 2.2 * gameplayScale
        let browY = baseHeadY + 8.2 * gameplayScale
        playerLeftEye.position.x += ((targets.headX - 8.2 * gameplayScale) - playerLeftEye.position.x) * 0.14
        playerLeftEye.position.y += (eyeY - playerLeftEye.position.y) * 0.14
        playerRightEye.position.x += ((targets.headX + 8.2 * gameplayScale) - playerRightEye.position.x) * 0.14
        playerRightEye.position.y += (eyeY - playerRightEye.position.y) * 0.14
        playerLeftBrow.position.x += ((targets.headX - 8.5 * gameplayScale) - playerLeftBrow.position.x) * 0.14
        playerLeftBrow.position.y += (browY - playerLeftBrow.position.y) * 0.14
        playerRightBrow.position.x += ((targets.headX + 8.5 * gameplayScale) - playerRightBrow.position.x) * 0.14
        playerRightBrow.position.y += (browY - playerRightBrow.position.y) * 0.14
        playerLeftBrow.zRotation += ((targets.headRotation * 0.08) - playerLeftBrow.zRotation) * 0.12
        playerRightBrow.zRotation += ((targets.headRotation * 0.08) - playerRightBrow.zRotation) * 0.12
        playerNose.position.x += ((targets.headX * 0.55) - playerNose.position.x) * 0.14
        playerNose.position.y += ((baseHeadY - 2.2 * gameplayScale) - playerNose.position.y) * 0.14
        playerMouth?.position.x += (targets.headX * 0.35 - (playerMouth?.position.x ?? 0)) * 0.14
        playerMouth?.position.y += (faceY - (playerMouth?.position.y ?? 0)) * 0.14
        playerMouth?.zRotation += ((RallyAvatarRebuildDefaults.Face.smileRotationDegrees * .pi / 180) + targets.headRotation * 0.2 - (playerMouth?.zRotation ?? 0)) * 0.12
        playerLeftLens?.position.x += (targets.headX - (playerLeftLens?.position.x ?? 0)) * 0.14
        playerLeftLens?.position.y += (baseHeadY - (playerLeftLens?.position.y ?? 0)) * 0.12
        playerRightLens?.position.x += (targets.headX - (playerRightLens?.position.x ?? 0)) * 0.14
        playerRightLens?.position.y += (baseHeadY - (playerRightLens?.position.y ?? 0)) * 0.12
        playerGlassesBridge?.position.x += (targets.headX * 0.5 - (playerGlassesBridge?.position.x ?? 0)) * 0.14
        playerGlassesBridge?.position.y += (baseHeadY - (playerGlassesBridge?.position.y ?? 0)) * 0.12
        if let leftLens = playerLeftLens, let leftTemple = playerLeftTemple {
            leftTemple.position = CGPoint(x: leftLens.position.x - 11 * (avatarAppearance?.bodyScale ?? 1), y: leftLens.position.y)
        }
        if let rightLens = playerRightLens, let rightTemple = playerRightTemple {
            rightTemple.position = CGPoint(x: rightLens.position.x + 11 * (avatarAppearance?.bodyScale ?? 1), y: rightLens.position.y)
        }

        let presentationIdle = impactProgress < 0.04 && pose == .ready
        let depthTarget: CGFloat = presentationIdle ? 0.98 : 1.0
        let yawTarget: CGFloat = 0
        let isBackhandPose = pose == .backhandClean || pose == .stretchBackhand
        playerRoot.zRotation += (yawTarget + effectiveTorsoRotation * 0.16 - playerRoot.zRotation) * 0.1
        playerRoot.xScale += (depthTarget + splitCompression * 0.7 - playerRoot.xScale) * 0.12

        let stanceWiden = Tunables.footworkStanceWidenPoints * max(sideCommit, footLoad * 0.72)
        let outsidePlant = Tunables.footworkOutsidePlantPoints * abs(weightSide) * max(footLoad * 0.7, footContact)
        let insidePush = Tunables.footworkInsidePushPoints * abs(weightSide) * footFollow
        let leadLegXTarget = targets.leadLegX
            + stanceWiden
            + (weightSide > 0 ? outsidePlant : -insidePush)
        let trailLegXTarget = targets.trailLegX
            - stanceWiden
            + (weightSide < 0 ? -outsidePlant : insidePush)
        let leadPlantRotation = weightSide > 0
            ? Tunables.footworkOutsideToeOutRadians * max(footLoad, footContact)
            : Tunables.footworkRecoveryToeDragRadians * footFollow
        let trailPlantRotation = weightSide < 0
            ? -Tunables.footworkOutsideToeOutRadians * max(footLoad, footContact)
            : -Tunables.footworkRecoveryToeDragRadians * footFollow

        playerLeadLeg.zRotation += ((targets.leadLegRotation + anticipation * 0.08 + leadPlantRotation * 0.35) - playerLeadLeg.zRotation) * 0.18
        playerTrailLeg.zRotation += ((targets.trailLegRotation - anticipation * 0.08 + trailPlantRotation * 0.35) - playerTrailLeg.zRotation) * 0.18
        playerLeadLeg.position.x += (leadLegXTarget - playerLeadLeg.position.x) * 0.18
        playerTrailLeg.position.x += (trailLegXTarget - playerTrailLeg.position.x) * 0.18

        let leadLegHeight = (courtAvatarLayout?.legHeight ?? 108) * 0.74
        let trailLegHeight = (courtAvatarLayout?.trailLegHeight ?? 102) * 0.74
        let leadShoeTarget = CGPoint(
            x: leadLegXTarget,
            y: (courtAvatarLayout?.legY ?? 32) - leadLegHeight * 0.51
        )
        let trailShoeTarget = CGPoint(
            x: trailLegXTarget,
            y: (courtAvatarLayout?.legY ?? 32) - trailLegHeight * 0.51
        )
        playerLeadShoe.position.x += (leadShoeTarget.x - playerLeadShoe.position.x) * 0.18
        playerLeadShoe.position.y += ((leadShoeTarget.y + leadFootY) - playerLeadShoe.position.y) * 0.18
        playerTrailShoe.position.x += (trailShoeTarget.x - playerTrailShoe.position.x) * 0.18
        playerTrailShoe.position.y += ((trailShoeTarget.y + trailFootY) - playerTrailShoe.position.y) * 0.18
        playerLeadShoe.zRotation += ((targets.leadLegRotation * 0.12 + leadPlantRotation) - playerLeadShoe.zRotation) * 0.20
        playerTrailShoe.zRotation += ((targets.trailLegRotation * 0.12 + trailPlantRotation) - playerTrailShoe.zRotation) * 0.20

        // Kinetic chain: arm blends SLOWER during load (torso coils first), faster at contact/follow
        // isLoadPhase / isContactPhase already computed above
        let armLoadBlend: CGFloat    = isLoadPhase    ? 0.14 : (isContactPhase ? 0.34 : 0.22)
        let armRotBlend: CGFloat     = isLoadPhase    ? 0.16 : (isContactPhase ? 0.36 : 0.24)
        let racketLoadBlend: CGFloat = isLoadPhase    ? 0.12 : (isContactPhase ? 0.38 : 0.24)

        playerLeadArm.zRotation += ((targets.leadArmRotation + idleShoulder - anticipation * 0.04) - playerLeadArm.zRotation) * armRotBlend * poseBlend
        playerTrailArm.zRotation += ((targets.trailArmRotation - idleShoulder * 0.8 + anticipation * 0.04) - playerTrailArm.zRotation) * (isBackhandPose ? armRotBlend * 1.1 : armLoadBlend) * poseBlend
        playerLeadArm.position.x += (targets.leadArmX - playerLeadArm.position.x) * armLoadBlend * poseBlend
        playerLeadArm.position.y += (targets.leadArmY - playerLeadArm.position.y) * armLoadBlend * poseBlend
        playerTrailArm.position.x += (targets.trailArmX - playerTrailArm.position.x) * (isBackhandPose ? armLoadBlend * 1.15 : armLoadBlend) * poseBlend
        playerTrailArm.position.y += (targets.trailArmY - playerTrailArm.position.y) * (isBackhandPose ? armLoadBlend * 1.15 : armLoadBlend) * poseBlend

        let qualityPose = qualityImpactProfile()
        // Racket lags behind arm during load — hand+racket are the last link in the chain
        playerRacketHandle.zRotation += ((targets.racketHandleRotation + qualityPose.handleRotation * qualityFlash) - playerRacketHandle.zRotation) * racketLoadBlend * poseBlend
        // Racket face angle applied additively on top of head rotation — wrist cock / topspin / slice
        playerRacketHead.zRotation += ((targets.racketHeadRotation + targets.racketFaceAngle + qualityPose.headRotation * qualityFlash) - playerRacketHead.zRotation) * racketLoadBlend * poseBlend
        playerRacketHandle.position.x += ((targets.racketHandleX + qualityPose.handleX * qualityFlash) - playerRacketHandle.position.x) * racketLoadBlend * poseBlend
        playerRacketHandle.position.y += ((targets.racketHandleY + qualityPose.handleY * qualityFlash) - playerRacketHandle.position.y) * racketLoadBlend * poseBlend
        // Wrist-snap offset: racket head overshoots along the swing axis at contact then decays
        let snapAxisX: CGFloat = isBackhandPose ? Tunables.backhandWristSnapAxisX : Tunables.forehandWristSnapAxisX
        let snapAxisY: CGFloat = isBackhandPose ? Tunables.backhandWristSnapAxisY : Tunables.forehandWristSnapAxisY
        playerRacketHead.position.x += ((targets.racketHeadX + qualityPose.headX * qualityFlash + wristSnapOffset * snapAxisX) - playerRacketHead.position.x) * racketLoadBlend * poseBlend
        playerRacketHead.position.y += ((targets.racketHeadY + qualityPose.headY * qualityFlash + wristSnapOffset * snapAxisY) - playerRacketHead.position.y) * racketLoadBlend * poseBlend

        let gripAngle = playerRacketHandle.zRotation + CGFloat.pi / 2
        let gripDX = cos(gripAngle)
        let gripDY = sin(gripAngle)
        let gripLower = CGPoint(
            x: playerRacketHandle.position.x - gripDX * 8.5 * gameplayScale,
            y: playerRacketHandle.position.y - gripDY * 8.5 * gameplayScale
        )
        let gripUpper = CGPoint(
            x: playerRacketHandle.position.x + gripDX * 8.5 * gameplayScale,
            y: playerRacketHandle.position.y + gripDY * 8.5 * gameplayScale
        )
        let leadHandTarget = gripLower
        let trailHandTarget = isBackhandPose
            ? gripUpper
            : CGPoint(x: targets.trailArmX - 8 * leanDirection, y: targets.trailArmY - 24 * gameplayScale)
        let handBlend: CGFloat = isBackhandPose ? 0.46 : 0.34
        playerLeadHand.position.x += (leadHandTarget.x - playerLeadHand.position.x) * handBlend
        playerLeadHand.position.y += (leadHandTarget.y - playerLeadHand.position.y) * handBlend
        playerTrailHand.position.x += (trailHandTarget.x - playerTrailHand.position.x) * handBlend
        playerTrailHand.position.y += (trailHandTarget.y - playerTrailHand.position.y) * handBlend
        playerTrailHand.alpha += ((isBackhandPose ? 1.0 : 0.68) - playerTrailHand.alpha) * 0.24

        playerLeadArm.position.x += ((playerLeadHand.position.x - 8 * leanDirection * gameplayScale) - playerLeadArm.position.x) * 0.18
        playerLeadArm.position.y += ((playerLeadHand.position.y - 31 * gameplayScale) - playerLeadArm.position.y) * 0.18
        if isBackhandPose {
            playerLeadArm.position.x += ((playerLeadHand.position.x + 8 * gameplayScale) - playerLeadArm.position.x) * 0.18
            playerLeadArm.position.y += ((playerLeadHand.position.y - 35 * gameplayScale) - playerLeadArm.position.y) * 0.18
            playerTrailArm.position.x += ((playerTrailHand.position.x - 8 * gameplayScale) - playerTrailArm.position.x) * 0.22
            playerTrailArm.position.y += ((playerTrailHand.position.y - 33 * gameplayScale) - playerTrailArm.position.y) * 0.22
            playerLeadArm.zRotation += ((playerRacketHandle.zRotation - 0.18) - playerLeadArm.zRotation) * 0.16
            playerTrailArm.zRotation += ((playerRacketHandle.zRotation + 0.20) - playerTrailArm.zRotation) * 0.18
        } else {
            playerTrailArm.position.x += ((playerTrailHand.position.x + 7 * leanDirection * gameplayScale) - playerTrailArm.position.x) * 0.12
            playerTrailArm.position.y += ((playerTrailHand.position.y - 28 * gameplayScale) - playerTrailArm.position.y) * 0.12
        }

        // ── Shoulder sleeve caps: track the top (shoulder end) of each arm ──
        // Arm shape is centered — shoulder is at armCenter + rotate(0, halfLen)
        let leadHalfLen: CGFloat = 63.0 * 0.5 * gameplayScale
        let trailHalfLen: CGFloat = 62.0 * 0.5 * gameplayScale
        let leadAng = playerLeadArm.zRotation
        let trailAng = playerTrailArm.zRotation
        let leadShoulderX = playerLeadArm.position.x - sin(leadAng) * leadHalfLen
        let leadShoulderY = playerLeadArm.position.y + cos(leadAng) * leadHalfLen
        let trailShoulderX = playerTrailArm.position.x - sin(trailAng) * trailHalfLen
        let trailShoulderY = playerTrailArm.position.y + cos(trailAng) * trailHalfLen
        playerLeadSleeve.position.x  += (leadShoulderX  - playerLeadSleeve.position.x)  * 0.52
        playerLeadSleeve.position.y  += (leadShoulderY  - playerLeadSleeve.position.y)  * 0.52
        playerTrailSleeve.position.x += (trailShoulderX - playerTrailSleeve.position.x) * 0.52
        playerTrailSleeve.position.y += (trailShoulderY - playerTrailSleeve.position.y) * 0.52

        let swingPalette = swingTrailPalette(intent: swingVisualIntent, lane: swingVisualLane)
        let flashColor = contactFlash > 0.01
            ? UIColor.white.withAlphaComponent(0.35 + contactFlash * 0.55)
            : swingPalette.glow.withAlphaComponent(0.22)
        let liveIntentEnergy = min(1, impactProgress * 0.72 + qualityFlash * 0.58 + anticipation * 0.3)
        playerRacketHead.glowWidth = 0.35 + contactFlash * 8 + qualityPose.glowBoost * qualityFlash * 0.26 + liveIntentEnergy * 1.1
        playerRacketHead.fillColor = swingPalette.glow.withAlphaComponent(
            0.006 + liveIntentEnergy * 0.010 + contactFlash * 0.035 + qualityPose.fillBoost * qualityFlash * 0.12
        )
        playerRacketHead.strokeColor = playerRacketBaseColor
            .blended(withFraction: CGFloat(contactFlash * 0.6), of: .white)?
            .blended(withFraction: CGFloat(liveIntentEnergy * 0.4), of: swingPalette.core)
            ?? playerRacketBaseColor
        playerRacketHandle.strokeColor = flashColor
        playerRacketHandle.fillColor = swingPalette.core.withAlphaComponent(0.74 + contactFlash * 0.16)
        playerLeadHand.fillColor = playerLeadArm.fillColor
        playerTrailHand.fillColor = playerTrailArm.fillColor
        playerRacketStrings.forEach { string in
            string.alpha = 0.38 + contactFlash * 0.44 + qualityPose.stringBoost * qualityFlash
            string.fillColor = UIColor.white
                .blended(withFraction: CGFloat(liveIntentEnergy * 0.34), of: swingPalette.tip)?
                .withAlphaComponent(0.22 + contactFlash * 0.46 + qualityPose.stringBoost * qualityFlash * 0.8)
                ?? UIColor.white.withAlphaComponent(0.22 + contactFlash * 0.46 + qualityPose.stringBoost * qualityFlash * 0.8)
        }
        let liveHairColor = avatarAppearance?.hairUIColor ?? UIColor(red: 0.008, green: 0.008, blue: 0.012, alpha: 0.98)
        playerBackHair.fillColor = liveHairColor.blended(withFraction: CGFloat(contactFlash * 0.12), of: .white) ?? liveHairColor
        playerHair.fillColor = liveHairColor.blended(withFraction: CGFloat(contactFlash * 0.18), of: .white) ?? liveHairColor
        // Shadow punches outward on contact then snaps back — sells the physical weight
        let shadowContactPunch = contactFlash * 0.22
        playerShadow.xScale += ((targets.shadowXScale + shadowContactPunch) - playerShadow.xScale) * 0.18
        playerShadow.yScale += ((targets.shadowYScale + shadowContactPunch * 0.5) - playerShadow.yScale) * 0.18
        playerShadow.alpha += ((max(0.32, targets.shadowAlpha) + contactFlash * 0.22) - playerShadow.alpha) * 0.18
        // Shadow shifts laterally with weight transfer — planted foot pushes shadow toward it
        let shadowShiftTarget = weightSide * Tunables.shadowWeightShiftPt * (1 - footRecoveryProgress)
        playerShadow.position.x += (shadowShiftTarget - playerShadow.position.x) * 0.14
        playerStanceGlow.fillColor = swingPalette.glow.withAlphaComponent(
            0.014 + anticipation * 0.018 + impactProgress * 0.028 + qualityFlash * 0.030
        )
        playerStanceGlow.xScale += ((0.92 + impactProgress * 0.10 + recoveryProgressValue * 0.04) - playerStanceGlow.xScale) * 0.14
        playerStanceGlow.yScale += ((0.86 + anticipation * 0.04 + qualityFlash * 0.03) - playerStanceGlow.yScale) * 0.14
        playerStanceGlow.alpha += ((0.14 + impactProgress * 0.08 + qualityFlash * 0.06) - playerStanceGlow.alpha) * 0.12
    }

    private func qualityImpactProfile() -> (
        handleRotation: CGFloat,
        headRotation: CGFloat,
        handleX: CGFloat,
        handleY: CGFloat,
        headX: CGFloat,
        headY: CGFloat,
        glowBoost: CGFloat,
        fillBoost: CGFloat,
        stringBoost: CGFloat
    ) {
        switch recentContactQuality {
        case .perfect:
            return (0.08, 0.12, 8, 6, 12, 9, 10, 0.12, 0.22)
        case .great:
            return (0.03, 0.05, 4, 3, 6, 4, 5, 0.06, 0.12)
        case .good:
            return (-0.04, -0.07, -3, -2, -5, -3, 2, 0.03, 0.06)
        case .miss, nil:
            return (0, 0, 0, 0, 0, 0, 0, 0, 0)
        }
    }

    private func currentPoseState(activeTouch: CGPoint?, impactProgress: CGFloat, recoveryProgress: CGFloat) -> PlayerPoseState {
        if impactProgress > 0.02 {
            if swingVisualIntent == .slice {
                return .defensiveBlock
            }
            let strokeSide = strokeSide(for: swingVisualLane)
            let stretched = recoverySeverity > 0.52 || swingVisualReach > 150
            if stretched {
                return strokeSide == .forehand ? .stretchForehand : .stretchBackhand
            }
            return strokeSide == .forehand ? .forehandClean : .backhandClean
        }
        if recoveryProgress > 0.08 {
            return .recovery
        }
        if activeTouch != nil {
            return .ready
        }
        return .ready
    }

    private func poseTargets(
        for state: PlayerPoseState,
        leanDirection: CGFloat,
        reach: CGFloat,
        recoveryProgress: CGFloat,
        anticipationProgress: CGFloat,
        swingPhase: CGFloat,
        racketContactTarget: CGPoint? = nil
    ) -> PlayerPoseTargets {
        switch state {
        case .ready:
            let split = sin(currentTrackTime * 5.0) * (0.012 + anticipationProgress * 0.010)
            let breathBob = sin(currentTrackTime * 1.6) * 1.2  // gentle idle breathing lift
            let preload = anticipationProgress
            let weightShift = leanDirection * Tunables.avatarWeightShiftPoints * preload
            // Athletic ready: racket up at chest, both arms bent forward, wide knees-bent stance.
            // Trail arm crosses slightly in front of body (cradles racket throat in real tennis).
            return PlayerPoseTargets(
                torsoRotation: leanDirection * (0.025 + preload * 0.055) + split * 0.30,
                headRotation: leanDirection * (0.020 + preload * 0.040) + split * 0.16,
                headX: leanDirection * (4 + preload * 6) + weightShift * 0.10,
                // More knee bend for athletic squat
                leadLegRotation: 0.08 + split + preload * 0.10,
                trailLegRotation: -0.07 - split * 0.75 - preload * 0.09,
                leadLegX: 28 + leanDirection * (6 + preload * 7) + weightShift,
                trailLegX: -28 - leanDirection * (5 + preload * 7) + weightShift * 0.36,
                // Lead arm (racket arm): bent inward, racket throat in front of chest
                leadArmRotation: -0.46 + leanDirection * (0.08 + preload * 0.06),
                // Trail arm: NOT dangling — bent forward, hand near racket throat
                trailArmRotation: 0.20 + leanDirection * (0.06 + preload * 0.04),
                leadArmX: 28 + leanDirection * (5 + preload * 7),
                leadArmY: 124 + breathBob + preload * 5,
                trailArmX: -22 + leanDirection * (3 + preload * 4),  // pulled toward body center
                trailArmY: 122 + breathBob + preload * 3,
                // Racket centered in front of body, face open and ready
                racketHandleRotation: -0.28 + leanDirection * (0.10 + preload * 0.08),
                racketHeadRotation: -0.08 + leanDirection * (0.10 + preload * 0.10),
                racketHandleX: 40 + leanDirection * (5 + preload * 8),
                racketHandleY: 132 + breathBob + preload * 6,
                racketHeadX: 62 + leanDirection * (6 + preload * 9),
                racketHeadY: 170 + breathBob + preload * 8,
                shadowXScale: 1.04 + preload * 0.04,
                shadowYScale: 0.98 - preload * 0.02,
                shadowAlpha: 0.25 + preload * 0.04
            )
        case .forehandClean:
            let phase = max(0, min(1, swingPhase))
            let load = max(0, 1 - phase / Tunables.swingLoadPhaseEnd)
            let contact = max(0, 1 - abs(phase - Tunables.swingContactPhaseCenter) / Tunables.swingContactPhaseRadius)
            let followRaw = max(0, min(1, (phase - Tunables.swingContactPhaseEnd) / (1 - Tunables.swingContactPhaseEnd)))
            let follow = 1 - pow(1 - followRaw, Tunables.followEaseOutPow)
            let armReach = 32 + reach * 0.12

            // Kinetic-chain lag: the racket hand commits only after the torso has loaded.
            let torsoTarget = Tunables.forehandLoadTorsoRotation * load
            let torsoFrac = abs(playerTorso.zRotation) / max(0.001, abs(torsoTarget))
            let racketLagBlend = torsoFrac < Tunables.racketHandLagTorsoFrac ? 0.60 : 1.0
            let rl = racketLagBlend

            let defaultContactHeadX = 88 + armReach * 0.92
            let defaultContactHeadY = 170 + armReach * 0.08
            let contactHeadX = racketContactTarget?.x ?? defaultContactHeadX
            let contactHeadY = racketContactTarget?.y ?? defaultContactHeadY
            let handleContactX = contactHeadX - 28
            let handleContactY = contactHeadY - 30

            let faceAtContact: CGFloat = {
                switch swingVisualIntent {
                case .topspin: return Tunables.racketFaceTopspin
                case .slice:   return Tunables.racketFaceSlice
                default:       return Tunables.racketFaceFlat
                }
            }()
            let racketFaceAngle = Tunables.wristCockAngleLoad * load
                                + faceAtContact * contact
                                + (faceAtContact + Tunables.wristPronateFinal) * follow
            return PlayerPoseTargets(
                torsoRotation: Tunables.forehandLoadTorsoRotation * load
                    + 0.48 * contact                                     // chest drives explosively through ball
                    + Tunables.forehandFollowTorsoRotation * follow,
                headRotation: -0.05 * load + 0.05 * contact + 0.07 * follow,  // head stays level, eyes on ball
                headX: -10 * load + 14 * contact + 18 * follow,
                // Legs: deep knee bend on load, weight drives powerfully into front foot at contact
                leadLegRotation: 0.18 + 0.22 * load + 0.22 * contact - 0.05 * follow,
                trailLegRotation: -0.26 - 0.22 * load + 0.18 * follow,         // trail foot pivots through on follow
                leadLegX: 31 + 10 * load + 16 * contact + 4 * follow,
                trailLegX: -28 - 12 * load + 14 * follow,                      // trail foot sweeps through
                // Lead arm: coils behind torso on load, whips explosively through contact, dips into follow
                leadArmRotation: Tunables.forehandLeadArmLoadRotation * load + 0.34 * contact + 0.68 * follow + reach * 0.0013,
                // Trail arm: balance arm — extends dramatically OUT and UP during follow (key pro signature)
                trailArmRotation: 0.32 * load + 0.04 * contact - 0.58 * follow,  // sweeps wide for balance
                leadArmX: 36 + armReach * (0.28 * load + 0.66 * contact + 0.44 * follow),
                leadArmY: 128 + reach * (0.03 * load + 0.07 * contact + 0.11 * follow) + Tunables.forehandLeadShoulderFollowDip * follow,
                trailArmX: -38 + reach * 0.04 * contact - 44 * follow,          // balance arm sweeps far out
                trailArmY: 118 + reach * 0.02 + 32 * follow,                    // and lifts — classic pro balance
                racketHandleRotation: (-0.68 * load + 0.32 * contact + 0.88 * follow + reach * 0.0015) * rl,
                racketHeadRotation: -0.50 * load + 0.62 * contact + 1.08 * follow + reach * 0.0012,  // full wrist roll-over
                racketHandleX: ((50 - 26 * load) * rl) * (1 - contact) * (1 - follow)
                    + handleContactX * contact
                    + Tunables.forehandFollowHandleX * follow,
                racketHandleY: (130 + 32 * load) * (1 - contact) * (1 - follow)
                    + handleContactY * contact
                    + Tunables.forehandFollowHandleY * follow,
                racketHeadX: (74 - 40 * load) * (1 - contact) * (1 - follow)
                    + contactHeadX * contact
                    + (Tunables.forehandFollowHandleX - 28) * follow,
                racketHeadY: (162 + 26 * load) * (1 - contact) * (1 - follow)
                    + contactHeadY * contact
                    + (Tunables.forehandFollowHandleY + 52) * follow,           // racket finishes high over opposite shoulder
                shadowXScale: 1.14 + 0.12 * contact,
                shadowYScale: 0.93,
                shadowAlpha: 0.36,
                racketFaceAngle: racketFaceAngle
            )
        case .backhandClean:
            let phase = max(0, min(1, swingPhase))
            let load = max(0, 1 - phase / Tunables.swingLoadPhaseEnd)
            let contact = max(0, 1 - abs(phase - Tunables.swingContactPhaseCenter) / Tunables.swingContactPhaseRadius)
            let followRaw = max(0, min(1, (phase - Tunables.swingContactPhaseEnd) / (1 - Tunables.swingContactPhaseEnd)))
            let follow = 1 - pow(1 - followRaw, Tunables.followEaseOutPow)
            let armReach = 30 + reach * 0.12

            let defaultContactHeadX = -86 - armReach * 0.18
            let defaultContactHeadY = 178 + armReach * 0.08
            let contactHeadX = racketContactTarget?.x ?? defaultContactHeadX
            let contactHeadY = racketContactTarget?.y ?? defaultContactHeadY
            let handleContactX = contactHeadX + 26
            let handleContactY = contactHeadY - 30

            let faceAtContact: CGFloat = {
                switch swingVisualIntent {
                case .slice:   return Tunables.racketFaceSlice
                default:       return Tunables.racketFaceFlat
                }
            }()
            let racketFaceAngle = Tunables.wristCockAngleLoad * load + faceAtContact * contact + faceAtContact * 0.5 * follow
            return PlayerPoseTargets(
                // Two-hander: full shoulder coil behind ball, explosive through-rotation, high finish
                torsoRotation: Tunables.backhandLoadTorsoRotation * load
                    - 0.56 * contact                                     // drives chest through target
                    + Tunables.backhandFollowTorsoRotation * follow,
                headRotation: -0.05 * load - 0.03 * contact + 0.02 * follow,  // head level, watches ball
                headX: -28 * load - 18 * contact - 6 * follow,
                leadLegRotation: -0.26 - 0.10 * load + 0.12 * follow,
                trailLegRotation: 0.40 + 0.20 * load - 0.10 * follow,
                leadLegX: -16 - 6 * load + 8 * contact + 10 * follow,
                trailLegX: -48 - 12 * load - 6 * contact + 14 * follow,
                // Both arms drive through together (two-hander unit), then lead arm extends to finish
                leadArmRotation: -1.62 * load - 1.18 * contact - 0.48 * follow - reach * 0.0011,
                trailArmRotation: -1.48 * load - 1.08 * contact - 0.42 * follow - reach * 0.0009,
                leadArmX: -18 - armReach * (0.72 * load + 0.62 * contact + 0.58 * follow),
                leadArmY: 144 + 20 * load + reach * (0.09 * contact + 0.06 * follow),
                trailArmX: -14 - armReach * (0.62 * load + 0.52 * contact + 0.62 * follow),
                trailArmY: 148 + 18 * load + reach * (0.09 * contact + 0.06 * follow),
                racketHandleRotation: -1.74 * load - 1.38 * contact - 0.52 * follow - reach * 0.0012,
                racketHeadRotation: -1.38 * load - 0.98 * contact - 0.18 * follow - reach * 0.0010,
                racketHandleX: (-22 - armReach * 0.98 * load) * (1 - contact) * (1 - follow)
                    + handleContactX * contact
                    + Tunables.backhandFollowHandleX * follow,
                racketHandleY: (154 + 22 * load) * (1 - contact) * (1 - follow)
                    + handleContactY * contact
                    + Tunables.backhandFollowHandleY * follow,
                racketHeadX: (-48 - armReach * 1.18 * load) * (1 - contact) * (1 - follow)
                    + contactHeadX * contact
                    + Tunables.backhandFollowHeadX * follow,
                racketHeadY: (204 + 28 * load) * (1 - contact) * (1 - follow)
                    + contactHeadY * contact
                    + Tunables.backhandFollowHeadY * follow,
                shadowXScale: 1.28 + 0.06 * load,
                shadowYScale: 0.88,
                shadowAlpha: 0.38,
                racketFaceAngle: racketFaceAngle
            )
        case .stretchForehand:
            return poseTargets(
                for: .forehandClean,
                leanDirection: leanDirection,
                reach: reach + 42,
                recoveryProgress: recoveryProgress,
                anticipationProgress: anticipationProgress,
                swingPhase: swingPhase,
                racketContactTarget: racketContactTarget
            )
        case .stretchBackhand:
            return poseTargets(
                for: .backhandClean,
                leanDirection: leanDirection,
                reach: reach + 46,
                recoveryProgress: recoveryProgress,
                anticipationProgress: anticipationProgress,
                swingPhase: swingPhase,
                racketContactTarget: racketContactTarget
            )
        case .defensiveBlock:
            let armReach = 18 + reach * 0.06
            return PlayerPoseTargets(
                torsoRotation: leanDirection * 0.08,
                headRotation: leanDirection * 0.03,
                headX: leanDirection * 6,
                leadLegRotation: leanDirection * 0.04,
                trailLegRotation: -leanDirection * 0.04,
                leadLegX: 22 + leanDirection * 7,
                trailLegX: -18 - leanDirection * 5,
                leadArmRotation: -0.08 + leanDirection * 0.18,
                trailArmRotation: 0.18 + leanDirection * 0.06,
                leadArmX: 36 + armReach * 0.18,
                leadArmY: 118,
                trailArmX: -34 + leanDirection * 6,
                trailArmY: 122,
                racketHandleRotation: -0.18 + leanDirection * 0.1,
                racketHeadRotation: -0.04 + leanDirection * 0.08,
                racketHandleX: 50 + armReach * 0.30,
                racketHandleY: 122,
                racketHeadX: 70 + armReach * 0.38,
                racketHeadY: 150,
                shadowXScale: 1.05,
                shadowYScale: 1.0,
                shadowAlpha: 0.28
            )
        case .recovery:
            let direction: CGFloat = recoveryLane == .right ? 1 : -1
            let severity = max(0.2, recoverySeverity) * recoveryProgress
            return PlayerPoseTargets(
                torsoRotation: direction * 0.16 * severity,
                headRotation: direction * 0.08 * severity,
                headX: direction * 14 * severity,
                leadLegRotation: direction * 0.12 * severity,
                trailLegRotation: -direction * 0.22 * severity,
                leadLegX: 26 + direction * 14 * severity,
                trailLegX: -26 - direction * 18 * severity,
                leadArmRotation: -0.24 + direction * 0.22 * severity,
                trailArmRotation: 0.24 + direction * 0.14 * severity,
                leadArmX: 38 + direction * 18 * severity,
                leadArmY: 120 - 8 * severity,
                trailArmX: -36 + direction * 8 * severity,
                trailArmY: 124 - 4 * severity,
                racketHandleRotation: -0.28 + direction * 0.24 * severity,
                racketHeadRotation: -0.12 + direction * 0.16 * severity,
                racketHandleX: 62 + direction * 26 * severity,
                racketHandleY: 120 - 10 * severity,
                racketHeadX: 92 + direction * 28 * severity,
                racketHeadY: 166 - 14 * severity,
                shadowXScale: 1.1 + 0.06 * severity,
                shadowYScale: 0.98,
                shadowAlpha: 0.26 + 0.04 * severity
            )
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
            cleanReturnPickups: cleanReturnPickups,
            changeupWinners: changeupWinners,
            pressureHolds: pressureHolds,
            segments: segments
        )
    }

    // MARK: - Phase handling

    private func handlePhaseChange(from: MatchFlowPhase, to: MatchFlowPhase) {
        GameEventBus.shared.publish(.phaseChanged(from: from, to: to))
        if to != .pressure && to != .breaker {
            pressureExchangeStreak = 0
        }
        if to == .pressure {
            CameraShake.nudge(cameraNode, dx: 0, dy: -6, outMs: 70, backMs: 180)
        } else if to == .breaker {
            CameraShake.nudge(cameraNode, dx: 0, dy: -10, outMs: 85, backMs: 220)
        } else if to == .recovery {
            CameraShake.nudge(cameraNode, dx: 0, dy: 6, outMs: 70, backMs: 200)
        }
        background?.setMomentum(tier: comboTier(for: combo), phase: to.rawValue.lowercased(), breaking: false)
        showPhaseBanner(for: to)
        if to == .pressure {
            showInstruction("Tempo rising. Hold your shape through contact.", hold: 1.8)
        } else if to == .breaker {
            showInstruction("Breaker. Expect a sharper change of pace.", hold: 2.1)
        }
        #if DEBUG
        phaseDebugLabel?.text = "Phase: \(to.rawValue)"
        #endif
    }

    #if DEBUG
    private func installPhaseDebugLabel() {
        guard !usesMinimalWallHUD else { return }
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
        if sessionMode == .wallRally {
            timeLabel.text = "ENDLESS"
            return
        }
        // Freeze the timer at the full session length during the countdown
        // so the player doesn't see it tick down before they can even play.
        let effectiveTrackTime = isCountingDown ? 0 : trackTime
        let remaining = max(0, sessionDurationSeconds - effectiveTrackTime)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        timeLabel.text = String(format: "%d:%02d", minutes, seconds)
    }

    private func updateInstructionLabel(trackTime: Double) {
        guard let instructionLabel else { return }
        guard !isCountingDown else { return }
        if trackTime >= Tunables.openingHintSeconds, instructionLabel.alpha > 0.01 {
            instructionLabel.removeAllActions()
            instructionLabel.run(.fadeOut(withDuration: 0.35))
        }
    }

    private func moveBalls(trackTime: Double) {
        var stillAlive: [BallNode] = []
        stillAlive.reserveCapacity(activeBalls.count)

        for ball in activeBalls {
            if let reentryState = ball.reentryState {
                let frame = reentryState.frame(at: trackTime)
                if frame.handoffReady {
                    let laneDirection: CGFloat = ball.lane == .right ? 1 : -1
                    let normalization = RallyBallNormalizationState(
                        handoff: RallyBallNormalizationHandoff(
                            startTime: trackTime,
                            startPoint: frame.point,
                            strikePoint: ball.effectiveStrikePoint,
                            laneDirection: laneDirection,
                            xScale: frame.xScale,
                            yScale: frame.yScale,
                            shadowAlpha: frame.shadowAlpha
                        )
                    )
                    ball.beginNormalization(normalization)
                    _ = ball.updateNormalization(trackTime: trackTime)
                } else if frame.isComplete {
                    ball.removeFromParent()
                    continue
                } else {
                    ball.applyReentryFrame(frame, trackTime: trackTime)
                }
            } else if ball.normalizationState != nil {
                let finishedNormalization = ball.updateNormalization(trackTime: trackTime)
                if finishedNormalization {
                    let progress = max(0, min(1.18, (trackTime - ball.effectiveSpawnTime) / ball.effectiveTravelSeconds))
                    ball.updatePresentation(progress: CGFloat(progress))
                }
            } else {
                let progress = max(0, min(1.18, (trackTime - ball.effectiveSpawnTime) / ball.effectiveTravelSeconds))
                ball.updatePresentation(progress: CGFloat(progress))
            }
            stillAlive.append(ball)
        }
        activeBalls = stillAlive
    }

    private func updateLiveExchanges(currentTime: TimeInterval) {
        guard !activeExchanges.isEmpty else { return }

        var stillActive: [RallyContinuousBallExchange] = []
        stillActive.reserveCapacity(activeExchanges.count)

        for exchange in activeExchanges {
            let frame = exchange.frame(at: currentTime)
            if frame.phase == .wallApproach
                || frame.phase == .wallCompression
                || frame.phase == .wallDwell
                || frame.phase == .wallDecompression
                || frame.phase == .wallRebound {
                exchange.ball.ownershipPhase = .wallExchange
            }
            exchange.ball.applyLiveExchangeFrame(frame)

            if frame.didBeginWallImpact {
                let lane = exchange.ball.lane
                let quality = recentContactQuality ?? .good
                let stroke = strokeSide(for: lane)
                stageWallStrikeBurst(
                    at: frame.point,
                    lane: lane,
                    quality: quality
                )
                stageWallImpactPulse(
                    at: frame.point,
                    lane: lane,
                    quality: quality,
                    strokeSide: stroke
                )
            }

            if frame.isComplete {
                armBallForReentry(exchange.ball, from: frame)
            } else {
                stillActive.append(exchange)
            }
        }

        activeExchanges = stillActive
    }

    private func armBallForReentry(_ ball: BallNode, from handoff: RallyContinuousBallExchangeFrame) {
        let returnLane = ball.lane.opposite
        ball.lane = returnLane
        wallNextLane = returnLane.opposite

        let strikePoint = racketContactPoint(for: returnLane)
        let config = RallyReentryConfig.rallyDefault
        let start = currentTrackTime
        let arrival = start + config.returnTravelDuration

        ball.beginReentry(
            RallyReentryBallState(
                startTime: start,
                arrivalTime: arrival,
                strikeTime: arrival - min(config.contactRearmDelay, config.returnTravelDuration * 0.72),
                startPoint: handoff.point,
                strikePoint: strikePoint,
                config: config,
                handoffXScale: handoff.xScale,
                handoffYScale: handoff.yScale,
                handoffShadowAlpha: handoff.shadowAlpha
            )
        )

        if !activeBalls.contains(where: { $0 === ball }) {
            activeBalls.append(ball)
        }
    }

    private func updateTrackingAssist() {
        let focusLane: Lane
        if sessionMode == .wallRally {
            focusLane = wallFocusLane()
        } else if let activeTouch = swingCurrentScene ?? swingOriginScene {
            focusLane = activeTouch.x < size.width / 2 ? .left : .right
        } else {
            focusLane = swingVisualLane
        }

        let focusBall = nearestBall(in: focusLane, around: currentTrackTime)
        let partner = focusBall.flatMap { linkedDoublePartner(for: $0) }
        updateStrikeGates(focusLane: focusLane, focusBall: focusBall, partner: partner)
        updateWallReadability(focusLane: focusLane, focusBall: focusBall, partner: partner)
        for ball in activeBalls {
            let emphasis: CGFloat
            if ball === focusBall {
                emphasis = 1.0
            } else if ball === partner {
                emphasis = 0.7
            } else if ball.lane == focusLane {
                emphasis = sessionMode == .wallRally ? 0.32 + wallOpeningForgivenessBoost() * 0.12 : 0.16
            } else {
                emphasis = sessionMode == .wallRally ? 0.02 : 0
            }
            ball.setTrackingEmphasis(emphasis)
        }
    }

    private func updateStrikeGates(focusLane: Lane, focusBall: BallNode?, partner: BallNode?) {
        let leftIntensity = strikeGateIntensity(for: .left, focusLane: focusLane, focusBall: focusBall, partner: partner)
        let rightIntensity = strikeGateIntensity(for: .right, focusLane: focusLane, focusBall: focusBall, partner: partner)
        let leftApproach = strikeGateApproach(for: .left, focusBall: focusBall, partner: partner)
        let rightApproach = strikeGateApproach(for: .right, focusBall: focusBall, partner: partner)
        applyStrikeGateStyle(leftStrikeGate, lane: .left, intensity: leftIntensity, approach: leftApproach)
        applyStrikeGateStyle(rightStrikeGate, lane: .right, intensity: rightIntensity, approach: rightApproach)
        applyContactPocketStyle(leftContactPocket, lane: .left, intensity: leftIntensity, approach: leftApproach)
        applyContactPocketStyle(rightContactPocket, lane: .right, intensity: rightIntensity, approach: rightApproach)
    }

    private func strikeGateIntensity(
        for lane: Lane,
        focusLane: Lane,
        focusBall: BallNode?,
        partner: BallNode?
    ) -> CGFloat {
        if sessionMode == .wallRally {
            if focusBall?.lane == lane { return 1.0 }
            if partner?.lane == lane { return 0.58 }
            if focusLane == lane { return 0.42 + wallOpeningForgivenessBoost() * 0.12 }
            return 0.04
        }
        if focusBall?.lane == lane { return 1.0 }
        if partner?.lane == lane { return 0.76 }
        if focusLane == lane { return 0.28 }
        return 0.12
    }

    private func strikeGateApproach(
        for lane: Lane,
        focusBall: BallNode?,
        partner: BallNode?
    ) -> CGFloat {
        if let focusBall, focusBall.lane == lane {
            return focusBall.approachToStrike(at: currentTrackTime)
        }
        if let partner, partner.lane == lane {
            return partner.approachToStrike(at: currentTrackTime) * 0.92
        }
        return 0
    }

    private func applyStrikeGateStyle(_ gate: SKShapeNode?, lane: Lane, intensity: CGFloat, approach: CGFloat) {
        guard let gate else { return }
        let palette = swingTrailPalette(intent: swingVisualIntent, lane: lane)
        let live = min(1, max(intensity, approach))
        let wallBoost: CGFloat = sessionMode == .wallRally ? 1.48 : 1.0
        let quietLaneAlpha: CGFloat = sessionMode == .wallRally ? 0.06 : 0.14
        gate.alpha = min(1, quietLaneAlpha + intensity * 0.52 * wallBoost + approach * 0.32 * wallBoost)
        gate.fillColor = palette.glow.withAlphaComponent(0.03 + intensity * 0.12 * wallBoost + approach * 0.16 * wallBoost)
        gate.strokeColor = palette.core.withAlphaComponent(0.12 + intensity * 0.38 * wallBoost + approach * 0.34 * wallBoost)
        gate.glowWidth = 3 + intensity * 9 * wallBoost + approach * 12 * wallBoost
        gate.lineWidth = 1.0 + intensity * 1.0 * wallBoost + approach * 1.2 * wallBoost
        gate.xScale = 1.0 + intensity * 0.1 * wallBoost + approach * 0.22 * wallBoost
        gate.yScale = 1.0 + intensity * 0.16 * wallBoost + approach * 0.34 * wallBoost
        gate.zRotation = (lane == .right ? 1 : -1) * approach * 0.04
        if live > 0.85 {
            gate.fillColor = palette.tip.withAlphaComponent(0.12 + approach * 0.12)
        }
    }

    private func applyContactPocketStyle(_ pocket: SKShapeNode?, lane: Lane, intensity: CGFloat, approach: CGFloat) {
        guard let pocket else { return }
        let palette = swingTrailPalette(intent: swingVisualIntent, lane: lane)
        let contactBias = recentContactLane == lane ? recentContactPocketBias() : 0
        let wallBoost: CGFloat = sessionMode == .wallRally ? 1.38 : 1.0
        pocket.position = racketContactPoint(for: lane)
        pocket.alpha = min(1, 0.10 + intensity * 0.28 * wallBoost + approach * 0.68 * wallBoost + contactBias * 0.22)
        pocket.strokeColor = palette.core.withAlphaComponent(0.10 + intensity * 0.22 * wallBoost + approach * 0.56 * wallBoost + contactBias * 0.22)
        pocket.fillColor = palette.glow.withAlphaComponent(0.02 + intensity * 0.04 * wallBoost + approach * 0.14 * wallBoost + contactBias * 0.08)
        pocket.glowWidth = 3 + intensity * 5 * wallBoost + approach * 12 * wallBoost + contactBias * 8
        pocket.lineWidth = 1.0 + intensity * 0.8 * wallBoost + approach * 1.8 * wallBoost + contactBias * 0.8
        pocket.xScale = 1.0 + intensity * 0.06 * wallBoost + approach * 0.32 * wallBoost + contactBias * 0.18
        pocket.yScale = 1.0 + intensity * 0.06 * wallBoost + approach * 0.32 * wallBoost + contactBias * 0.18
    }

    private func updateWallReadability(focusLane: Lane, focusBall: BallNode?, partner: BallNode?) {
        guard sessionMode == .wallRally else {
            leftStrokeReadLabel?.alpha = 0
            rightStrokeReadLabel?.alpha = 0
            focusStrokeReadLabel?.alpha = 0
            wallAnticipationBar?.alpha = 0
            wallAnticipationFill?.alpha = 0
            wallReboundBand?.alpha = 0
            contactTimingRing?.alpha = 0
            return
        }

        styleStrokeReadLabel(leftStrokeReadLabel, lane: .left, isFocus: false, approach: 0)
        styleStrokeReadLabel(rightStrokeReadLabel, lane: .right, isFocus: false, approach: 0)
        leftStrokeReadLabel?.alpha = 0
        rightStrokeReadLabel?.alpha = 0

        guard let focusBall else {
            focusStrokeReadLabel?.alpha = 0
            wallAnticipationBar?.alpha = 0.03
            wallAnticipationFill?.alpha = 0
            contactTimingRing?.alpha = 0
            return
        }

        let palette = swingTrailPalette(intent: .drive, lane: focusLane)
        let signedDelta = focusBall.effectiveArrivalTime - currentTrackTime
        let scalar = timingWindowScalar(
            for: focusBall,
            signedDelta: -signedDelta,
            swingIntent: .drive,
            strokeSide: strokeSide(for: focusLane)
        )
        let goodWindow = HitQuality.good.windowSeconds * scalar
        let greatWindow = HitQuality.great.windowSeconds * scalar
        let perfectWindow = HitQuality.perfect.windowSeconds * scalar
        let absDelta = abs(signedDelta)
        let approach = focusBall.approachToStrike(at: currentTrackTime)
        let focusPoint = racketContactPoint(for: focusLane)
        let contactDistance = spatialContactDistance(to: focusBall, lane: focusLane)
        let moveWarning = approach > 0.36 && contactDistance > wallAssistMissRadius(for: focusLane) * 0.78
        let nowCueLead = max(0.10, greatWindow * 0.26)
        let cueColor: UIColor
        if moveWarning {
            cueColor = UIColor(red: 0.96, green: 0.92, blue: 0.62, alpha: 1)
        } else if absDelta <= greatWindow + nowCueLead {
            cueColor = UIColor(red: 1.0, green: 0.88, blue: 0.42, alpha: 1)
        } else {
            cueColor = palette.core
        }
        focusStrokeReadLabel?.alpha = 0

        wallAnticipationBar?.position = CGPoint(x: focusPoint.x, y: focusPoint.y + Tunables.wallFocusReadLabelLift - 26)
        wallAnticipationBar?.alpha = min(0.38, 0.04 + approach * 0.34)
        wallAnticipationBar?.strokeColor = cueColor.withAlphaComponent(0.10 + approach * 0.18)
        wallAnticipationBar?.fillColor = UIColor(red: 0.03, green: 0.05, blue: 0.09, alpha: 0.14 + approach * 0.06)
        wallAnticipationBar?.glowWidth = 2 + approach * 3
        wallAnticipationBar?.xScale = 1.0 + approach * 0.03
        wallAnticipationBar?.yScale = 1.0 + approach * 0.04

        let peakLead = Tunables.wallAnticipationLeadMs.seconds
        let timeToContact = max(0, signedDelta)
        let rampIn = peakLead * 0.78
        let anticipationProgress: CGFloat
        if timeToContact > peakLead + rampIn {
            anticipationProgress = 0
        } else if timeToContact >= peakLead {
            anticipationProgress = 1 - CGFloat((timeToContact - peakLead) / rampIn)
        } else {
            anticipationProgress = max(0.78, 1 - CGFloat(timeToContact / peakLead) * 0.22)
        }
        let readabilityWindow = max(goodWindow * 3.0, 0.48)
        let timingFill = max(0, min(1, 1 - absDelta / readabilityWindow))
        let fillWidthProgress = max(0.14, anticipationProgress * 0.74 + timingFill * 0.26)
        let fillWidth = max(24, Tunables.wallAnticipationBarWidth * fillWidthProgress)
        wallAnticipationFill?.path = CGPath(
            roundedRect: CGRect(
                x: -fillWidth / 2,
                y: -(Tunables.wallAnticipationBarHeight * 0.56) / 2,
                width: fillWidth,
                height: Tunables.wallAnticipationBarHeight * 0.56
            ),
            cornerWidth: Tunables.wallAnticipationBarHeight * 0.28,
            cornerHeight: Tunables.wallAnticipationBarHeight * 0.28,
            transform: nil
        )
        wallAnticipationFill?.position = wallAnticipationBar?.position ?? .zero
        wallAnticipationFill?.fillColor = cueColor.withAlphaComponent(0.20 + fillWidthProgress * 0.16)
        wallAnticipationFill?.alpha = min(0.42, 0.08 + anticipationProgress * 0.26 + timingFill * 0.04)
        wallAnticipationFill?.glowWidth = 4 + fillWidthProgress * 6
        wallAnticipationFill?.xScale = 1.0 + (anticipationProgress > 0.78 ? 0.04 : 0)

        let ringScale = 0.86 + fillWidthProgress * 0.40 + approach * 0.14
        let ringAlpha = min(0.34, 0.04 + anticipationProgress * 0.20 + (absDelta <= perfectWindow ? 0.08 : 0))
        contactTimingRing?.position = focusPoint
        contactTimingRing?.strokeColor = cueColor.withAlphaComponent(0.10 + anticipationProgress * 0.16)
        contactTimingRing?.glowWidth = 2 + anticipationProgress * 5 + fillWidthProgress * 2
        contactTimingRing?.lineWidth = 1.2 + (anticipationProgress > 0.78 ? 0.4 : 0) + (absDelta <= greatWindow ? 0.3 : 0)
        contactTimingRing?.setScale(ringScale)
        contactTimingRing?.alpha = ringAlpha
        if anticipationProgress > 0.92, contactTimingRing?.action(forKey: "contactPulse") == nil {
            contactTimingRing?.run(.sequence([
                .group([
                    .scale(to: ringScale * 1.12, duration: 0.08),
                    .fadeAlpha(to: min(1, ringAlpha + 0.22), duration: 0.08)
                ]),
                .group([
                    .scale(to: ringScale, duration: 0.14),
                    .fadeAlpha(to: ringAlpha, duration: 0.14)
                ])
            ]), withKey: "contactPulse")
        }
        wallReboundBand?.alpha = 0
    }

    private func styleStrokeReadLabel(
        _ label: SKLabelNode?,
        lane: Lane,
        isFocus: Bool,
        approach: CGFloat
    ) {
        guard let label else { return }
        let palette = swingTrailPalette(intent: .drive, lane: lane)
        let stroke = strokeSide(for: lane)
        let accent = wallStrokeAccentColor(for: stroke, quality: isFocus ? .great : .good)
        let energy = isFocus ? max(approach, 0.52) : approach * 0.42
        label.fontColor = accent.blended(withFraction: energy * (isFocus ? 0.62 : 0.34), of: .white) ?? palette.core
        label.alpha = min(1, isFocus ? 0.62 + energy * 0.38 : 0.28 + energy * 0.32)
        label.setScale(isFocus ? 1.06 + energy * 0.18 : 0.94 + energy * 0.08)
        label.fontSize = isFocus ? 14 : 12
        label.position = CGPoint(
            x: racketContactPoint(for: lane).x,
            y: racketContactPoint(for: lane).y + Tunables.wallReadLabelLift
        )
    }

    private func shortStrokeRead(for lane: Lane) -> String {
        strokeSide(for: lane) == .forehand ? "FH" : "BH"
    }

    private func fullStrokeRead(for lane: Lane) -> String {
        shortStrokeRead(for: lane)
    }

    private func recentContactPocketBias() -> CGFloat {
        let qualityProgress = max(0, min(1, (recentContactUntil - currentTimeSnapshot) / 0.22))
        let qualityScalar: CGFloat
        switch recentContactQuality {
        case .perfect:
            qualityScalar = 1.0
        case .great:
            qualityScalar = 0.72
        case .good:
            qualityScalar = 0.42
        case .miss, nil:
            qualityScalar = 0
        }
        return qualityProgress * qualityScalar
    }

    private func cullMissedBalls() {
        let strikeY = size.height * Tunables.strikeLineYRatio
        var stillAlive: [BallNode] = []
        var missedLane: Lane?
        for ball in activeBalls {
            if ball.ownershipPhase.blocksCull {
                stillAlive.append(ball)
                continue
            }
            if ball.position.y < strikeY - Tunables.cullBelowStrikePoints {
                ball.removeFromParent()
                missedLane = missedLane ?? ball.lane
            } else {
                stillAlive.append(ball)
            }
        }
        activeBalls = stillAlive
        if let missedLane {
            registerMiss(lane: missedLane)
        }
    }

    // MARK: - Spawning (called by RhythmSpawner)

    func spawnBall(_ note: BeatmapNote) {
        if sessionMode == .wallRally {
            pendingWallSpawnToken = nil
        }
        spawnedBallCount += 1
        let travelSeconds = currentTravelSeconds
        let spawnTime = note.arrivalTime - travelSeconds
        let strikeY = size.height * Tunables.strikeLineYRatio
        let spawnY = sessionMode == .wallRally
            ? size.height * Tunables.wallSurfaceYRatio - 16
            : size.height * Tunables.spawnLineYRatio
        let horizonCenterX = size.width / 2
        let wallCenterBias: CGFloat = sessionMode == .wallRally ? 0.84 : 1.0
        let horizonSpread = size.width * Tunables.horizonLaneInsetRatio * racketTuning.horizonSpreadScalar * wallCenterBias
        let strikeInset = size.width * Tunables.strikeLaneInsetRatio * racketTuning.strikeWidthScalar * (sessionMode == .wallRally ? 1.08 : 1.0)
        let spawnX = horizonCenterX + (note.lane == .left ? -horizonSpread : horizonSpread)
        let strikeX = note.lane == .left ? strikeInset : size.width - strikeInset
        let shotShape = selectShotShape(for: note)
        let ballRole: BeatmapNote.Role = sessionMode == .wallRally ? .returnBall : note.role
        let strikeDiameter = size.width * Tunables.ballStrikeDiameterSceneWidthRatio
        let sceneRelativeStrikeScale = strikeDiameter / max(1, Tunables.ballRadiusPoints * 2)
        let ball = BallNode(
            lane: note.lane,
            kind: note.kind,
            role: ballRole,
            wallStyleMode: sessionMode == .wallRally,
            shotShape: shotShape,
            arrivalTime: note.arrivalTime,
            spawnTime: spawnTime,
            travelSeconds: travelSeconds,
            spawnPoint: CGPoint(x: spawnX, y: spawnY),
            strikePoint: CGPoint(x: strikeX, y: strikeY),
            spawnScale: Tunables.ballSpawnScale * racketTuning.spawnScaleScalar,
            strikeScale: sceneRelativeStrikeScale * racketTuning.strikeScaleScalar,
            overrunScale: Tunables.ballOverrunScale * racketTuning.overrunScaleScalar,
            curveAmount: wallCurveAmount() * racketTuning.curveScalar,
            overrideFillColor: sessionMode == .wallRally
                ? UIColor(red: 0.93, green: 0.97, blue: 0.36, alpha: 1)
                : nil
        )
        ball.ownershipPhase = .liveTravel
        addChild(ball)
        if sessionMode == .wallRally {
            ball.alpha = 0
            ball.setScale(0.78)
            ball.run(.group([
                .fadeIn(withDuration: 0.1),
                .scale(to: 1.0, duration: 0.12)
            ]))
            animateOpponentHit()
        }
        activeBalls.append(ball)
        if sessionMode == .wallRally {
            let pulsePalette = swingTrailPalette(intent: .drive, lane: note.lane)
            strikeLinePulse?.fillColor = pulsePalette.core
            strikeLinePulse?.schedule(arrivalTime: note.arrivalTime, currentTrackTime: currentTrackTime)
            stageWallReboundCue(for: ball)
        }
        stagePointCueIfNeeded(for: note)
    }

    private func scheduleWallBall(after delay: Double) {
        guard sessionMode == .wallRally, !sessionEnded else { return }
        guard activeBalls.isEmpty, activeExchanges.isEmpty else { return }
        let token = UUID()
        pendingWallSpawnToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard self.sessionMode == .wallRally, !self.sessionEnded, !self.isCountingDown else { return }
            guard self.pendingWallSpawnToken == token else { return }
            guard self.activeBalls.isEmpty, self.activeExchanges.isEmpty else { return }
            guard !self.activeBalls.contains(where: { $0.ownershipPhase.blocksSpawn }) else {
                self.pendingWallSpawnToken = nil
                return
            }
            guard self.activeBalls.isEmpty else {
                self.pendingWallSpawnToken = nil
                return
            }
            let lane = self.nextWallSpawnLane()
            let arrivalTime = self.currentTrackTime + self.currentTravelSeconds
            let note = BeatmapNote(
                arrivalTime: arrivalTime,
                lane: lane,
                kind: .normal,
                role: .rally
            )
            self.spawnBall(note)
        }
    }

    private func stagePointCueIfNeeded(for note: BeatmapNote) {
        guard sessionMode != .wallRally else { return }
        if showOpeningTutorialCue(for: note) {
            return
        }

        if note.kind == .double {
            betweenPointLiftUntil = max(betweenPointLiftUntil, currentTimeSnapshot + 0.32)
            CameraShake.drift(
                cameraNode,
                dx: 0,
                dy: -5,
                settleDx: 0,
                settleDy: -1,
                outMs: 58,
                driftMs: 120,
                backMs: 220
            )
            showMomentBanner(
                text: "TWO BALLS",
                color: UIColor(red: 0.98, green: 0.84, blue: 0.44, alpha: 1),
                hold: 0.36,
                startScale: 0.92,
                peakScale: 1.03
            )
            stageStrikeTransition(
                color: UIColor(red: 0.98, green: 0.84, blue: 0.44, alpha: 1),
                intensity: 0.88,
                duration: 0.34
            )
            return
        }

        switch note.role {
        case .serve:
            if activeBalls.count <= 1 {
                betweenPointLiftUntil = currentTimeSnapshot + 0.62
                CameraShake.drift(
                    cameraNode,
                    dx: 0,
                    dy: -4,
                    settleDx: 0,
                    settleDy: -1,
                    outMs: 65,
                    driftMs: 140,
                    backMs: 220
                )
            }
        case .changeup:
            if note.kind != .double {
                CameraShake.nudge(cameraNode, dx: 0, dy: -3, outMs: 45, backMs: 150)
            }
        case .returnBall:
            if activeBalls.count <= 2 {
            }
        case .rally:
            break
        }
    }

    private func showOpeningTutorialCue(for note: BeatmapNote) -> Bool {
        guard sessionMode != .wallRally, spawnedBallCount <= 6 else { return false }
        let sideLabel = shortStrokeRead(for: note.lane)

        switch spawnedBallCount {
        case 1:
            showInstruction(sideLabel, hold: 0.36)
            return true
        case 2:
            showInstruction(sideLabel, hold: 0.32)
            return true
        case 3:
            showInstruction("TIME", hold: 0.28)
            return true
        case 4, 5, 6:
            return false
        default:
            return false
        }
    }

    private func stageWallFeedCue(for ball: BallNode) {
        guard sessionMode == .wallRally else { return }
        let openingStrength = max(0, 1 - wallOpeningProgress())
        let cueStrength = max(0.18, openingStrength * 0.82)
        guard spawnedBallCount <= 4 || openingStrength > 0.42 else { return }

        let feedColor = UIColor(red: 0.93, green: 0.97, blue: 0.36, alpha: 1)
        let pocketPoint = racketContactPoint(for: ball.lane)
        let spawnHalo = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * (1.8 + cueStrength * 0.55))
        spawnHalo.position = ball.position
        spawnHalo.zPosition = 22
        spawnHalo.strokeColor = feedColor.withAlphaComponent(0.72)
        spawnHalo.fillColor = feedColor.withAlphaComponent(0.12 + cueStrength * 0.06)
        spawnHalo.lineWidth = 1.4 + cueStrength * 0.6
        spawnHalo.glowWidth = 8 + cueStrength * 6
        addChild(spawnHalo)

        let pocket = SKShapeNode(circleOfRadius: 18 + cueStrength * 4)
        pocket.position = pocketPoint
        pocket.zPosition = 21
        pocket.strokeColor = feedColor.withAlphaComponent(0.44 + cueStrength * 0.12)
        pocket.fillColor = UIColor.white.withAlphaComponent(0.03 + cueStrength * 0.03)
        pocket.lineWidth = 1.2
        pocket.glowWidth = 5 + cueStrength * 4
        addChild(pocket)

        let guidePath = CGMutablePath()
        guidePath.move(to: ball.position)
        guidePath.addQuadCurve(
            to: pocketPoint,
            control: CGPoint(
                x: (ball.position.x + pocketPoint.x) * 0.5,
                y: ball.position.y - size.height * (0.06 + cueStrength * 0.015)
            )
        )
        let guide = SKShapeNode(path: guidePath)
        guide.zPosition = 20
        guide.strokeColor = feedColor.withAlphaComponent(0.18 + cueStrength * 0.08)
        guide.lineWidth = 1.2 + cueStrength * 0.4
        guide.glowWidth = 4 + cueStrength * 3
        guide.lineCap = .round
        addChild(guide)

        let handoff = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * (0.92 + cueStrength * 0.1))
        handoff.position = ball.position
        handoff.zPosition = 23
        handoff.fillColor = feedColor.withAlphaComponent(0.32 + cueStrength * 0.12)
        handoff.strokeColor = UIColor.white.withAlphaComponent(0.34)
        handoff.lineWidth = 0.8
        handoff.glowWidth = 10
        addChild(handoff)

        spawnHalo.run(.sequence([
            .group([
                .scale(to: 0.62, duration: 0.15),
                .fadeOut(withDuration: 0.16 + cueStrength * 0.03)
            ]),
            .removeFromParent()
        ]))
        pocket.run(.sequence([
            .group([
                .scale(to: 1.26, duration: 0.13),
                .fadeAlpha(to: 0.2, duration: 0.13)
            ]),
            .group([
                .scale(to: 1.08, duration: 0.1),
                .fadeAlpha(to: 0.08, duration: 0.1)
            ]),
            .group([
                .scale(to: 1.14, duration: 0.1),
                .fadeOut(withDuration: 0.15 + cueStrength * 0.04)
            ]),
            .removeFromParent()
        ]))
        guide.run(.sequence([
            .group([
                .fadeAlpha(to: 0.06, duration: 0.11),
                .scaleX(to: 0.985, duration: 0.11)
            ]),
            .group([
                .fadeOut(withDuration: 0.1 + cueStrength * 0.04),
                .scaleX(to: 1.0, duration: 0.1)
            ]),
            .removeFromParent()
        ]))
        let handoffMove = SKAction.customAction(withDuration: 0.14 + cueStrength * 0.03) { [weak handoff] _, elapsed in
            guard let handoff else { return }
            let duration = 0.14 + cueStrength * 0.03
            let t = max(0, min(1, elapsed / duration))
            let inverse = 1 - t
            let control = CGPoint(
                x: (ball.position.x + pocketPoint.x) * 0.5,
                y: ball.position.y - self.size.height * (0.055 + cueStrength * 0.012)
            )
            let x = inverse * inverse * ball.position.x + 2 * inverse * t * control.x + t * t * pocketPoint.x
            let y = inverse * inverse * ball.position.y + 2 * inverse * t * control.y + t * t * pocketPoint.y
            handoff.position = CGPoint(x: x, y: y)
            handoff.alpha = 0.95 * inverse
            handoff.setScale(1 - CGFloat(t) * 0.22)
        }
        handoff.run(.sequence([handoffMove, .removeFromParent()]))
    }

    private func stageWallReboundCue(for ball: BallNode) {
        guard sessionMode == .wallRally else { return }

        let bandColor = wallStrokeAccentColor(for: strokeSide(for: ball.lane), quality: .great)
        wallReboundBand?.removeAllActions()
        wallReboundBand?.alpha = 0

        let reboundBurst = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.88)
        reboundBurst.position = CGPoint(
            x: size.width / 2,
            y: size.height * Tunables.wallSurfaceYRatio - 18
        )
        reboundBurst.strokeColor = bandColor.withAlphaComponent(0.84)
        reboundBurst.fillColor = UIColor.white.withAlphaComponent(0.08)
        reboundBurst.lineWidth = 1.6
        reboundBurst.glowWidth = 10
        reboundBurst.zPosition = 22
        addChild(reboundBurst)
        reboundBurst.run(.sequence([
            .group([
                .scale(to: 1.84, duration: Tunables.wallReboundCueDurationMs.seconds),
                .fadeOut(withDuration: Tunables.wallReboundCueDurationMs.seconds)
            ]),
            .removeFromParent()
        ]))
    }

    private func selectShotShape(for note: BeatmapNote) -> ShotShape {
        if sessionMode == .wallRally {
            return .drive
        }
        let phase = flow?.currentPhase ?? .exchange

        if note.kind == .double {
            return phase == .breaker ? .skid : .drive
        }

        switch note.role {
        case .serve:
            return phase == .warmUp ? .drive : .skid
        case .returnBall:
            return phase == .recovery ? .floater : .drive
        case .changeup:
            return phase == .breaker ? .skid : .floater
        case .rally:
            break
        }

        switch phase {
        case .warmUp:
            return .floater
        case .recovery:
            return .floater
        case .exchange:
            return note.lane == .left ? .drive : .topspin
        case .pressure:
            return note.lane == .left ? .topspin : .drive
        case .breaker:
            return note.lane == .left ? .skid : .topspin
        }
    }

    // MARK: - Input — Pokemon-Go-style pan gesture

    /// Single-finger swing recognizer.
    ///
    /// - `.began`: capture the touch origin in scene coords, instantiate the
    ///   swing trail node.
    /// - `.changed`: redraw the trail from origin → current finger position.
    /// - `.ended`: compute the release vector + velocity. In wall rally,
    ///   the lane is the side where the swipe happens, while upward release
    ///   supplies the stroke commitment. The player should not have to drag
    ///   across the center axis to hit a down-the-line ball.
    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let view = self.view else { return }
        let viewPoint = pan.location(in: view)
        let scenePoint = convertPoint(fromView: viewPoint)

        switch pan.state {
        case .began:
            swingOriginScene = scenePoint
            swingCurrentScene = scenePoint
            swingVisualReach = 0
            HapticManager.shared.playTouchDown()
            installSwingTrail(at: scenePoint)

        case .changed:
            guard let origin = swingOriginScene else { return }
            swingCurrentScene = scenePoint
            swingVisualReach = hypot(scenePoint.x - origin.x, scenePoint.y - origin.y)
            updateSwingTrail(from: origin, to: scenePoint)

        case .ended:
            defer {
                swingOriginScene = nil
                swingCurrentScene = nil
                fadeSwingTrail()
            }
            guard let origin = swingOriginScene else { return }
            let dx = scenePoint.x - origin.x
            let dy = scenePoint.y - origin.y
            let distance = hypot(dx, dy)

            let v = pan.velocity(in: view)
            let upwardVelocity = max(0, -v.y)
            let speed = sessionMode == .wallRally
                ? max(hypot(v.x, v.y), upwardVelocity)
                : hypot(v.x, v.y)

            // Ignore taps and accidental contact — only deliberate motion
            // commits a swing.
            let minimumDistance = sessionMode == .wallRally
                ? Tunables.swingMinDistance * 0.34
                : Tunables.swingMinDistance
            let minimumSpeed = sessionMode == .wallRally
                ? Tunables.swingFastVelocity * 0.30
                : 0
            guard distance >= minimumDistance || speed >= minimumSpeed else { return }

            // Lane is side-based, not cross-axis based. A left-side upward
            // swipe hits the left lane; a right-side upward swipe hits the
            // right lane. If the gesture starts nearly centered, defer to the
            // currently arriving ball.
            let lane: Lane
            if sessionMode == .wallRally {
                let focusLane = wallFocusLane()
                let weightedSideX = origin.x * Tunables.swingLaneSideStartWeight
                    + scenePoint.x * (1 - Tunables.swingLaneSideStartWeight)
                let centerDeadZone = size.width * Tunables.swingLaneCenterDeadZoneRatio
                if abs(weightedSideX - size.width * 0.5) > centerDeadZone {
                    lane = weightedSideX < size.width * 0.5 ? .left : .right
                } else {
                    lane = focusLane
                }
            } else {
                let weightedSideX = origin.x * Tunables.swingLaneSideStartWeight
                    + scenePoint.x * (1 - Tunables.swingLaneSideStartWeight)
                lane = weightedSideX < size.width * 0.5 ? .left : .right
            }
            swingVisualLane = lane
            swingVisualImpactUntil = currentTimeSnapshot + 0.26
            swingVisualReach = sessionMode == .wallRally
                ? hypot(dx, max(dy, Tunables.swingWallMinUpwardRisePoints))
                : distance
            let swingIntent = classifySwingIntent(dx: dx, dy: dy)
            swingVisualIntent = swingIntent
            resolveSwing(
                lane: lane,
                swingSpeed: speed,
                swingIntent: swingIntent,
                strokeSide: strokeSide(for: lane)
            )

        case .cancelled, .failed:
            swingOriginScene = nil
            swingCurrentScene = nil
            fadeSwingTrail()

        default:
            break
        }
    }

    // MARK: - Swing trail rendering

    private func installSwingTrail(at origin: CGPoint) {
        let trail = SKShapeNode()
        trail.strokeColor = UIColor(white: 1.0, alpha: 0.72)
        trail.fillColor = .clear
        trail.lineWidth = Tunables.swingTrailLineWidth * 0.92
        trail.glowWidth = 0
        trail.lineCap = .round
        trail.zPosition = 61

        let glow = SKShapeNode()
        glow.strokeColor = UIColor(red: 0.33, green: 0.88, blue: 0.95, alpha: 0.62)
        glow.fillColor = .clear
        glow.lineWidth = Tunables.swingTrailLineWidth * 1.9
        glow.glowWidth = Tunables.swingTrailGlowWidth + 8
        glow.lineCap = .round
        glow.zPosition = 60

        let tip = SKShapeNode(circleOfRadius: Tunables.swingTrailLineWidth * 0.9)
        tip.fillColor = UIColor.white.withAlphaComponent(0.88)
        tip.strokeColor = .clear
        tip.glowWidth = 10
        tip.position = origin
        tip.alpha = 0
        tip.zPosition = 62

        let path = CGMutablePath()
        path.move(to: origin)
        path.addLine(to: origin)
        trail.path = path
        glow.path = path

        addChild(glow)
        addChild(trail)
        addChild(tip)
        swingTrailGlowNode = glow
        swingTrailNode = trail
        swingTrailTipNode = tip
    }

    private func updateSwingTrail(from origin: CGPoint, to current: CGPoint) {
        guard let trail = swingTrailNode else { return }
        let path = CGMutablePath()
        path.move(to: origin)
        path.addLine(to: current)
        trail.path = path
        swingTrailGlowNode?.path = path

        // Trail brightens as the swing gets longer — visual reward for
        // committing.
        let distance = hypot(current.x - origin.x, current.y - origin.y)
        let intensity = min(1, distance / 220)
        let intent = sessionMode == .wallRally
            ? .drive
            : classifySwingIntent(dx: current.x - origin.x, dy: current.y - origin.y)
        let lane: Lane = sessionMode == .wallRally
            ? wallFocusLane()
            : (current.x < origin.x ? .left : .right)
        let palette = swingTrailPalette(intent: intent, lane: lane)

        trail.strokeColor = palette.core.withAlphaComponent(0.52 + 0.34 * intensity)
        trail.lineWidth = Tunables.swingTrailLineWidth * (0.88 + intensity * 0.24)
        swingTrailGlowNode?.strokeColor = palette.glow.withAlphaComponent(0.34 + 0.36 * intensity)
        swingTrailGlowNode?.lineWidth = Tunables.swingTrailLineWidth * (1.7 + intensity * 0.52)
        swingTrailGlowNode?.glowWidth = Tunables.swingTrailGlowWidth + 8 + 10 * intensity
        swingTrailTipNode?.position = current
        swingTrailTipNode?.fillColor = palette.tip.withAlphaComponent(0.72 + 0.18 * intensity)
        swingTrailTipNode?.alpha = 0.42 + 0.5 * intensity
        swingTrailTipNode?.setScale(0.82 + intensity * 0.4)
    }

    private func fadeSwingTrail() {
        guard let trail = swingTrailNode else { return }
        swingTrailNode = nil
        let glow = swingTrailGlowNode
        swingTrailGlowNode = nil
        let tip = swingTrailTipNode
        swingTrailTipNode = nil
        trail.run(.sequence([
            .fadeOut(withDuration: 0.18),
            .removeFromParent()
        ]))
        glow?.run(.sequence([
            .fadeOut(withDuration: 0.18),
            .removeFromParent()
        ]))
        tip?.run(.sequence([
            .group([
                .fadeOut(withDuration: 0.16),
                .scale(to: 0.6, duration: 0.16)
            ]),
            .removeFromParent()
        ]))
    }

    private func swingTrailPalette(intent: SwingIntent, lane: Lane) -> (core: UIColor, glow: UIColor, tip: UIColor) {
        switch (intent, lane) {
        case (.topspin, .left):
            return (
                UIColor(red: 0.67, green: 0.95, blue: 1.0, alpha: 1),
                UIColor(red: 0.25, green: 0.84, blue: 0.95, alpha: 1),
                UIColor.white
            )
        case (.topspin, .right):
            return (
                UIColor(red: 1.0, green: 0.86, blue: 0.7, alpha: 1),
                UIColor(red: 0.96, green: 0.7, blue: 0.34, alpha: 1),
                UIColor.white
            )
        case (.slice, .left):
            return (
                UIColor(red: 0.86, green: 0.98, blue: 1.0, alpha: 1),
                UIColor(red: 0.56, green: 0.96, blue: 0.92, alpha: 1),
                UIColor.white
            )
        case (.slice, .right):
            return (
                UIColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1),
                UIColor(red: 0.98, green: 0.56, blue: 0.72, alpha: 1),
                UIColor.white
            )
        case (.drive, .left):
            return (
                UIColor(red: 0.8, green: 0.96, blue: 1.0, alpha: 1),
                UIColor(red: 0.33, green: 0.88, blue: 0.95, alpha: 1),
                UIColor.white
            )
        case (.drive, .right):
            return (
                UIColor(red: 1.0, green: 0.88, blue: 0.82, alpha: 1),
                UIColor(red: 0.93, green: 0.56, blue: 0.46, alpha: 1),
                UIColor.white
            )
        }
    }

    // MARK: - Swing resolution

    private func resolveSwing(
        lane: Lane,
        swingSpeed: CGFloat,
        swingIntent: SwingIntent,
        strokeSide: StrokeSide
    ) {
        guard !isDying, !isCountingDown, !sessionEnded else { return }

        if sessionMode == .wallRally {
            guard let target = preferredWallSwingTarget(for: lane) else { return }
            let signedDelta = currentTrackTime - target.effectiveArrivalTime
            let delta = abs(signedDelta)
            let contactDistance = spatialContactDistance(to: target, lane: lane)

            if target.lane != lane {
                registerMiss(lane: lane, wallReason: .side, correctLane: target.lane)
                return
            }

            if contactDistance > wallAssistMissRadius(for: lane) * 1.08 {
                registerMiss(lane: lane, wallReason: .reach)
                return
            }

            let gradingDistance = adjustedWallGradingDistance(contactDistance, lane: lane)
            let windowScalar = timingWindowScalar(
                for: target,
                signedDelta: signedDelta,
                swingIntent: swingIntent,
                strokeSide: strokeSide
            )
            var quality = HitQuality.grade(absDelta: delta, windowScalar: windowScalar)

            if quality == .great,
               swingSpeed >= Tunables.swingFastVelocity * 0.34,
               delta <= HitQuality.perfect.windowSeconds * windowScalar * 1.42 {
                quality = .perfect
            }

            if quality == .good,
               swingSpeed >= Tunables.swingFastVelocity * 0.18,
               delta <= HitQuality.great.windowSeconds * windowScalar * 1.28 {
                quality = .great
            }

            quality = adjustedQualityForContactDistance(quality, distance: gradingDistance)
            quality = softenedWallTimingQuality(
                quality,
                lane: target.lane,
                delta: delta,
                windowScalar: windowScalar,
                swingSpeed: swingSpeed,
                gradingDistance: gradingDistance
            )

            if quality == .miss {
                registerMiss(
                    lane: lane,
                    wallReason: signedDelta < 0 ? .early : .late
                )
                return
            }

            registerHit(
                ball: target,
                quality: quality,
                strokeSide: strokeSide,
                swingIntent: .drive,
                contactDistance: contactDistance,
                swingSpeed: swingSpeed
            )
            return
        }

        guard let target = preferredSwingTarget(in: lane) else {
            // No ball to hit — count as a miss so the player feels the cost
            // of mashing.
            registerMiss(lane: lane, wallReason: .generic)
            return
        }
        let signedDelta = currentTrackTime - target.effectiveArrivalTime
        let delta = abs(signedDelta)
        let contactDistance = spatialContactDistance(to: target, lane: lane)
        if contactDistance > wallAssistMissRadius(for: lane) {
            registerMiss(lane: lane, wallReason: .reach)
            return
        }
        let gradingDistance = adjustedWallGradingDistance(contactDistance, lane: lane)

        // Phase tightens / loosens the timing windows. Warm-up gives the
        // player a 10% wider perfect window; breaker shaves 15% off.
        let windowScalar = timingWindowScalar(
            for: target,
            signedDelta: signedDelta,
            swingIntent: swingIntent,
            strokeSide: strokeSide
        )
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

        if quality == .good,
           strokeSide == .backhand,
           target.shotShape == .floater,
           delta <= HitQuality.great.windowSeconds * windowScalar * 1.06 {
            quality = .great
        }

        if quality == .great,
           strokeSide == .forehand,
           (swingIntent == .drive || swingIntent == .slice),
           (target.shotShape == .drive || target.shotShape == .skid),
           swingSpeed >= Tunables.swingFastVelocity * 0.92,
           delta <= HitQuality.perfect.windowSeconds * windowScalar * 1.35 {
            quality = .perfect
        }

        quality = adjustedQualityForContactDistance(quality, distance: gradingDistance)
        quality = softenedWallTimingQuality(
            quality,
            lane: target.lane,
            delta: delta,
            windowScalar: windowScalar,
            swingSpeed: swingSpeed,
            gradingDistance: gradingDistance
        )

        if quality == .miss {
            registerMiss(
                lane: lane,
                wallReason: signedDelta < 0 ? .early : .late
            )
            return
        }
        if let partner = linkedDoublePartner(for: target) {
            let companionQuality = companionQuality(
                primary: quality,
                swingSpeed: swingSpeed,
                targetDelta: delta,
                windowScalar: windowScalar,
                swingIntent: swingIntent,
                strokeSide: strokeSide,
                target: target
            )
            let partnerDistance = spatialContactDistance(to: partner, lane: partner.lane)
            registerMultiHit([
                (target, quality, strokeSide, swingIntent, contactDistance),
                (partner, companionQuality, strokeSide, swingIntent, partnerDistance)
            ], swingSpeed: swingSpeed)
            return
        }
        registerHit(
            ball: target,
            quality: quality,
            strokeSide: strokeSide,
            swingIntent: swingIntent,
            contactDistance: contactDistance,
            swingSpeed: swingSpeed
        )
    }

    private func preferredWallSwingTarget(for lane: Lane) -> BallNode? {
        guard sessionMode == .wallRally else { return preferredSwingTarget(in: lane) }

        let laneMatch = nearestBall(in: lane, around: currentTrackTime)
        if let laneMatch {
            return laneMatch
        }

        guard let focusBall = primaryWallBall() else { return nil }
        guard focusBall.isHittable(at: currentTrackTime) else { return nil }

        let focusDelta = abs(focusBall.effectiveArrivalTime - currentTrackTime)
        let generousWindow = HitQuality.good.windowSeconds * 2.8
        if focusDelta <= generousWindow {
            return focusBall
        }

        return nil
    }

    private func nearestBall(in lane: Lane, around trackTime: Double) -> BallNode? {
        let windowScalar = (flow?.currentProfile().timingWindowScalar ?? 1.0) * racketTuning.timingAssistScalar
        let targetSlack = sessionMode == .wallRally
            ? ((HitQuality.good.windowSeconds * 2.1 + Tunables.swingTargetSlackSeconds * 2.1)
                * (1 + Double(wallOpeningForgivenessBoost()) * 0.18))
            : (HitQuality.good.windowSeconds * windowScalar + Tunables.swingTargetSlackSeconds)
        let contactPoint = racketContactPoint(for: lane)
        let maxDistance = sessionMode == .wallRally
            ? wallAssistMissRadius(for: lane) * 1.18
            : effectiveRacketMissRadius(for: lane)
        return activeBalls
            .filter { $0.isHittable(at: trackTime) }
            .filter { $0.lane == lane }
            .filter { abs($0.effectiveArrivalTime - trackTime) <= targetSlack }
            .filter { $0.position.distance(to: contactPoint) <= maxDistance }
            .min {
                contactCandidateScore(for: $0, around: trackTime, contactPoint: contactPoint)
                < contactCandidateScore(for: $1, around: trackTime, contactPoint: contactPoint)
            }
    }

    // MARK: - Hit / miss

    private func registerHit(
        ball: BallNode,
        quality: HitQuality,
        strokeSide: StrokeSide,
        swingIntent: SwingIntent,
        contactDistance: CGFloat,
        swingSpeed: CGFloat
    ) {
        let hitLane = ball.lane
        let hitPosition = ball.position
        let contactPoint = racketContactPoint(for: hitLane)

        combo += 1
        maxCombo = max(maxCombo, combo)
        switch quality {
        case .perfect: perfectHits += 1
        case .great:   greatHits   += 1
        case .good:    goodHits    += 1
        case .miss:    break
        }

        // Fire audio/haptics on the same frame as contact, before VFX work.
        let power = strokePowerScalar(for: swingSpeed)
        GameEventBus.shared.publish(
            .hit(quality: quality, lane: hitLane, position: hitPosition, combo: combo, power: power)
        )

        var freezeMs: Double
        switch quality {
        case .perfect: freezeMs = Tunables.frameStopPerfectMs
        case .great:   freezeMs = Tunables.frameStopGreatMs
        case .good:    freezeMs = Tunables.frameStopGoodMs
        case .miss:    freezeMs = Tunables.frameStopMissMs
        }
        freezeMs *= wallStrikeFreezeScalar(for: quality)
        if freezeMs > 0 {
            frameStopUntil = currentTimeSnapshot + freezeMs.seconds
        }

        activeBalls.removeAll { $0 === ball }

        flashLaneGlow(lane: hitLane, quality: quality)
        swingVisualLane = hitLane
        recentContactLane = hitLane
        swingVisualImpactUntil = currentTimeSnapshot + wallContactImpactDuration(for: quality)
        swingVisualReach = max(swingVisualReach, 52)
        contactFlashUntil = currentTimeSnapshot + wallContactFlashDuration(for: quality)
        recentContactQuality = quality
        recentContactUntil = currentTimeSnapshot + wallContactAfterglowDuration(for: quality)
        // Hit-stop: freeze pose interpolation briefly so contact feels physical.
        if quality != .miss {
            hitStopUntil = currentTimeSnapshot + Tunables.swingHitStopSeconds
        }
        // Wrist snap: spike then exponential decay tracked from this timestamp
        wristSnapAppliedAt = currentTimeSnapshot
        lastRacketContactTarget = CGPoint(
            x: hitPosition.x - (playerRoot?.position.x ?? size.width / 2),
            y: hitPosition.y - (playerRoot?.position.y ?? size.height * Tunables.gameplayPlayerRootYRatio)
        )
        // Foot stomp: record contact time for recovery shuffle
        footContactTime = currentTimeSnapshot
        stageRacketContactBurst(quality: quality)
        let comboMultiplier = max(1, combo / 5)
        let strokeScoreBoost = scoreBoost(for: strokeSide, swingIntent: swingIntent, shotShape: ball.shotShape)
        score += Int((Double(quality.baseScore * comboMultiplier) * strokeScoreBoost).rounded())

        stageContactImprint(
            at: contactPoint,
            lane: hitLane,
            intent: swingIntent,
            quality: quality
        )
        if sessionMode == .wallRally {
            beginContinuousWallExchange(
                for: ball,
                from: hitPosition,
                to: contactPoint,
                lane: hitLane,
                quality: quality,
                strokeSide: strokeSide
            )
        } else if quality == .perfect {
            shatterBall(ball)
        } else {
            stageRacketContactProxy(
                ball: ball,
                from: hitPosition,
                to: contactPoint,
                lane: hitLane,
                quality: quality,
                strokeSide: strokeSide,
                completion: { _ in
                    ball.removeFromParent()
                }
            )
        }
        stageWallStrikeBurst(
            at: contactPoint,
            lane: hitLane,
            quality: quality
        )
        stageContactScoreBurst(
            at: contactPoint,
            quality: quality,
            strokeSide: strokeSide
        )
        stageContactCameraResponse(for: ball, quality: quality)
        applyRecoveryState(after: ball, quality: quality, contactDistance: contactDistance)

        let livePhase = flow?.currentPhase ?? .exchange
        if sessionMode == .phasedMatch {
            score += roleScoreBonus(for: ball.role, quality: quality, phase: livePhase)
            applyRallyInfluence(
                from: ball,
                quality: quality,
                strokeSide: strokeSide,
                swingIntent: swingIntent,
                contactDistance: contactDistance,
                phase: livePhase
            )
            applyRoleFeedback(
                for: ball,
                quality: quality,
                phase: livePhase,
                strokeSide: strokeSide,
                swingIntent: swingIntent
            )
            applyRallyResetPacing(after: ball, quality: quality, phase: livePhase)
        } else {
            betweenPointLiftUntil = max(
                betweenPointLiftUntil,
                currentTimeSnapshot + min(0.14, wallContactAfterglowDuration(for: quality) * 0.42)
            )
            wallHitCelebration(quality: quality, lane: hitLane, strokeSide: strokeSide)
        }
        recordInCurrentSegment(quality: quality)
        recentHUDImpactUntil = currentTimeSnapshot + wallHUDImpactDuration(for: quality)
        updateHUD()

        let newTier = comboTier(for: combo)
        if newTier != lastComboTier {
            lastComboTier = newTier
            GameEventBus.shared.publish(.comboTier(newTier))
        }
    }

    private func registerMiss(
        lane: Lane,
        wallReason: WallMissReason = .generic,
        correctLane: Lane? = nil
    ) {
        resetSwingBodyMechanics()
        totalMisses += 1
        pressureExchangeStreak = 0
        stageMissTimingPopup(at: racketContactPoint(for: lane), reason: wallReason)
        activeBalls.forEach { $0.removeFromParent() }
        activeBalls.removeAll()
        applyMissRecovery(for: lane)
        recordInCurrentSegment(quality: .miss)
        if sessionMode == .wallRally {
            strikeLinePulse?.cancelAll()
            let previous = combo
            combo = 0
            lastComboTier = 0
            wallNextLane = correctLane ?? lane
            updateHUD()
            stageResetBeat(duration: previous > 0 ? 0.10 : 0.08, soft: true)
            GameEventBus.shared.publish(.miss(lane: lane))
            if wallReason == .side, let correctLane {
                stageWallSideMissFeedback(swungLane: lane, correctLane: correctLane)
            }
            showWallMissInstruction(
                wallMissCue(for: wallReason, comboWasLive: previous > 0),
                comboWasLive: previous > 0
            )
            if previous >= 10 {
                showMomentBanner(
                    text: "RESET",
                    color: UIColor(red: 0.98, green: 0.56, blue: 0.48, alpha: 1),
                    hold: 0.2,
                    startScale: 0.94,
                    peakScale: 1.0
                )
            }
            scheduleWallBall(after: wallMissRestartSeconds(previousCombo: previous))
            return
        }
        let previous = combo
        if combo > 0 {
            // The Flappy moment.
            triggerDeathSequence(previousCombo: previous)
        } else {
            // Soft miss — no combo to break, just a little buzz.
            stageResetBeat(duration: 0.42)
            GameEventBus.shared.publish(.miss(lane: lane))
            showWallMissInstruction("", comboWasLive: false)
        }
    }

    private func wallMissCue(for reason: WallMissReason, comboWasLive: Bool) -> String {
        switch reason {
        case .early:  return "EARLY — WAIT FOR IT"
        case .late:   return "TOO LATE"
        case .side:   return "WRONG SIDE"
        case .reach:  return "TOO FAR"
        case .generic: return comboWasLive ? "COMBO RESET" : "MISS"
        }
    }

    private func showWallMissInstruction(_ text: String, comboWasLive: Bool) {
        guard showCoachingCues else { return }
        guard let instructionLabel, let instructionPlate else { return }
        guard !text.isEmpty, sessionMode != .wallRally else { return }
        let fadeIn: TimeInterval = 0.07
        let hold: TimeInterval = comboWasLive ? 0.16 : 0.14
        let fadeOut: TimeInterval = comboWasLive ? 0.12 : 0.10

        instructionLabel.removeAllActions()
        instructionPlate.removeAllActions()
        instructionLabel.text = text
        instructionLabel.alpha = 0
        instructionPlate.alpha = 0
        instructionLabel.run(.sequence([
            .fadeAlpha(to: 1.0, duration: fadeIn),
            .wait(forDuration: hold),
            .fadeOut(withDuration: fadeOut)
        ]))
        instructionPlate.run(.sequence([
            .fadeAlpha(to: 1.0, duration: fadeIn),
            .wait(forDuration: hold),
            .fadeOut(withDuration: fadeOut)
        ]))
    }

    /// Bucket the hit/miss into the third of the session it belongs to.
    /// Drives the segmented stats shown on the end-of-run summary.
    private func recordInCurrentSegment(quality: HitQuality) {
        let progress = sessionDurationSeconds <= 0
            ? 0
            : min(1, max(0, currentTrackTime / sessionDurationSeconds))
        let segment: Int
        switch progress {
        case ..<(1.0 / 3.0): segment = 0
        case ..<(2.0 / 3.0): segment = 1
        default:             segment = 2
        }
        segmentHits[quality]?[segment] += 1
    }

    private func triggerDeathSequence(previousCombo: Int) {
        resetSwingBodyMechanics()
        isDying = true
        combo = 0
        lastComboTier = 0
        stageResetBeat(duration: 0.82)
        updateHUD()
        background?.setMomentum(
            tier: 0,
            phase: flow?.currentPhase.rawValue.lowercased() ?? "exchange",
            breaking: true
        )
        showPhaseBanner(for: .recovery)
        showWallMissInstruction("RESET", comboWasLive: false)

        frameStopUntil = currentTimeSnapshot + Tunables.frameStopDeathMs.seconds
        flow?.registerComboBreak(at: currentTrackTime)
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
            guard let self else { return }
            self.background?.setMomentum(
                tier: self.comboTier(for: self.combo),
                phase: self.flow?.currentPhase.rawValue.lowercased() ?? "exchange",
                breaking: false
            )
        }
    }

    // MARK: - Public score accessors (for SwiftUI overlays)

    var currentScore: Int { score }
    var currentCombo: Int { combo }
    var currentMaxCombo: Int { maxCombo }
    var sessionIsOver: Bool { sessionEnded }

    private func updateHUD() {
        scoreLabel?.text = "\(score)"
        if usesMinimalWallHUD {
            layoutWallHUDPositions()
            hudCaptionLabel?.alpha = 0
            hudPhaseLabel?.alpha = 0
            hudPhaseValueLabel?.text = ""
            hudPhaseValueLabel?.alpha = 0
            timeLabel?.alpha = 0
            hudTopPlate?.alpha = 0
            hudMaxLabel?.alpha = 0
            hudMaxValueLabel?.alpha = 0
            comboLabel?.alpha = 0
            hudMaxLabel?.text = "BEST"
        } else {
            hudCaptionLabel?.alpha = 1
            hudPhaseLabel?.alpha = 1
            hudPhaseValueLabel?.alpha = 1
            timeLabel?.alpha = 1
            hudPhaseValueLabel?.text = flow?.currentPhase.rawValue ?? "EXCHANGE"
            hudPhaseValueLabel?.fontColor = bannerColor(for: flow?.currentPhase ?? .exchange).withAlphaComponent(0.88)
        }
        hudMaxValueLabel?.text = usesMinimalWallHUD ? "" : "x\(maxCombo)"
        if (sessionMode == .wallRally ? combo > 0 : combo > 1), let comboLabel {
            comboLabel.text = comboDescriptor(for: combo)
            comboLabel.fontColor = comboAccentColor(for: combo)
            comboLabel.alpha = usesMinimalWallHUD ? 0 : 1
        } else {
            comboLabel?.text = ""
        }
        hudTopPlate?.strokeColor = combo > 1
            ? comboAccentColor(for: combo).withAlphaComponent(0.28)
            : UIColor(white: 1.0, alpha: 0.16)
        hudTopPlate?.fillColor = combo > 1
            ? comboAccentColor(for: combo).withAlphaComponent(0.08)
            : UIColor(red: 0.03, green: 0.05, blue: 0.09, alpha: 0.42)
        hudCaptionLabel?.fontColor = combo > 1
            ? comboAccentColor(for: combo).withAlphaComponent(0.46)
            : UIColor(white: 1.0, alpha: 0.34)
        hudMaxValueLabel?.fontColor = combo > 1
            ? comboAccentColor(for: combo).withAlphaComponent(0.82)
            : UIColor(white: 1.0, alpha: 0.78)
        background?.setMomentum(
            tier: comboTier(for: combo),
            phase: sessionMode == .wallRally ? "wall" : (flow?.currentPhase.rawValue.lowercased() ?? "exchange"),
            breaking: isDying
        )
        let hudImpactWindow = max(0.16, wallHUDImpactDuration(for: recentContactQuality ?? .good))
        let hudImpact = max(0, min(1, (recentHUDImpactUntil - currentTimeSnapshot) / hudImpactWindow))
        hudTopPlate?.glowWidth = 4 + hudImpact * hudImpactGlowBoost()
        if hudImpact > 0.01 {
            hudCaptionLabel?.fontColor = (hudCaptionLabel?.fontColor ?? UIColor(white: 1.0, alpha: 0.34))
                .blended(withFraction: CGFloat(hudImpact * 0.4), of: .white)
        }
        punchHUD(recentContactQuality)
    }

    /// Quick scale-spring on the score label so each hit visibly *lands*
    /// in the HUD. Combo label punches at slightly different rhythm so the
    /// two pieces feel alive rather than synchronized.
    private func punchHUD(_ quality: HitQuality?) {
        if let s = scoreLabel {
            s.removeAction(forKey: "punch")
            let scoreScale: CGFloat
            let scoreOut: TimeInterval
            let scoreBack: TimeInterval
            let rallyBonus = sessionMode == .wallRally ? min(0.06, CGFloat(combo) * 0.004) : 0
            switch quality {
            case .perfect:
                scoreScale = 1.17 + rallyBonus
                scoreOut = 0.05
                scoreBack = 0.16
            case .great:
                scoreScale = 1.13 + rallyBonus * 0.8
                scoreOut = 0.045
                scoreBack = 0.14
            case .good:
                scoreScale = 1.08 + rallyBonus * 0.55
                scoreOut = 0.04
                scoreBack = 0.12
            case .miss, nil:
                scoreScale = 1.07
                scoreOut = 0.04
                scoreBack = 0.12
            }
            let punch = SKAction.sequence([
                .scale(to: scoreScale, duration: scoreOut),
                .scale(to: 1.0, duration: scoreBack)
            ])
            punch.timingMode = .easeOut
            s.run(punch, withKey: "punch")
        }
        if (sessionMode == .wallRally ? combo > 0 : combo > 1), let c = comboLabel {
            c.removeAction(forKey: "punch")
            let comboScale: CGFloat
            let comboOut: TimeInterval
            let comboBack: TimeInterval
            let streakBonus = sessionMode == .wallRally ? min(0.12, CGFloat(combo) * 0.008) : 0
            switch quality {
            case .perfect:
                comboScale = 1.18 + streakBonus
                comboOut = 0.05
                comboBack = 0.18
            case .great:
                comboScale = 1.13 + streakBonus * 0.78
                comboOut = 0.045
                comboBack = 0.16
            case .good:
                comboScale = 1.08 + streakBonus * 0.52
                comboOut = 0.04
                comboBack = 0.14
            case .miss, nil:
                comboScale = 1.1
                comboOut = 0.04
                comboBack = 0.14
            }
            let punch = SKAction.sequence([
                .scale(to: comboScale, duration: comboOut),
                .scale(to: 1.0, duration: comboBack)
            ])
            punch.timingMode = .easeOut
            c.run(punch, withKey: "punch")
        }
    }

    private func hudImpactGlowBoost() -> CGFloat {
        switch recentContactQuality {
        case .perfect: return 14
        case .great: return 8
        case .good: return 4
        case .miss, nil: return 0
        }
    }

    private func comboDescriptor(for combo: Int) -> String {
        if sessionMode == .wallRally {
            if combo >= 12 {
                return "ON FIRE x\(combo)"
            } else if combo >= 8 {
                return "LOCKED x\(combo)"
            } else if combo >= 4 {
                return "RHYTHM x\(combo)"
            }
            return "STREAK x\(combo)"
        }
        switch comboTier(for: combo) {
        case 1:
            return "RALLY x\(combo)"
        case 2:
            return "PRESSURE x\(combo)"
        case 3:
            return "SURGE x\(combo)"
        case 4:
            return "BREAKER x\(combo)"
        default:
            return "x\(combo)"
        }
    }

    private func comboAccentColor(for combo: Int) -> UIColor {
        if sessionMode == .wallRally {
            if combo >= 12 {
                return UIColor(red: 1.0, green: 0.86, blue: 0.42, alpha: 1)
            } else if combo >= 8 {
                return UIColor(red: 0.72, green: 0.93, blue: 1.0, alpha: 1)
            } else if combo >= 4 {
                return UIColor(red: 0.86, green: 0.78, blue: 0.48, alpha: 1)
            }
        }
        switch comboTier(for: combo) {
        case 1:
            return UIColor(red: 0.33, green: 0.88, blue: 0.95, alpha: 1)
        case 2:
            return UIColor(red: 0.87, green: 0.71, blue: 0.43, alpha: 1)
        case 3:
            return UIColor(red: 0.8, green: 0.33, blue: 0.55, alpha: 1)
        case 4:
            return UIColor(red: 0.96, green: 0.88, blue: 0.74, alpha: 1)
        default:
            return UIColor(white: 1, alpha: 0.62)
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
        let openingBoost = wallOpeningCelebrationBoost()
        let peak: CGFloat
        let durationUp: TimeInterval
        let durationDown: TimeInterval
        switch quality {
        case .perfect:
            peak = 0.35 + openingBoost * 0.06
            durationUp = 0.04
            durationDown = 0.34 + openingBoost * 0.02
        case .great:
            peak = 0.2 + openingBoost * 0.04
            durationUp = 0.05
            durationDown = 0.27 + openingBoost * 0.02
        case .good:
            peak = 0.12 + openingBoost * 0.03
            durationUp = 0.06
            durationDown = 0.22 + openingBoost * 0.02
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
            stageStrikeTransition(color: comboAccentColor(for: combo), intensity: 1.0, duration: 0.28)
        } else if quality == .great {
            stageStrikeTransition(color: comboAccentColor(for: combo), intensity: 0.68, duration: 0.2)
        }
    }

    /// White radial burst centred on the racket head — fires at contact so the
    /// racket visually "hits" something even before the ball reacts.
    private func stageRacketContactBurst(quality: HitQuality) {
        guard quality != .miss else { return }
        let origin = playerRacketHead.position
        let r = Tunables.contactRacketBurstRadius
        let burst = SKShapeNode(circleOfRadius: r)
        burst.position = origin
        burst.fillColor = UIColor.white.withAlphaComponent(quality == .perfect ? 0.80 : 0.58)
        burst.strokeColor = .clear
        burst.glowWidth = quality == .perfect ? 12 : 7
        burst.zPosition = 66
        addChild(burst)
        let toScale: CGFloat = quality == .perfect ? 3.0 : 2.4
        burst.run(.sequence([
            .group([
                .scale(to: toScale, duration: 0.07),
                .fadeOut(withDuration: 0.07)
            ]),
            .removeFromParent()
        ]))

        // Second ring — expands slower, accent-coloured
        let ring = SKShapeNode(circleOfRadius: r * 0.72)
        ring.position = origin
        let palette = swingTrailPalette(intent: swingVisualIntent, lane: swingVisualLane)
        ring.strokeColor = palette.glow.withAlphaComponent(0.90)
        ring.fillColor = .clear
        ring.lineWidth = quality == .perfect ? 3.0 : 2.0
        ring.glowWidth = quality == .perfect ? 10 : 6
        ring.zPosition = 65
        addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: toScale * 1.3, duration: 0.12),
                .fadeOut(withDuration: 0.12)
            ]),
            .removeFromParent()
        ]))
    }

    private func stageWallStrikeBurst(at point: CGPoint, lane: Lane, quality: HitQuality) {
        guard sessionMode == .wallRally else { return }

        let openingBoost = wallOpeningCelebrationBoost()
        let color: UIColor
        let ringScale: CGFloat
        let ringDuration: TimeInterval
        switch quality {
        case .perfect:
            color = UIColor(red: 1.0, green: 0.92, blue: 0.38, alpha: 1)
            ringScale = 3.2 + openingBoost * 0.32
            ringDuration = Tunables.contactFlashRingDuration
        case .great:
            color = UIColor(red: 1.0, green: 0.95, blue: 0.58, alpha: 1)
            ringScale = 2.7 + openingBoost * 0.26
            ringDuration = Tunables.contactFlashRingDuration
        case .good:
            color = UIColor(red: 0.96, green: 0.98, blue: 0.84, alpha: 1)
            ringScale = 2.3 + openingBoost * 0.2
            ringDuration = Tunables.contactFlashRingDuration
        case .miss:
            return
        }

        let ring = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.68)
        ring.position = point
        ring.strokeColor = UIColor.white.withAlphaComponent(0.98)
        ring.fillColor = .clear
        ring.lineWidth = 2.8
        ring.glowWidth = 14
        ring.zPosition = 64
        addChild(ring)

        let flash = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.52)
        flash.position = point
        flash.fillColor = color.withAlphaComponent(0.50)
        flash.strokeColor = .white.withAlphaComponent(0.46)
        flash.lineWidth = 0.8
        flash.glowWidth = 14
        flash.zPosition = 63
        addChild(flash)

        let driftX: CGFloat = lane == .right ? 8 : -8
        ring.run(.sequence([
            .group([
                .scale(to: ringScale, duration: ringDuration),
                .fadeOut(withDuration: ringDuration),
                .moveBy(x: driftX, y: -10, duration: ringDuration)
            ]),
            .removeFromParent()
        ]))
        flash.run(.sequence([
            .group([
                .scale(to: 1.9 + openingBoost * 0.14, duration: ringDuration * 0.72),
                .fadeOut(withDuration: ringDuration * 0.72)
            ]),
            .removeFromParent()
        ]))

        let sparkCount: Int
        switch quality {
        case .perfect: sparkCount = Tunables.contactSparkPerfectCount
        case .great: sparkCount = max(Tunables.contactSparkMinCount + 2, 8)
        case .good: sparkCount = Tunables.contactSparkMinCount
        case .miss: sparkCount = 0
        }
        if sparkCount > 0 {
            let outboundDirection: CGFloat = lane == .right ? 1 : -1
            for i in 0..<sparkCount {
                let radius = quality == .perfect ? 3.6 : 2.8
                let spark = SKShapeNode(circleOfRadius: radius)
                spark.fillColor = color.withAlphaComponent(0.92)
                spark.strokeColor = .clear
                spark.glowWidth = quality == .perfect ? 10 : 7
                spark.position = point
                spark.zPosition = 65
                addChild(spark)
                let spread = CGFloat(i) - CGFloat(sparkCount - 1) * 0.5
                let dist: CGFloat = quality == .perfect ? 62 : (quality == .great ? 52 : 42)
                let forward = dist * (0.82 + CGFloat(i % 3) * 0.08)
                let lateral = spread * 4.2
                spark.run(.sequence([
                    .group([
                        .moveBy(
                            x: outboundDirection * forward,
                            y: 18 + lateral,
                            duration: ringDuration * 1.08
                        ),
                        .fadeOut(withDuration: ringDuration * 1.08),
                        .scale(to: 0.16, duration: ringDuration * 1.08)
                    ]),
                    .removeFromParent()
                ]))
            }
        }
    }

    private func stageWallSideMissFeedback(swungLane: Lane, correctLane: Lane) {
        guard sessionMode == .wallRally else { return }

        let wrongGlow = swungLane == .left ? leftLaneGlow : rightLaneGlow
        let rightGlow = correctLane == .left ? leftLaneGlow : rightLaneGlow
        wrongGlow?.removeAllActions()
        rightGlow?.removeAllActions()

        wrongGlow?.run(.sequence([
            .fadeAlpha(to: 0.04, duration: 0.08),
            .fadeAlpha(to: 0.38, duration: 0.22)
        ]))
        rightGlow?.run(.sequence([
            .fadeAlpha(to: 0.64, duration: 0.08),
            .fadeAlpha(to: 0.42, duration: 0.28)
        ]))

        let wrongGate = swungLane == .left ? leftStrikeGate : rightStrikeGate
        let rightGate = correctLane == .left ? leftStrikeGate : rightStrikeGate
        wrongGate?.run(.sequence([
            .fadeAlpha(to: 0.04, duration: 0.08),
            .fadeAlpha(to: 0.14, duration: 0.2)
        ]))
        rightGate?.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.08),
            .fadeAlpha(to: 0.34, duration: 0.24)
        ]))

        CameraShake.nudge(
            cameraNode,
            dx: (swungLane == .right ? 1 : -1) * 7,
            dy: 3,
            outMs: 42,
            backMs: 150
        )

        let correctPoint = racketContactPoint(for: correctLane)
        let wrongPoint = racketContactPoint(for: swungLane)

        let guide = SKShapeNode()
        guide.zPosition = 67
        guide.strokeColor = wallStrokeAccentColor(for: strokeSide(for: correctLane), quality: .great).withAlphaComponent(0.84)
        guide.lineWidth = 3
        guide.glowWidth = 8
        let guidePath = CGMutablePath()
        guidePath.move(to: wrongPoint)
        guidePath.addQuadCurve(
            to: correctPoint,
            control: CGPoint(
                x: (wrongPoint.x + correctPoint.x) * 0.5,
                y: max(wrongPoint.y, correctPoint.y) + 18
            )
        )
        guide.path = guidePath
        guide.alpha = 0
        addChild(guide)
        guide.run(.sequence([
            .group([
                .fadeAlpha(to: 0.92, duration: 0.07),
                .scale(to: 1.02, duration: 0.1)
            ]),
            .group([
                .fadeOut(withDuration: 0.18),
                .scale(to: 0.98, duration: 0.18)
            ]),
            .removeFromParent()
        ]))

        let stamp = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        stamp.text = shortStrokeRead(for: correctLane)
        stamp.fontSize = 20
        stamp.fontColor = wallStrokeAccentColor(for: strokeSide(for: correctLane), quality: .great)
        stamp.position = CGPoint(x: correctPoint.x, y: correctPoint.y + 36)
        stamp.zPosition = 68
        stamp.alpha = 0
        addChild(stamp)
        stamp.run(.sequence([
            .group([
                .fadeAlpha(to: 1.0, duration: 0.08),
                .scale(to: 1.16, duration: 0.1)
            ]),
            .wait(forDuration: 0.14),
            .group([
                .fadeOut(withDuration: 0.18),
                .moveBy(x: 0, y: 8, duration: 0.18)
            ]),
            .removeFromParent()
        ]))
    }

    private func stageContactScoreBurst(at point: CGPoint, quality: HitQuality, strokeSide: StrokeSide) {
        let burstText = contactScoreBurstText(for: quality, strokeSide: strokeSide)
        guard !burstText.isEmpty else { return }

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = burstText
        label.fontSize = quality == .perfect ? 28 : 20
        label.fontColor = quality == .perfect
            ? UIColor(red: 1.0, green: 0.84, blue: 0.18, alpha: 1)
            : UIColor.white.withAlphaComponent(0.92)
        label.position = CGPoint(x: point.x, y: point.y + 10)
        label.zPosition = 67
        label.alpha = 0
        addChild(label)

        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.text = label.text
        shadow.fontSize = label.fontSize
        shadow.fontColor = UIColor.black.withAlphaComponent(0.3)
        shadow.position = CGPoint(x: point.x, y: point.y + 8)
        shadow.zPosition = 66
        shadow.alpha = 0
        addChild(shadow)

        let rise = Tunables.timingPopupRise
        let peakScale: CGFloat = quality == .perfect ? 1.28 : 1.08
        let fadeDuration = max(0.08, Tunables.timingPopupDuration - 0.08)
        label.run(.sequence([
            .group([
                .fadeAlpha(to: 1.0, duration: 0.06),
                .scale(to: peakScale, duration: 0.08),
                .moveBy(x: 0, y: 4, duration: 0.08)
            ]),
            .group([
                .fadeOut(withDuration: fadeDuration),
                .scale(to: 1.0, duration: fadeDuration),
                .moveBy(x: 0, y: rise, duration: fadeDuration)
            ]),
            .removeFromParent()
        ]))
        shadow.run(.sequence([
            .group([
                .fadeAlpha(to: 0.62, duration: 0.06),
                .moveBy(x: 0, y: 3, duration: 0.08)
            ]),
            .group([
                .fadeOut(withDuration: fadeDuration),
                .moveBy(x: 0, y: rise * 0.9, duration: fadeDuration)
            ]),
            .removeFromParent()
        ]))
    }

    private func contactScoreBurstText(for quality: HitQuality, strokeSide: StrokeSide) -> String {
        switch quality {
        case .perfect:
            return "PERFECT"
        case .great, .good:
            return "GOOD"
        case .miss:
            return ""
        }
    }

    private func stageMissTimingPopup(at point: CGPoint, reason: WallMissReason) {
        let text: String
        let color: UIColor
        switch reason {
        case .early:
            text = "EARLY"
            color = UIColor(red: 1.0, green: 0.72, blue: 0.28, alpha: 0.95) // amber
        case .late:
            text = "LATE"
            color = UIColor(red: 1.0, green: 0.72, blue: 0.28, alpha: 0.95) // amber
        default:
            text = "MISS"
            color = UIColor(red: 0.98, green: 0.38, blue: 0.38, alpha: 0.95) // red
        }

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = text == "MISS" ? 20 : 17
        label.fontColor = color
        label.position = CGPoint(x: point.x, y: point.y + 16)
        label.zPosition = 68
        label.alpha = 0
        addChild(label)

        label.run(.sequence([
            .group([
                .fadeAlpha(to: 0.92, duration: 0.06),
                .scale(to: 1.06, duration: 0.06)
            ]),
            .group([
                .fadeOut(withDuration: Tunables.timingPopupDuration - 0.06),
                .moveBy(x: 0, y: Tunables.timingPopupRise, duration: Tunables.timingPopupDuration - 0.06),
                .scale(to: 0.92, duration: Tunables.timingPopupDuration - 0.06)
            ]),
            .removeFromParent()
        ]))
    }

    private func wallHitCelebration(quality: HitQuality, lane: Lane, strokeSide: StrokeSide) {
        guard sessionMode == .wallRally else { return }
        let laneDirection: CGFloat = lane == .right ? 1 : -1
        let openingBoost = wallOpeningCelebrationBoost()
        switch quality {
        case .perfect:
            CameraShake.drift(
                cameraNode,
                dx: laneDirection * (9 + openingBoost * 2.2),
                dy: -(9 + openingBoost * 1.8),
                settleDx: laneDirection * 1.2,
                settleDy: -1.2,
                outMs: 44,
                driftMs: 96,
                backMs: 180
            )
            if wallShouldShowPerfectBanner(for: combo) {
                showMomentBanner(
                    text: wallPerfectMomentText(for: combo, strokeSide: strokeSide),
                    color: wallStrokeAccentColor(for: strokeSide, quality: .perfect),
                    hold: combo <= 2 ? 0.16 : 0.14,
                    startScale: 0.92,
                    peakScale: 1.02
                )
            }
        case .great:
            CameraShake.drift(
                cameraNode,
                dx: laneDirection * (4 + openingBoost * 1.1),
                dy: -(4 + openingBoost),
                settleDx: laneDirection * 0.8,
                settleDy: -0.8,
                outMs: 40,
                driftMs: 84,
                backMs: 160
            )
        case .good:
            break
        case .miss:
            break
        }
    }

    private func wallShouldShowPerfectBanner(for combo: Int) -> Bool {
        // Always show on the first few perfects so players learn the grade.
        // After that, fire at every 5th combo hit to celebrate streaks without
        // flooding the screen.
        if combo <= 3 { return true }
        return combo % 5 == 0
    }

    private func wallPerfectMomentText(for combo: Int, strokeSide: StrokeSide) -> String {
        // Stroke-specific opening labels keep early banners readable.
        // After the first few, shift to combo-aware praise.
        switch combo {
        case 1:
            return strokeSide == .forehand ? "CLEAN FH" : "CLEAN BH"
        case 2:
            return "KEEP IT GOING"
        case 3:
            return "LOCKED IN"
        case 5, 10:
            return "PERFECT ×\(combo)"
        case 15, 20:
            return "ON FIRE ×\(combo)"
        case 25, 30:
            return "UNSTOPPABLE ×\(combo)"
        default:
            return combo >= 20 ? "MACHINE ×\(combo)" : "PERFECT ×\(combo)"
        }
    }

    private func wallStrokeAccentColor(for strokeSide: StrokeSide, quality: HitQuality) -> UIColor {
        switch (strokeSide, quality) {
        case (.forehand, .perfect):
            return UIColor(red: 1.0, green: 0.84, blue: 0.38, alpha: 1)
        case (.forehand, .great):
            return UIColor(red: 1.0, green: 0.73, blue: 0.34, alpha: 1)
        case (.forehand, .good):
            return UIColor(red: 0.92, green: 0.82, blue: 0.52, alpha: 1)
        case (.backhand, .perfect):
            return UIColor(red: 0.62, green: 0.92, blue: 1.0, alpha: 1)
        case (.backhand, .great):
            return UIColor(red: 0.56, green: 0.84, blue: 1.0, alpha: 1)
        case (.backhand, .good):
            return UIColor(red: 0.72, green: 0.9, blue: 1.0, alpha: 1)
        case (_, .miss):
            return UIColor(white: 1.0, alpha: 0.75)
        }
    }

    private func stageWallReturn(
        ball liveBall: BallNode? = nil,
        from point: CGPoint,
        lane: Lane,
        quality: HitQuality,
        strokeSide: StrokeSide
    ) {
        guard sessionMode == .wallRally else { return }
        let laneEndX = lane == .left
            ? size.width * Tunables.horizonLaneInsetRatio
            : size.width * (1 - Tunables.horizonLaneInsetRatio)
        let endX = laneEndX + ((size.width * 0.5) - laneEndX) * 0.10
        let endPoint = CGPoint(x: endX, y: size.height * Tunables.wallSurfaceYRatio - 16)
        let color: UIColor
        let width: CGFloat
        let openingSnap = max(0, 1 - wallOpeningProgress())
        let comboDrive = min(1.0, Double(max(0, combo - 1)) / 10.0)
        let qualityScalar: CGFloat
        switch quality {
        case .perfect:
            color = wallStrokeAccentColor(for: strokeSide, quality: .perfect)
            width = 6.2
            qualityScalar = 0.92
        case .great:
            color = wallStrokeAccentColor(for: strokeSide, quality: .great)
            width = 5.0
            qualityScalar = 1.0
        case .good:
            color = wallStrokeAccentColor(for: strokeSide, quality: .good)
            width = 4.1
            qualityScalar = 1.08
        case .miss:
            return
        }

        let duration = max(0.14, (0.19 - openingSnap * 0.012 - comboDrive * 0.008) * Double(qualityScalar))
        var wallConfig = WallKinematicsConfig.rallyDefault
        wallConfig.totalDuration = duration
        wallConfig.reboundTravelDistance += CGFloat(comboDrive) * 8
        if quality == .perfect {
            wallConfig.reboundAcceleration = 1.28
        } else if quality == .great {
            wallConfig.reboundAcceleration = 1.22
        } else {
            wallConfig.reboundAcceleration = 1.14
        }
        let wallModel = RallyWallRallyKinematics(config: wallConfig)

        let trail = SKShapeNode()
        trail.zPosition = 63
        trail.lineCap = .round
        trail.strokeColor = color.withAlphaComponent(0.88)
        trail.lineWidth = width
        trail.glowWidth = width * 1.8
        let path = CGMutablePath()
        path.move(to: point)
        path.addLine(to: point)
        trail.path = path
        addChild(trail)

        let usesLiveBall = liveBall != nil
        let ghost: SKShapeNode
        if let liveBall {
            liveBall.removeAllActions()
            liveBall.position = point
            liveBall.zPosition = 64
            liveBall.alpha = 1
            ghost = liveBall
        } else {
            let synthetic = SKShapeNode(circleOfRadius: quality == .perfect ? 8 : 7)
            synthetic.fillColor = UIColor(red: 0.93, green: 0.97, blue: 0.36, alpha: 1)
            synthetic.strokeColor = color.withAlphaComponent(0.72)
            synthetic.lineWidth = 1.2
            synthetic.glowWidth = 8
            synthetic.position = point
            synthetic.zPosition = 64
            addChild(synthetic)
            ghost = synthetic
        }

        let echo = SKShapeNode(circleOfRadius: quality == .perfect ? 5.4 : 4.6)
        echo.fillColor = color.withAlphaComponent(0.18)
        echo.strokeColor = .white.withAlphaComponent(0.18)
        echo.lineWidth = 0.8
        echo.glowWidth = 6
        echo.position = point
        echo.zPosition = 63
        addChild(echo)

        let impactPulse = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.74)
        impactPulse.position = endPoint
        impactPulse.fillColor = color.withAlphaComponent(0.14)
        impactPulse.strokeColor = UIColor.white.withAlphaComponent(0.26)
        impactPulse.lineWidth = 1.1
        impactPulse.glowWidth = 8
        impactPulse.alpha = 0
        impactPulse.zPosition = 65
        addChild(impactPulse)

        let laneDirection: CGFloat = lane == .right ? 1 : -1

        let move = SKAction.customAction(withDuration: duration) { [weak ghost] _, elapsed in
            guard let ghost else { return }
            let t = max(0, min(1, elapsed / duration))
            let frame = wallModel.frame(
                start: point,
                wallContact: endPoint,
                reboundDirection: laneDirection,
                progress: CGFloat(t)
            )
            ghost.position = frame.point
            ghost.xScale = frame.xScale
            ghost.yScale = frame.yScale
            ghost.zRotation = laneDirection * 0.05 - laneDirection * wallModel.compressionScalar(at: CGFloat(t)) * 0.06
            ghost.alpha = 0.98 - CGFloat(t) * 0.64

            let livePath = CGMutablePath()
            livePath.move(to: point)
            livePath.addLine(to: frame.point)
            trail.path = livePath
        }
        ghost.run(.sequence([
            move,
            .run {
                if usesLiveBall {
                    liveBall?.removeFromParent()
                } else {
                    ghost.removeFromParent()
                }
            }
        ]))

        let echoMove = SKAction.customAction(withDuration: duration * 0.88) { [weak echo] _, elapsed in
            guard let echo else { return }
            let t = max(0, min(1, elapsed / (duration * 0.88)))
            let frame = wallModel.frame(
                start: point,
                wallContact: endPoint,
                reboundDirection: laneDirection,
                progress: CGFloat(t)
            )
            echo.position = CGPoint(
                x: frame.point.x + laneDirection * (2.2 - CGFloat(t) * 3.1),
                y: frame.point.y + (1 - CGFloat(t)) * 1.2
            )
            echo.setScale(0.92 + wallModel.compressionScalar(at: CGFloat(t)) * 0.18)
            echo.alpha = (1 - CGFloat(t)) * 0.28
        }
        echo.run(.sequence([
            echoMove,
            .removeFromParent()
        ]))

        trail.run(.sequence([
            .group([
                .fadeOut(withDuration: duration * 0.92),
                .scaleX(to: 1.04 + CGFloat(comboDrive) * 0.06, duration: duration * 0.92),
                .scaleY(to: 0.78, duration: duration * 0.92)
            ]),
            .removeFromParent()
        ]))

        let wallFlashAlpha: CGFloat = quality == .perfect ? 0.34 : (quality == .great ? 0.26 : 0.18)
        wallTargetNode?.removeAllActions()
        wallTargetNode?.run(.sequence([
            .group([
                .fadeAlpha(to: wallFlashAlpha, duration: duration * 0.82),
                .scaleX(to: 1.02, duration: duration * 0.82),
                .scaleY(to: 0.96, duration: duration * 0.82)
            ]),
            .wait(forDuration: Tunables.wallOutboundDwellSeconds),
            .group([
                .fadeAlpha(to: 1.0, duration: Tunables.wallOutboundReleaseSeconds),
                .scaleX(to: 1.0, duration: Tunables.wallOutboundReleaseSeconds),
                .scaleY(to: 1.0, duration: Tunables.wallOutboundReleaseSeconds)
            ])
        ]))

        wallKickShadowNode?.removeAllActions()
        wallKickShadowNode?.position = CGPoint(x: endPoint.x, y: size.height * Tunables.wallReboundBandYRatio + 6)
        wallKickShadowNode?.run(SKAction.customAction(withDuration: duration) { [weak self] _, elapsed in
            guard let self else { return }
            let progress = CGFloat(max(0, min(1, elapsed / duration)))
            let frame = wallModel.frame(
                start: point,
                wallContact: endPoint,
                reboundDirection: laneDirection,
                progress: progress
            )
            self.wallKickShadowNode?.alpha = frame.shadowAlpha
            self.wallKickShadowNode?.xScale = frame.shadowXScale
            self.wallKickShadowNode?.yScale = 0.88 + wallModel.compressionScalar(at: progress) * 0.06
            self.wallKickShadowNode?.position = CGPoint(
                x: frame.point.x,
                y: size.height * Tunables.wallReboundBandYRatio + 6 - wallModel.reboundLiftScalar(at: progress) * 0.03
            )
        })

        impactPulse.run(.sequence([
            .wait(forDuration: max(0, duration - Tunables.wallOutboundCompressionSeconds)),
            .group([
                .fadeAlpha(to: 1.0, duration: Tunables.wallOutboundCompressionSeconds),
                .scaleX(to: 1.36, duration: Tunables.wallOutboundCompressionSeconds),
                .scaleY(to: 0.74, duration: Tunables.wallOutboundCompressionSeconds)
            ]),
            .wait(forDuration: Tunables.wallOutboundDwellSeconds),
            .group([
                .fadeOut(withDuration: Tunables.wallOutboundReleaseSeconds),
                .scaleX(to: 1.62, duration: Tunables.wallOutboundReleaseSeconds),
                .scaleY(to: 1.12, duration: Tunables.wallOutboundReleaseSeconds)
            ]),
            .removeFromParent()
        ]))
    }

    private func beginContinuousWallExchange(
        for ball: BallNode,
        from hitPosition: CGPoint,
        to contactPoint: CGPoint,
        lane: Lane,
        quality: HitQuality,
        strokeSide: StrokeSide
    ) {
        let laneEndX = lane == .left
            ? size.width * Tunables.horizonLaneInsetRatio
            : size.width * (1 - Tunables.horizonLaneInsetRatio)
        let wallPoint = CGPoint(
            x: laneEndX + ((size.width * 0.5) - laneEndX) * 0.10,
            y: size.height * Tunables.wallSurfaceYRatio - 16
        )
        let direction: CGFloat = lane == .right ? 1 : -1
        let inboundSpeed = max(
            280,
            hitPosition.distance(to: contactPoint) / max(0.001, Tunables.racketContactApproachSeconds)
        )

        ball.removeAllActions()
        ball.position = hitPosition
        ball.zPosition = 67
        ball.alpha = 1

        let exchange = RallyContinuousBallExchange(
            ball: ball,
            startPoint: hitPosition,
            contactPoint: contactPoint,
            wallContactPoint: wallPoint,
            direction: direction,
            inboundSpeed: inboundSpeed,
            offsetFromCenter: abs(hitPosition.y - contactPoint.y),
            startTime: currentTimeSnapshot
        )
        ball.ownershipPhase = .racketExchange
        activeExchanges.append(exchange)
        stageRacketContactHalo(
            at: contactPoint,
            quality: quality,
            strokeSide: strokeSide
        )
    }

    private func stageRacketContactHalo(
        at point: CGPoint,
        quality: HitQuality,
        strokeSide: StrokeSide
    ) {
        let halo = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.84)
        halo.position = point
        halo.fillColor = wallStrokeAccentColor(for: strokeSide, quality: quality).withAlphaComponent(0.16)
        halo.strokeColor = UIColor.white.withAlphaComponent(0.22)
        halo.lineWidth = 0.9
        halo.glowWidth = 9
        halo.alpha = 0
        halo.zPosition = 66
        addChild(halo)

        halo.run(.sequence([
            .group([
                .fadeAlpha(to: 0.88, duration: 0.05),
                .scaleX(to: 1.18, duration: 0.05),
                .scaleY(to: 0.92, duration: 0.05)
            ]),
            .group([
                .fadeOut(withDuration: 0.17),
                .scaleX(to: 1.46, duration: 0.17),
                .scaleY(to: 1.08, duration: 0.17)
            ]),
            .removeFromParent()
        ]))
    }

    private func stageWallImpactPulse(
        at point: CGPoint,
        lane: Lane,
        quality: HitQuality,
        strokeSide: StrokeSide
    ) {
        let color = wallStrokeAccentColor(for: strokeSide, quality: quality)
        let pulse = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.78)
        pulse.position = point
        pulse.fillColor = color.withAlphaComponent(0.15)
        pulse.strokeColor = UIColor.white.withAlphaComponent(0.24)
        pulse.lineWidth = 1.0
        pulse.glowWidth = 8
        pulse.alpha = 0
        pulse.zPosition = 65
        addChild(pulse)

        let direction: CGFloat = lane == .right ? 1 : -1
        let scuff = SKShapeNode(ellipseOf: CGSize(width: 28, height: 7))
        scuff.position = CGPoint(x: point.x - direction * 3, y: point.y - 4)
        scuff.zRotation = -direction * 0.12
        scuff.fillColor = UIColor.white.withAlphaComponent(0.20)
        scuff.strokeColor = color.withAlphaComponent(0.34)
        scuff.lineWidth = 0.8
        scuff.glowWidth = 2
        scuff.alpha = 0
        scuff.zPosition = 62
        addChild(scuff)

        scuff.run(.sequence([
            .group([
                .fadeAlpha(to: 0.72, duration: 0.04),
                .scaleX(to: 1.22, duration: 0.04),
                .scaleY(to: 0.82, duration: 0.04)
            ]),
            .group([
                .fadeOut(withDuration: Tunables.wallImpactMarkFadeSeconds),
                .scaleX(to: 1.72, duration: Tunables.wallImpactMarkFadeSeconds),
                .scaleY(to: 0.44, duration: Tunables.wallImpactMarkFadeSeconds)
            ]),
            .removeFromParent()
        ]))

        for i in 0..<8 {
            let dust = SKShapeNode(circleOfRadius: CGFloat(2 + (i % 3)))
            dust.position = CGPoint(x: point.x - direction * 4, y: point.y - 2)
            dust.fillColor = UIColor.white.withAlphaComponent(0.20)
            dust.strokeColor = .clear
            dust.glowWidth = 1.5
            dust.zPosition = 61
            addChild(dust)
            let spread = CGFloat(i) - 3.5
            dust.run(.sequence([
                .group([
                    .moveBy(
                        x: -direction * CGFloat(10 + i * 2),
                        y: -CGFloat(8 + i % 4) + spread * 1.2,
                        duration: Tunables.wallImpactMarkFadeSeconds
                    ),
                    .fadeOut(withDuration: Tunables.wallImpactMarkFadeSeconds),
                    .scale(to: 0.18, duration: Tunables.wallImpactMarkFadeSeconds)
                ]),
                .removeFromParent()
            ]))
        }

        pulse.run(.sequence([
            .group([
                .fadeAlpha(to: 0.92, duration: 0.04),
                .scaleX(to: 1.34, duration: 0.04),
                .scaleY(to: 0.74, duration: 0.04)
            ]),
            .group([
                .fadeOut(withDuration: 0.16),
                .scaleX(to: 1.92, duration: 0.16),
                .scaleY(to: 1.18, duration: 0.16),
                .moveBy(x: -direction * 8, y: -6, duration: 0.16)
            ]),
            .removeFromParent()
        ]))
    }

    private func contactCandidateScore(for ball: BallNode, around trackTime: Double, contactPoint: CGPoint) -> CGFloat {
        let timeScore = CGFloat(abs(ball.effectiveArrivalTime - trackTime) * 1000)
        let distanceScore = ball.position.distance(to: contactPoint)
        if sessionMode == .wallRally {
            let approach = ball.approachToStrike(at: trackTime)
            let approachBonus = (1 - approach) * 22
            return timeScore * 0.92 + distanceScore * 0.76 + approachBonus
        }
        return timeScore + distanceScore * 0.9
    }

    private func strokePowerScalar(for swingSpeed: CGFloat) -> CGFloat {
        max(0.35, min(1.45, swingSpeed / max(1, Tunables.swingFastVelocity)))
    }

    private func racketContactPoint(for lane: Lane) -> CGPoint {
        guard let playerRoot else {
            return CGPoint(
                x: lane == .left ? size.width * 0.34 : size.width * 0.66,
                y: size.height * Tunables.strikeLineYRatio
            )
        }
        let authored = CGPoint(
            x: playerRoot.position.x + contactPocketOffsetX(for: lane),
            y: size.height * Tunables.strikeLineYRatio + contactPocketLift(for: lane)
        )
        guard let playerRacketHead, lane == swingVisualLane else {
            return authored
        }

        let live = playerRoot.convert(
            CGPoint(x: playerRacketHead.position.x, y: playerRacketHead.position.y),
            to: self
        )
        let swingProgress = max(0, min(1, (swingVisualImpactUntil - currentTimeSnapshot) / 0.26))
        let touchProgress: CGFloat = swingCurrentScene == nil ? 0 : 0.28
        let blend = min(1, swingProgress + touchProgress)
        return CGPoint(
            x: authored.x + (live.x - authored.x) * blend,
            y: authored.y + (live.y - authored.y) * blend
        )
    }

    private func contactPocketOffsetX(for lane: Lane) -> CGFloat {
        let forehand = strokeSide(for: lane) == .forehand
        let base = size.width * (forehand ? 0.165 : 0.125)
        return lane == .left ? -base : base
    }

    private func contactPocketLift(for lane: Lane) -> CGFloat {
        strokeSide(for: lane) == .forehand ? 4 : -2
    }

    private func refreshHandednessIfNeeded() {
        guard playerRoot != nil else { return }
        leftContactPocket?.position = racketContactPoint(for: .left)
        rightContactPocket?.position = racketContactPoint(for: .right)
    }

    private func applyMatchPaceIfNeeded() {
        if sessionMode == .wallRally {
            currentBPM = wallTempoBPM(for: matchPace)
            currentTravelSeconds = wallTravelSeconds()
            return
        }
        guard let flow else { return }
        let profile = flow.currentProfile()
        currentTravelSeconds = Tunables.ballTravelSeconds
            * profile.travelScalar
            * racketTuning.travelScalar
            * matchPace.travelScalar
        spawner?.travelSeconds = currentTravelSeconds
    }

    private func spatialContactDistance(to ball: BallNode, lane: Lane) -> CGFloat {
        ball.position.distance(to: racketContactPoint(for: lane))
    }

    private func wallTempoBPM(for pace: GamePreferences.MatchPace) -> Double {
        switch pace {
        case .calm:
            return 72
        case .standard:
            return 78
        case .quick:
            return 88
        }
    }

    private func wallTravelSeconds() -> Double {
        let openingScalar: Double
        switch spawnedBallCount {
        case ..<2:
            openingScalar = 1.06
        case 2:
            openingScalar = 1.01
        case 3:
            openingScalar = 0.98
        default:
            openingScalar = combo >= 6 ? 0.9 : (combo >= 3 ? 0.95 : 0.98)
        }
        return Tunables.ballTravelSeconds * 1.0 * matchPace.travelScalar * openingScalar
    }

    #if DEBUG
    private func runDebugAvatarAuditIfNeeded() {
        guard !hasLoggedAvatarAudit else { return }
        guard
            let root = playerRoot,
            let head = playerHead,
            let torso = playerTorso,
            let leadLeg = playerLeadLeg,
            let trailLeg = playerTrailLeg,
            let leadArm = playerLeadArm,
            let trailArm = playerTrailArm,
            let mouth = playerMouth
        else { return }

        let totalFrame = root.calculateAccumulatedFrame()
        let totalHeight = max(1, totalFrame.height)
        let headHeight = head.frame.height
        let legHeight = max(leadLeg.frame.height, trailLeg.frame.height)
        let stanceWidth = abs(leadLeg.position.x - trailLeg.position.x)
        let shoulderWidth = abs(leadArm.position.x - trailArm.position.x)
        let hipWidth = max(leadLeg.frame.width * 2, 1)

        let forehand = poseTargets(
            for: .forehandClean,
            leanDirection: 1,
            reach: 92,
            recoveryProgress: 0,
            anticipationProgress: 0.2,
            swingPhase: 0.42
        )
        let backhand = poseTargets(
            for: .backhandClean,
            leanDirection: -1,
            reach: 92,
            recoveryProgress: 0,
            anticipationProgress: 0.2,
            swingPhase: 0.42
        )

        let torsoContrast = abs(abs(forehand.torsoRotation) - abs(backhand.torsoRotation))
        let armContrast = abs(abs(forehand.trailArmRotation) - abs(backhand.trailArmRotation))
        let handleContrast = abs(abs(forehand.racketHandleRotation) - abs(backhand.racketHandleRotation))
        let mirroredSimilarity = max(0, 1 - ((torsoContrast + armContrast + handleContrast) / 1.35))

        let audit = RallyAvatarUnifiedAudit.run(
            RallyAvatarUnifiedAuditConfig(
                context: "Gameplay.SpriteKit",
                proportions: RallyAvatarProportionSample(
                    headHeightRatio: headHeight / totalHeight,
                    legLengthRatio: legHeight / totalHeight,
                    torsoWidthRatio: torso.frame.width / totalHeight,
                    shoulderToHipRatio: shoulderWidth / hipWidth,
                    stanceWidthRatio: stanceWidth / totalHeight
                ),
                face: RallyFaceSample(
                    eyeWidthRatio: 0.21,
                    eyeSpacingRatio: 0.25,
                    browHeightRatio: 0.11,
                    mouthHeightRatio: (mouth.position.y - head.position.y) / max(1, headHeight),
                    glassesWidthRatio: 0.48,
                    glassesVisible: !(playerLeftLens?.isHidden ?? true)
                ),
                framing: RallyFramingSample(
                    cameraPitchDegrees: 8,
                    cameraDistance: 1.14,
                    bodyCoverageRatio: min(1, totalFrame.height / max(1, size.height)),
                    headCoverageRatio: headHeight / max(1, size.height),
                    feetVisible: totalFrame.minY > -24,
                    shoulderCropRisk: totalFrame.maxX > size.width * 0.9 || totalFrame.minX < size.width * 0.1,
                    mannequinCenterRisk: abs(totalFrame.midX - size.width / 2) < 8
                ),
                backhand: RallyBackhandSample(
                    forehandTorsoTurn: forehand.torsoRotation,
                    backhandTorsoTurn: backhand.torsoRotation,
                    backhandSupportArmReach: abs(backhand.leadArmX - backhand.trailArmX) / 100,
                    backhandContactOffset: backhand.racketHeadX / 100,
                    recoveryDuration: 0.22,
                    mirroredSimilarityScore: mirroredSimilarity
                )
            )
        )
        RallyAvatarUnifiedAudit.log(audit, context: "Gameplay.SpriteKit")
        hasLoggedAvatarAudit = true
    }
    #endif

    private func wallCurveAmount() -> CGFloat {
        guard sessionMode == .wallRally else { return Tunables.laneCurveAmount }
        let openingBonus = wallOpeningCelebrationBoost()
        return Tunables.laneCurveAmount * max(0.16, 0.26 - openingBonus * 0.04)
    }

    private func wallCadenceSeconds(for quality: HitQuality) -> Double {
        let base: Double
        switch (matchPace, quality) {
        case (.calm, .perfect):
            base = 0.64
        case (.calm, .great):
            base = 0.70
        case (.calm, .good):
            base = 0.78
        case (.calm, .miss):
            base = 0.66
        case (.standard, .perfect):
            base = 0.54
        case (.standard, .great):
            base = 0.60
        case (.standard, .good):
            base = 0.68
        case (.standard, .miss):
            base = 0.60
        case (.quick, .perfect):
            base = 0.48
        case (.quick, .great):
            base = 0.54
        case (.quick, .good):
            base = 0.61
        case (.quick, .miss):
            base = 0.56
        }
        let comboScalar = combo >= 10 ? 0.80 : (combo >= 5 ? 0.86 : 0.94)
        return base * wallOpeningCadenceScalar() * comboScalar
    }

    private func wallRallyContinuitySnap(for quality: HitQuality) -> Double {
        guard sessionMode == .wallRally, combo >= 3 else { return 1.0 }
        switch quality {
        case .perfect:
            return combo >= 8 ? 0.86 : 0.9
        case .great:
            return combo >= 8 ? 0.9 : 0.93
        case .good:
            return combo >= 6 ? 0.95 : 0.97
        case .miss:
            return 1.0
        }
    }

    private func wallMissRestartSeconds(previousCombo: Int) -> Double {
        if previousCombo >= 6 {
            return 0.22
        }
        if previousCombo >= 2 {
            return 0.24
        }
        return 0.26
    }

    private func wallReturnSnapScalar(for quality: HitQuality) -> Double {
        guard sessionMode == .wallRally else { return 1.0 }
        let openingBonus = max(0, 1.0 - wallOpeningProgress())
        switch quality {
        case .perfect:
            return 0.78 - openingBonus * 0.03
        case .great:
            return 0.83 - openingBonus * 0.02
        case .good:
            return 0.89 - openingBonus * 0.015
        case .miss:
            return 1.0
        }
    }

    private func wallEarlyRallySnapBonus(for quality: HitQuality) -> Double {
        guard sessionMode == .wallRally else { return 1.0 }
        let openingBonus = max(0, 1.0 - wallOpeningProgress())
        switch quality {
        case .perfect:
            return 0.92 - openingBonus * 0.03
        case .great:
            return 0.95 - openingBonus * 0.025
        case .good:
            return combo <= 2 ? 0.97 - openingBonus * 0.02 : 0.99
        case .miss:
            return 1.0
        }
    }

    private func wallFocusLane() -> Lane {
        primaryWallBall()?.lane ?? wallNextLane
    }

    private func nextWallSpawnLane() -> Lane {
        let lane = wallNextLane
        wallNextLane = lane.opposite
        return lane
    }

    private func primaryWallBall() -> BallNode? {
        guard sessionMode == .wallRally, !activeBalls.isEmpty else { return nil }
        return activeBalls.min {
            contactCandidateScore(for: $0, around: currentTrackTime, contactPoint: racketContactPoint(for: $0.lane))
            < contactCandidateScore(for: $1, around: currentTrackTime, contactPoint: racketContactPoint(for: $1.lane))
        }
    }

    private func wallStanceTargetX(for lane: Lane) -> CGFloat {
        let base = lane == .left ? size.width * 0.36 : size.width * 0.64
        guard sessionMode == .wallRally, let focusBall = primaryWallBall(), focusBall.lane == lane else {
            return base
        }
        let ballBias = (focusBall.position.x - base) * 0.22
        return min(size.width * 0.7, max(size.width * 0.3, base + ballBias))
    }

    private func wallStrikeFreezeScalar(for quality: HitQuality) -> Double {
        guard sessionMode == .wallRally else { return 1.0 }
        let openingBoost = Double(wallOpeningCelebrationBoost())
        let rallyEase = combo >= 6 ? 0.9 : (combo >= 3 ? 0.94 : 1.0)
        switch quality {
        case .perfect:
            return (1.18 + openingBoost * 0.1) * rallyEase
        case .great:
            return (1.12 + openingBoost * 0.08) * rallyEase
        case .good:
            return (1.06 + openingBoost * 0.05) * rallyEase
        case .miss:
            return 1.0
        }
    }

    private func wallOpeningCadenceScalar() -> Double {
        switch spawnedBallCount {
        case ..<2:
            return 1.14
        case 2:
            return 1.08
        case 3:
            return 1.04
        case 4:
            return 1.02
        default:
            return 1.0
        }
    }

    private func wallOpeningProgress() -> Double {
        min(1, Double(max(0, spawnedBallCount - 1)) / 7)
    }

    private func wallOpeningForgivenessBoost() -> CGFloat {
        CGFloat(max(0, 1 - wallOpeningProgress()))
    }

    private func wallOpeningCelebrationBoost() -> CGFloat {
        wallOpeningForgivenessBoost()
    }

    private func wallContactImpactDuration(for quality: HitQuality) -> TimeInterval {
        guard sessionMode == .wallRally else { return 0.16 }
        let openingBoost = 1 - wallOpeningProgress()
        switch quality {
        case .perfect: return 0.2 + openingBoost * 0.03
        case .great: return 0.185 + openingBoost * 0.025
        case .good: return 0.17 + openingBoost * 0.02
        case .miss: return 0.16
        }
    }

    private func wallContactFlashDuration(for quality: HitQuality) -> TimeInterval {
        guard sessionMode == .wallRally else { return 0.15 }
        switch quality {
        case .perfect: return 0.21
        case .great: return 0.19
        case .good: return 0.17
        case .miss: return 0.15
        }
    }

    private func wallContactAfterglowDuration(for quality: HitQuality) -> TimeInterval {
        guard sessionMode == .wallRally else { return 0.22 }
        switch quality {
        case .perfect: return 0.3
        case .great: return 0.27
        case .good: return 0.24
        case .miss: return 0.22
        }
    }

    private func wallHUDImpactDuration(for quality: HitQuality) -> TimeInterval {
        guard sessionMode == .wallRally else { return 0.22 }
        let openingBoost = 1 - wallOpeningProgress()
        switch quality {
        case .perfect: return 0.3 + openingBoost * 0.03
        case .great: return 0.27 + openingBoost * 0.025
        case .good: return 0.24 + openingBoost * 0.02
        case .miss: return 0.22
        }
    }

    private func preferredSwingTarget(in lane: Lane) -> BallNode? {
        if let laneMatch = nearestBall(in: lane, around: currentTrackTime) {
            return laneMatch
        }
        guard sessionMode == .wallRally, let focusBall = primaryWallBall() else {
            return fallbackWallTarget()
        }
        let generousDistance = wallAssistMissRadius(for: focusBall.lane) * 1.55
        return focusBall.position.distance(to: racketContactPoint(for: focusBall.lane)) <= generousDistance
            ? focusBall
            : fallbackWallTarget()
    }

    private func fallbackWallTarget() -> BallNode? {
        guard sessionMode == .wallRally else { return nil }
        return primaryWallBall()
    }

    private func wallAssistMissRadius(for lane: Lane) -> CGFloat {
        sessionMode == .wallRally
            ? effectiveRacketMissRadius(for: lane) * (1.96 + wallOpeningForgivenessBoost() * 0.34)
            : effectiveRacketMissRadius(for: lane)
    }

    private func adjustedWallGradingDistance(_ distance: CGFloat, lane: Lane) -> CGFloat {
        guard sessionMode == .wallRally else { return distance }
        let offCenter = effectiveRacketOffCenterRadius(for: lane) * 1.12
        let assistRadius = wallAssistMissRadius(for: lane)
        guard distance > offCenter, distance < assistRadius else { return distance }
        return offCenter + (distance - offCenter) * 0.18
    }

    private func effectiveRacketReach(for lane: Lane) -> CGFloat {
        let base = Tunables.racketReachBasePoints * racketTuning.strikeWidthScalar
        let swingBonus = swingVisualReach * Tunables.racketReachFromSwingScalar
        let laneBias: CGFloat = swingVisualLane == lane ? 1.0 : 0.9
        return (base + swingBonus) * laneBias * recoveryReachScalar(for: lane)
    }

    private func effectiveRacketSweetSpot(for lane: Lane) -> CGFloat {
        Tunables.racketSweetSpotRadius
            * racketTuning.strikeWidthScalar
            * (swingVisualLane == lane ? 1.0 : 0.92)
            * recoveryReachScalar(for: lane)
    }

    private func effectiveRacketOffCenterRadius(for lane: Lane) -> CGFloat {
        min(
            effectiveRacketMissRadius(for: lane) - 8,
            Tunables.racketOffCenterRadius * racketTuning.strikeWidthScalar + swingVisualReach * 0.03
        )
    }

    private func effectiveRacketMissRadius(for lane: Lane) -> CGFloat {
        max(effectiveRacketReach(for: lane), Tunables.racketMissRadius * racketTuning.strikeWidthScalar)
    }

    private func adjustedQualityForContactDistance(_ quality: HitQuality, distance: CGFloat) -> HitQuality {
        if sessionMode == .wallRally {
            let sweetSpot = effectiveRacketSweetSpot(for: swingVisualLane) * 1.22
            let offCenter = effectiveRacketOffCenterRadius(for: swingVisualLane) * 1.24
            let missRadius = effectiveRacketMissRadius(for: swingVisualLane) * 1.16
            if distance <= sweetSpot { return quality }
            if distance >= missRadius { return .miss }
            if distance > offCenter {
                return downgrade(quality)
            }
            return quality == .perfect ? .great : quality
        }
        let sweetSpot = effectiveRacketSweetSpot(for: swingVisualLane)
        let offCenter = effectiveRacketOffCenterRadius(for: swingVisualLane)
        if distance <= sweetSpot { return quality }
        if distance >= effectiveRacketMissRadius(for: swingVisualLane) { return .miss }
        if distance > offCenter {
            return downgrade(downgrade(quality))
        }
        return downgrade(quality)
    }

    private func softenedWallTimingQuality(
        _ quality: HitQuality,
        lane: Lane,
        delta: Double,
        windowScalar: Double,
        swingSpeed: CGFloat,
        gradingDistance: CGFloat
    ) -> HitQuality {
        guard sessionMode == .wallRally else { return quality }

        let openingBoost = wallOpeningForgivenessBoost()
        let sweetSpot = effectiveRacketSweetSpot(for: lane) * (1.46 + openingBoost * 0.12)
        let offCenter = effectiveRacketOffCenterRadius(for: lane) * (1.4 + openingBoost * 0.14)
        let fastEnough = swingSpeed >= Tunables.swingFastVelocity * 0.16

        if quality == .good,
           fastEnough,
           gradingDistance <= offCenter,
           delta <= HitQuality.great.windowSeconds * windowScalar * (1.5 + Double(openingBoost) * 0.14) {
            return .great
        }

        if quality == .great,
           gradingDistance <= sweetSpot,
           delta <= HitQuality.perfect.windowSeconds * windowScalar * (1.64 + Double(openingBoost) * 0.16) {
            return .perfect
        }

        if quality == .miss,
           fastEnough,
           gradingDistance <= offCenter * 1.08,
           delta <= HitQuality.good.windowSeconds * windowScalar * (1.48 + Double(openingBoost) * 0.18) {
            return .good
        }

        return quality
    }

    private func downgrade(_ quality: HitQuality) -> HitQuality {
        switch quality {
        case .perfect: return .great
        case .great: return .good
        case .good, .miss: return .miss
        }
    }

    private func showPhaseBanner(for phase: MatchFlowPhase) {
        showMomentBanner(
            text: phase.rawValue,
            color: bannerColor(for: phase),
            hold: 0.46,
            startScale: 0.94,
            peakScale: 1.02
        )
        stageStrikeTransition(
            color: bannerColor(for: phase),
            intensity: phase == .breaker ? 1.0 : 0.78,
            duration: phase == .breaker ? 0.42 : 0.34
        )
    }

    private func showMomentBanner(
        text: String,
        color: UIColor,
        hold: TimeInterval,
        startScale: CGFloat = 0.94,
        peakScale: CGFloat = 1.02
    ) {
        guard let phaseBannerLabel else { return }
        phaseBannerLabel.removeAllActions()
        phaseBannerLabel.text = text
        phaseBannerLabel.alpha = 0
        phaseBannerLabel.setScale(startScale)
        phaseBannerLabel.fontColor = color
        phaseBannerLabel.run(.sequence([
            .group([
                .fadeAlpha(to: 1.0, duration: 0.16),
                .scale(to: peakScale, duration: 0.18)
            ]),
            .wait(forDuration: hold),
            .group([
                .fadeAlpha(to: 0.0, duration: 0.34),
                .scale(to: 1.0, duration: 0.4)
            ])
        ]))
    }

    private func stageResetBeat(duration: TimeInterval, soft: Bool = false) {
        betweenPointLiftUntil = max(betweenPointLiftUntil, currentTimeSnapshot + duration)
        if soft {
            CameraShake.nudge(cameraNode, dx: 0, dy: 2, outMs: 38, backMs: 120)
            stageStrikeTransition(
                color: UIColor(white: 1.0, alpha: 1.0),
                intensity: 0.28,
                duration: min(0.22, duration * 0.52)
            )
            return
        }
        CameraShake.nudge(cameraNode, dx: 0, dy: 4, outMs: 50, backMs: 170)
        stageStrikeTransition(
            color: UIColor(white: 1.0, alpha: 1.0),
            intensity: 0.52,
            duration: min(0.36, duration * 0.66)
        )
    }

    private func stageStrikeTransition(
        color: UIColor,
        intensity: CGFloat,
        duration: TimeInterval
    ) {
        let y = size.height * Tunables.strikeLineYRatio
        if let strikeHalo {
            strikeHalo.removeAction(forKey: "transition")
            strikeHalo.fillColor = color.withAlphaComponent(0.12 + intensity * 0.14)
            strikeHalo.run(.sequence([
                .group([
                    .fadeAlpha(to: 0.92, duration: duration * 0.28),
                    .scaleX(to: 1.08 + intensity * 0.06, duration: duration * 0.28),
                    .scaleY(to: 1.5 + intensity * 0.16, duration: duration * 0.28)
                ]),
                .group([
                    .fadeAlpha(to: 1.0, duration: 0),
                    .run { [weak strikeHalo] in
                        strikeHalo?.fillColor = color.withAlphaComponent(0.08)
                    },
                    .scaleX(to: 1.0, duration: duration * 0.72),
                    .scaleY(to: 1.0, duration: duration * 0.72),
                    .fadeOut(withDuration: duration * 0.72)
                ])
            ]), withKey: "transition")
        }

        let sweep = SKShapeNode(
            rectOf: CGSize(width: size.width * (0.2 + intensity * 0.18), height: 6),
            cornerRadius: 3
        )
        sweep.fillColor = color.withAlphaComponent(0.72)
        sweep.strokeColor = .clear
        sweep.glowWidth = 10 + intensity * 6
        sweep.position = CGPoint(x: size.width * 0.5, y: y)
        sweep.zPosition = 11
        addChild(sweep)

        sweep.run(.sequence([
            .group([
                .moveBy(x: 0, y: 14 + intensity * 10, duration: duration * 0.22),
                .fadeAlpha(to: 0.95, duration: duration * 0.18),
                .scaleX(to: 1.16 + intensity * 0.12, duration: duration * 0.22)
            ]),
            .group([
                .moveBy(x: 0, y: 18 + intensity * 12, duration: duration * 0.78),
                .fadeOut(withDuration: duration * 0.78),
                .scaleX(to: 1.5 + intensity * 0.18, duration: duration * 0.78),
                .scaleY(to: 0.6, duration: duration * 0.78)
            ]),
            .removeFromParent()
        ]))
    }

    private func completeSession() {
        resetSwingBodyMechanics()
        sessionEnded = true
        let finishColor = UIColor(red: 0.96, green: 0.88, blue: 0.74, alpha: 1)
        CameraShake.drift(
            cameraNode,
            dx: 0,
            dy: -6,
            settleDx: 0,
            settleDy: -1,
            outMs: 65,
            driftMs: 120,
            backMs: 240
        )
        background?.pulseHorizon(intensity: 1.12)
        background?.setMomentum(
            tier: max(1, comboTier(for: combo)),
            phase: "match-complete",
            breaking: false
        )
        showMomentBanner(
            text: "MATCH COMPLETE",
            color: finishColor,
            hold: 0.58,
            startScale: 0.9,
            peakScale: 1.04
        )
        stageStrikeTransition(color: finishColor, intensity: 1.0, duration: 0.44)
        showInstruction("Strong finish. Review the match story.", hold: 0.7)
        GameEventBus.shared.publish(.sessionEnd(buildResult()))
    }

    private func stageContactCameraResponse(for ball: BallNode, quality: HitQuality) {
        let laneDirection: CGFloat = ball.lane == .right ? 1 : -1
        let rallyEnergy = sessionMode == .wallRally ? min(1, CGFloat(combo) / 10) : 0
        switch quality {
        case .perfect:
            let dx = laneDirection * (ball.role == .changeup ? 8 : 5)
            let dy: CGFloat = ball.role == .serve ? -5 : (ball.role == .changeup ? -7 : -4)
            CameraShake.drift(
                cameraNode,
                dx: dx + laneDirection * rallyEnergy * 2.4,
                dy: dy - rallyEnergy * 1.8,
                settleDx: dx * 0.22,
                settleDy: dy * 0.18,
                outMs: 48,
                driftMs: 110,
                backMs: 220
            )
        case .great:
            CameraShake.drift(
                cameraNode,
                dx: laneDirection * (3 + rallyEnergy * 1.4),
                dy: -(3 + rallyEnergy),
                settleDx: laneDirection * 0.8,
                settleDy: -0.8,
                outMs: 42,
                driftMs: 90,
                backMs: 190
            )
        case .good:
            CameraShake.drift(
                cameraNode,
                dx: -laneDirection * 2,
                dy: 3,
                settleDx: 0,
                settleDy: 1.2,
                outMs: 38,
                driftMs: 80,
                backMs: 170
            )
        case .miss:
            break
        }
    }

    private func stageContactImprint(
        at point: CGPoint,
        lane: Lane,
        intent: SwingIntent,
        quality: HitQuality
    ) {
        let palette = swingTrailPalette(intent: intent, lane: lane)
        let ringRadius: CGFloat = quality == .perfect ? 19 : (quality == .great ? 15 : 12)
        let ring = SKShapeNode(circleOfRadius: ringRadius)
        ring.position = point
        ring.fillColor = .clear
        ring.strokeColor = palette.glow.withAlphaComponent(quality == .good ? 0.46 : 0.78)
        ring.lineWidth = quality == .perfect ? 2.4 : 1.7
        ring.glowWidth = quality == .perfect ? 12 : 7
        ring.zPosition = 64
        addChild(ring)

        let innerRing = SKShapeNode(circleOfRadius: ringRadius * 0.62)
        innerRing.position = point
        innerRing.fillColor = palette.tip.withAlphaComponent(quality == .perfect ? 0.16 : 0.1)
        innerRing.strokeColor = .white.withAlphaComponent(quality == .perfect ? 0.54 : 0.28)
        innerRing.lineWidth = 1
        innerRing.glowWidth = 8
        innerRing.zPosition = 63
        addChild(innerRing)

        let slash = SKShapeNode(
            rectOf: CGSize(width: intent == .slice ? 42 : 30, height: 3),
            cornerRadius: 1.5
        )
        slash.position = point
        slash.fillColor = palette.core.withAlphaComponent(0.84)
        slash.strokeColor = .clear
        slash.glowWidth = 6
        slash.zRotation = contactImprintRotation(intent: intent, lane: lane)
        slash.zPosition = 65
        addChild(slash)

        let direction: CGFloat = lane == .right ? 1 : -1
        let sparkLead = SKShapeNode(
            rectOf: CGSize(width: intent == .slice ? 30 : 36, height: 2.4),
            cornerRadius: 1.2
        )
        sparkLead.position = point
        sparkLead.fillColor = palette.tip.withAlphaComponent(0.9)
        sparkLead.strokeColor = .clear
        sparkLead.glowWidth = 8
        sparkLead.zRotation = contactImprintRotation(intent: intent, lane: lane) + direction * 0.08
        sparkLead.zPosition = 66
        addChild(sparkLead)

        let sparkTrail = SKShapeNode(
            rectOf: CGSize(width: intent == .slice ? 24 : 28, height: 2),
            cornerRadius: 1
        )
        sparkTrail.position = point
        sparkTrail.fillColor = palette.core.withAlphaComponent(0.76)
        sparkTrail.strokeColor = .clear
        sparkTrail.glowWidth = 6
        sparkTrail.zRotation = contactImprintRotation(intent: intent, lane: lane) - direction * 0.05
        sparkTrail.zPosition = 65
        addChild(sparkTrail)

        ring.run(.sequence([
            .group([
                .scale(to: quality == .perfect ? 2.02 : 1.64, duration: 0.2),
                .fadeOut(withDuration: 0.2)
            ]),
            .removeFromParent()
        ]))
        innerRing.run(.sequence([
            .group([
                .scale(to: quality == .perfect ? 1.36 : 1.24, duration: 0.16),
                .fadeOut(withDuration: 0.16)
            ]),
            .removeFromParent()
        ]))
        slash.run(.sequence([
            .group([
                .moveBy(x: lane == .right ? 8 : -8, y: intent == .topspin ? 8 : 4, duration: 0.16),
                .scaleX(to: intent == .slice ? 1.28 : 1.16, duration: 0.16),
                .fadeOut(withDuration: 0.16)
            ]),
            .removeFromParent()
        ]))
        sparkLead.run(.sequence([
            .group([
                .moveBy(x: direction * 18, y: intent == .topspin ? 12 : 6, duration: 0.12),
                .scaleX(to: 1.24, duration: 0.12),
                .fadeOut(withDuration: 0.12)
            ]),
            .removeFromParent()
        ]))
        sparkTrail.run(.sequence([
            .group([
                .moveBy(x: direction * 12, y: intent == .slice ? -3 : 3, duration: 0.14),
                .scaleX(to: 1.12, duration: 0.14),
                .fadeOut(withDuration: 0.14)
            ]),
            .removeFromParent()
        ]))
    }

    private func stageRacketContactProxy(
        ball: BallNode,
        from hitPosition: CGPoint,
        to contactPoint: CGPoint,
        lane: Lane,
        quality: HitQuality,
        strokeSide: StrokeSide,
        completion: @escaping (CGPoint) -> Void
    ) {
        ball.removeAllActions()
        ball.position = hitPosition
        ball.zPosition = 67
        ball.alpha = 1

        let halo = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.84)
        halo.position = contactPoint
        halo.fillColor = wallStrokeAccentColor(for: strokeSide, quality: quality).withAlphaComponent(0.16)
        halo.strokeColor = UIColor.white.withAlphaComponent(0.22)
        halo.lineWidth = 0.9
        halo.glowWidth = 9
        halo.alpha = 0
        halo.zPosition = 66
        addChild(halo)

        let direction: CGFloat = lane == .right ? 1 : -1
        let offsetFromCenter = abs(hitPosition.y - contactPoint.y)
        let inboundSpeed = max(280, hitPosition.distance(to: contactPoint) / max(0.001, Tunables.racketContactApproachSeconds))
        let model = RallyManualContactModel(config: .rallyDefault)
        let totalDuration = model.config.totalDuration

        let stringBaselines = playerRacketStrings.map(\.position)
        let animation = SKAction.customAction(withDuration: totalDuration) { [weak self, weak ball, weak halo] _, elapsed in
            guard let self, let ball, let halo else { return }
            let progress = CGFloat(max(0, min(1, elapsed / totalDuration)))
            let frame = model.frame(
                start: hitPosition,
                contact: contactPoint,
                direction: direction,
                progress: progress,
                inboundSpeed: inboundSpeed,
                offsetFromCenter: offsetFromCenter
            )

            ball.position = frame.contactPoint
            ball.xScale = frame.xScale
            ball.yScale = frame.yScale
            ball.alpha = 1 - max(0, progress - 0.76) / 0.24

            halo.position = contactPoint
            halo.alpha = max(0, frame.shadowAlpha + 0.18)
            halo.xScale = 0.96 + model.compressionScalar(at: progress) * 0.46
            halo.yScale = 0.86 + model.releaseVelocityScalar(at: progress) * 0.12

            for (index, string) in self.playerRacketStrings.enumerated() {
                guard index < stringBaselines.count else { continue }
                let baseline = stringBaselines[index]
                string.position = CGPoint(
                    x: baseline.x + direction * frame.stringFlexOffset * 0.12,
                    y: baseline.y - frame.stringFlexOffset
                )
                string.alpha = min(1, 0.38 + model.compressionScalar(at: progress) * 0.4)
            }
        }

        let cleanup = SKAction.run { [weak self, weak ball, weak halo] in
            let releasePoint = ball?.position ?? contactPoint
            halo?.removeFromParent()
            guard let self else { return }
            for (index, string) in self.playerRacketStrings.enumerated() {
                guard index < stringBaselines.count else { continue }
                string.position = stringBaselines[index]
                string.alpha = 0.38
            }
            completion(releasePoint)
        }

        ball.run(.sequence([animation, cleanup]))
    }

    private func contactImprintRotation(intent: SwingIntent, lane: Lane) -> CGFloat {
        let direction: CGFloat = lane == .right ? 1 : -1
        switch intent {
        case .drive:
            return direction * 0.2
        case .topspin:
            return direction * 0.66
        case .slice:
            return direction * -0.42
        }
    }

    private func applyRallyResetPacing(
        after ball: BallNode,
        quality: HitQuality,
        phase: MatchFlowPhase
    ) {
        switch quality {
        case .perfect:
            stageResetBeat(duration: ball.role == .changeup ? 0.5 : 0.34)
        case .great:
            if ball.role == .serve || ball.role == .changeup {
                stageResetBeat(duration: 0.28)
            }
        case .good:
            stageResetBeat(duration: phase == .pressure || phase == .breaker ? 0.24 : 0.18)
            break
        case .miss:
            break
        }
    }

    private func showInstruction(_ text: String, hold: TimeInterval) {
        guard showCoachingCues else { return }
        if sessionMode == .wallRally {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let isMinimalCue = trimmed.count <= 6 && trimmed == trimmed.uppercased()
            guard isMinimalCue else { return }
        }
        guard let instructionLabel, let instructionPlate else { return }
        instructionLabel.removeAllActions()
        instructionPlate.removeAllActions()
        instructionLabel.text = text
        instructionLabel.alpha = 0
        instructionPlate.alpha = 0
        instructionLabel.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.18),
            .wait(forDuration: hold),
            .fadeOut(withDuration: 0.3)
        ]))
        instructionPlate.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.18),
            .wait(forDuration: hold),
            .fadeOut(withDuration: 0.3)
        ]))
    }

    private func bannerColor(for phase: MatchFlowPhase) -> UIColor {
        switch phase {
        case .warmUp: return UIColor(red: 0.82, green: 0.98, blue: 1.0, alpha: 1)
        case .exchange: return UIColor(red: 0.86, green: 0.92, blue: 1.0, alpha: 1)
        case .pressure: return UIColor(red: 1.0, green: 0.84, blue: 0.38, alpha: 1)
        case .breaker: return UIColor(red: 1.0, green: 0.42, blue: 0.58, alpha: 1)
        case .recovery: return UIColor(red: 0.74, green: 1.0, blue: 0.88, alpha: 1)
        }
    }

    private func registerMultiHit(_ hits: [(BallNode, HitQuality, StrokeSide, SwingIntent, CGFloat)], swingSpeed: CGFloat) {
        for (ball, quality, strokeSide, swingIntent, contactDistance) in hits {
            guard activeBalls.contains(where: { $0 === ball }) else { continue }
            registerHit(
                ball: ball,
                quality: quality,
                strokeSide: strokeSide,
                swingIntent: swingIntent,
                contactDistance: contactDistance,
                swingSpeed: swingSpeed
            )
        }
    }

    private func linkedDoublePartner(for ball: BallNode) -> BallNode? {
        activeBalls.first { candidate in
            guard candidate !== ball else { return false }
            guard candidate.lane != ball.lane else { return false }
            guard abs(candidate.effectiveArrivalTime - ball.effectiveArrivalTime) <= Tunables.doubleArrivalToleranceSeconds else {
                return false
            }
            return ball.kind == .double || candidate.kind == .double
        }
    }

    private func companionQuality(
        primary: HitQuality,
        swingSpeed: CGFloat,
        targetDelta: Double,
        windowScalar: Double,
        swingIntent: SwingIntent,
        strokeSide: StrokeSide,
        target: BallNode
    ) -> HitQuality {
        guard primary != .miss else { return .miss }
        if swingSpeed >= Tunables.swingFastVelocity * 0.9 {
            return primary
        }
        let greatWindow = HitQuality.great.windowSeconds * windowScalar
        if strokeSide == .backhand && target.shotShape == .floater && targetDelta <= greatWindow * 1.08 {
            return .great
        }
        if swingIntent == .topspin && target.shotShape == .topspin && targetDelta <= greatWindow * 1.05 {
            return .great
        }
        return .good
    }

    private func classifySwingIntent(dx: CGFloat, dy: CGFloat) -> SwingIntent {
        if sessionMode == .wallRally {
            return .drive
        }
        if dy >= Tunables.swingTopspinRisePoints {
            return .topspin
        }
        if dy <= Tunables.swingSliceDropPoints {
            return .slice
        }
        return abs(dx) >= abs(dy) ? .drive : .topspin
    }

    private func strokeSide(for lane: Lane) -> StrokeSide {
        switch dominantHand {
        case .right:
            return lane == .left ? .backhand : .forehand
        case .left:
            return lane == .left ? .forehand : .backhand
        }
    }

    private func timingWindowScalar(
        for target: BallNode,
        signedDelta: Double,
        swingIntent: SwingIntent,
        strokeSide: StrokeSide
    ) -> Double {
        if sessionMode == .wallRally {
            return 1.78 + Double(wallOpeningForgivenessBoost()) * 0.16
        }
        let base = (flow?.currentProfile().timingWindowScalar ?? 1.0) * racketTuning.timingAssistScalar
        let shotScalar = shotTimingScalar(for: target.shotShape, signedDelta: signedDelta)
        let contactScalar = contactPhaseScalar(for: target)
        let intentScalar = swingIntentScalar(for: swingIntent, shotShape: target.shotShape)
        let strokeScalar = strokeSide == .backhand ? backhandScalar(for: target.shotShape) : forehandScalar(for: target.shotShape)
        let recoveryScalar = recoveryTimingScalar(for: target.lane)
        return max(0.1, base * shotScalar * contactScalar * intentScalar * strokeScalar * recoveryScalar)
    }

    private func applyRecoveryState(after ball: BallNode, quality: HitQuality, contactDistance: CGFloat) {
        let missRadius = max(1, effectiveRacketMissRadius(for: ball.lane))
        let distanceSeverity = min(1, contactDistance / missRadius)
        let reachSeverity = min(1, swingVisualReach / 240)
        let rawSeverity = max(distanceSeverity, reachSeverity * 0.86)
        let qualityScalar: CGFloat
        switch quality {
        case .perfect: qualityScalar = 0.78
        case .great: qualityScalar = 0.92
        case .good: qualityScalar = 1.08
        case .miss: qualityScalar = 1.2
        }
        let wallScalar: CGFloat = sessionMode == .wallRally ? 0.58 : 1.0
        let minimumSeverity: CGFloat = sessionMode == .wallRally ? 0.06 : 0.12
        let severity = min(1, max(minimumSeverity, rawSeverity * qualityScalar * wallScalar))
        recoverySeverity = severity
        recoveryLane = ball.lane
        let baseSeconds = sessionMode == .wallRally
            ? Tunables.avatarRecoverySeconds * 0.88
            : Tunables.recoveryBaseSeconds
        let stretchSeconds = sessionMode == .wallRally
            ? Tunables.avatarRecoverySeconds * 0.34
            : Tunables.recoveryStretchSeconds
        recoveryTrackUntil = max(
            recoveryTrackUntil,
            currentTrackTime + baseSeconds + Double(severity) * stretchSeconds
        )
    }

    private func applyMissRecovery(for lane: Lane) {
        let stretchSeverity = min(1, max(0.28, swingVisualReach / 220))
        recoverySeverity = max(recoverySeverity, stretchSeverity)
        recoveryLane = lane
        recoveryTrackUntil = max(
            recoveryTrackUntil,
            currentTrackTime + Tunables.recoveryBaseSeconds * 0.9 + Double(stretchSeverity) * Tunables.recoveryStretchSeconds
        )
    }

    private func recoveryProgress(at trackTime: Double) -> CGFloat {
        guard recoveryTrackUntil > trackTime else { return 0 }
        let remaining = recoveryTrackUntil - trackTime
        let total = Tunables.recoveryBaseSeconds + Tunables.recoveryStretchSeconds
        return min(1, CGFloat(remaining / max(0.001, total)))
    }

    private func recoveryPenalty(for lane: Lane) -> CGFloat {
        guard let recoveryLane else { return 0 }
        let progress = recoveryProgress(at: currentTrackTime)
        guard progress > 0 else { return 0 }
        let laneScalar: CGFloat = recoveryLane == lane
            ? Tunables.recoverySameLanePenalty
            : Tunables.recoveryOppositeLanePenalty
        return min(1, recoverySeverity * progress * laneScalar)
    }

    private func recoveryReachScalar(for lane: Lane) -> CGFloat {
        if sessionMode == .wallRally {
            return 1.12
        }
        return max(0.68, 1 - recoveryPenalty(for: lane) * Tunables.recoveryReachPenalty)
    }

    private func recoveryTimingScalar(for lane: Lane) -> Double {
        if sessionMode == .wallRally {
            return 1.18
        }
        return max(0.72, 1 - Double(recoveryPenalty(for: lane)) * Tunables.recoveryTimingPenalty)
    }

    private func recoveryOffsetX(at trackTime: Double) -> CGFloat {
        guard let recoveryLane else { return 0 }
        let progress = recoveryProgress(at: trackTime)
        guard progress > 0 else { return 0 }
        let direction: CGFloat = recoveryLane == .right ? 1 : -1
        return direction
            * size.width
            * Tunables.recoveryCenterOffsetRatio
            * recoverySeverity
            * progress
    }

    private func contactPhaseScalar(for target: BallNode) -> Double {
        if sessionMode == .wallRally {
            switch target.contactWindowPhase(at: currentTrackTime) {
            case .approach:
                return 0.96
            case .rise:
                return 1.08
            case .peak:
                return 1.12
            case .fall:
                return 1.02
            }
        }
        switch (target.shotShape, target.contactWindowPhase(at: currentTrackTime)) {
        case (_, .approach):
            return 0.82
        case (.topspin, .rise):
            return 1.08
        case (.topspin, .peak):
            return 1.0
        case (.topspin, .fall):
            return 0.9
        case (.skid, .rise):
            return 1.1
        case (.skid, .peak):
            return 0.9
        case (.skid, .fall):
            return 0.8
        case (.floater, .rise):
            return 0.92
        case (.floater, .peak):
            return 1.04
        case (.floater, .fall):
            return 1.08
        case (.drive, .rise):
            return 0.98
        case (.drive, .peak):
            return 1.06
        case (.drive, .fall):
            return 0.94
        }
    }

    private func shotTimingScalar(for shotShape: ShotShape, signedDelta: Double) -> Double {
        let isEarly = signedDelta < 0
        switch shotShape {
        case .drive:
            return isEarly ? 0.98 : 1.0
        case .topspin:
            return isEarly ? 0.92 : 1.08
        case .skid:
            return isEarly ? 1.06 : 0.84
        case .floater:
            return isEarly ? 0.9 : 1.12
        }
    }

    private func swingIntentScalar(for intent: SwingIntent, shotShape: ShotShape) -> Double {
        switch (intent, shotShape) {
        case (.drive, .drive), (.topspin, .topspin), (.slice, .skid), (.topspin, .floater):
            return 1.06
        case (.slice, .topspin), (.drive, .floater):
            return 0.92
        default:
            return 1.0
        }
    }

    private func forehandScalar(for shotShape: ShotShape) -> Double {
        switch shotShape {
        case .drive, .skid: return 0.98
        case .topspin, .floater: return 1.0
        }
    }

    private func backhandScalar(for shotShape: ShotShape) -> Double {
        switch shotShape {
        case .floater, .topspin: return 1.04
        case .drive, .skid: return 1.0
        }
    }

    private func scoreBoost(for strokeSide: StrokeSide, swingIntent: SwingIntent, shotShape: ShotShape) -> Double {
        switch (strokeSide, swingIntent, shotShape) {
        case (.forehand, .drive, .drive), (.forehand, .slice, .skid):
            return 1.08
        case (.backhand, .topspin, .topspin), (.backhand, .drive, .floater):
            return 1.04
        default:
            return 1.0
        }
    }

    private func applyRallyInfluence(
        from ball: BallNode,
        quality: HitQuality,
        strokeSide: StrokeSide,
        swingIntent: SwingIntent,
        contactDistance: CGFloat,
        phase: MatchFlowPhase
    ) {
        guard let spawner else { return }

        let missRadius = max(1, effectiveRacketMissRadius(for: ball.lane))
        let contactCentering = max(0, 1 - min(1, contactDistance / missRadius))
        let qualityPressure: Double
        switch quality {
        case .perfect: qualityPressure = 0.95
        case .great: qualityPressure = 0.76
        case .good: qualityPressure = 0.48
        case .miss: qualityPressure = 0.2
        }

        let laneBias: Lane
        switch (strokeSide, swingIntent) {
        case (.forehand, .drive), (.forehand, .topspin):
            laneBias = ball.lane.opposite
        case (.backhand, .drive), (.backhand, .topspin):
            laneBias = ball.lane
        case (_, .slice):
            laneBias = ball.lane
        }

        let shape: RallyInfluence.Shape
        switch swingIntent {
        case .drive:
            shape = quality == .good ? .defensive : .drive
        case .topspin:
            shape = quality == .good ? .defensive : .topspin
        case .slice:
            shape = quality == .good ? .slice : .slice
        }

        let phasePressure: Double
        switch phase {
        case .warmUp: phasePressure = 0.12
        case .exchange: phasePressure = 0.3
        case .recovery: phasePressure = 0.22
        case .pressure: phasePressure = 0.5
        case .breaker: phasePressure = 0.68
        }

        let pressure = min(
            1,
            max(0.1, qualityPressure * 0.7 + Double(contactCentering) * 0.2 + phasePressure)
        )

        let alternateLane: Lane
        if quality == .good || swingIntent == .slice {
            alternateLane = ball.lane.opposite
        } else {
            alternateLane = ball.lane
        }

        spawner.applyInfluence(
            RallyInfluence(
                preferredLane: laneBias,
                alternateLane: alternateLane,
                shape: shape,
                pressure: pressure
            )
        )
    }

    private func roleScoreBonus(for role: BeatmapNote.Role, quality: HitQuality, phase: MatchFlowPhase) -> Int {
        switch (role, quality) {
        case (.returnBall, .perfect):
            return 30
        case (.returnBall, .great):
            return 18
        case (.changeup, .perfect):
            return phase == .breaker ? 48 : 40
        case (.changeup, .great):
            return 24
        case (.serve, .perfect):
            return 16
        default:
            return 0
        }
    }

    private func applyRoleFeedback(
        for ball: BallNode,
        quality: HitQuality,
        phase: MatchFlowPhase,
        strokeSide: StrokeSide,
        swingIntent: SwingIntent
    ) {
        if ball.role == .returnBall, (quality == .great || quality == .perfect) {
            cleanReturnPickups += 1
        }

        if ball.role == .changeup, (quality == .great || quality == .perfect) {
            changeupWinners += 1
        }

        if phase == .pressure || phase == .breaker {
            if ball.role != .serve, (quality == .great || quality == .perfect) {
                pressureExchangeStreak += 1
                if pressureExchangeStreak == 4 {
                    pressureHolds += 1
                    pressureExchangeStreak = 0
                    score += phase == .breaker ? 80 : 60
                }
            } else {
                pressureExchangeStreak = 0
            }
        } else {
            pressureExchangeStreak = 0
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
            completeSession()
        }
    }
}

// MARK: - BallNode

final class BallNode: SKShapeNode {
    enum ContactWindowPhase {
        case approach
        case rise
        case peak
        case fall
    }

    var lane: Lane
    let kind: BeatmapNote.Kind
    let role: BeatmapNote.Role
    let wallStyleMode: Bool
    let shotShape: GameScene.ShotShape
    let arrivalTime: Double
    let spawnTime: Double
    let travelSeconds: Double
    let spawnPoint: CGPoint
    let strikePoint: CGPoint
    let spawnScale: CGFloat
    let strikeScale: CGFloat
    let overrunScale: CGFloat
    let curveAmount: CGFloat
    var ownershipPhase: RallyBallOwnershipPhase = .liveTravel
    var reentryState: RallyReentryBallState?
    var normalizationState: RallyBallNormalizationState?
    var liveTravelBaselineOverride: RallyBallLiveTravelBaseline?
    private var trackingEmphasis: CGFloat = 0
    private let auraNode = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 1.4)
    private let warningRingNode = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 2.1)
    private let focusRingNode = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 2.65)
    private let tailNode = SKShapeNode(ellipseOf: CGSize(width: Tunables.ballRadiusPoints * 2.8, height: Tunables.ballRadiusPoints * 0.92))
    private let shadowNode = SKShapeNode(ellipseOf: CGSize(width: Tunables.ballRadiusPoints * 1.6, height: Tunables.ballRadiusPoints * 0.62))
    private let wallShadowNode = SKShapeNode(ellipseOf: CGSize(width: Tunables.ballRadiusPoints * 1.2, height: Tunables.ballRadiusPoints * 0.46))
    private let rimShadeNode = SKShapeNode()
    private let coreNode = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.34)
    private let specularNode = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.24)
    private let seamGroup = SKNode()
    private let seamPrimary = SKShapeNode()
    private let seamSecondary = SKShapeNode()
    private static let opticYellow = UIColor(red: 0.875, green: 1.0, blue: 0.31, alpha: 1)
    private static let opticYellowRim = UIColor(red: 0.769, green: 0.88, blue: 0.273, alpha: 1)

    init(
        lane: Lane,
        kind: BeatmapNote.Kind,
        role: BeatmapNote.Role,
        wallStyleMode: Bool,
        shotShape: GameScene.ShotShape,
        arrivalTime: Double,
        spawnTime: Double,
        travelSeconds: Double,
        spawnPoint: CGPoint,
        strikePoint: CGPoint,
        spawnScale: CGFloat,
        strikeScale: CGFloat,
        overrunScale: CGFloat,
        curveAmount: CGFloat,
        overrideFillColor: UIColor? = nil
    ) {
        self.lane = lane
        self.kind = kind
        self.role = role
        self.wallStyleMode = wallStyleMode
        self.shotShape = shotShape
        self.arrivalTime = arrivalTime
        self.spawnTime = spawnTime
        self.travelSeconds = travelSeconds
        self.spawnPoint = spawnPoint
        self.strikePoint = strikePoint
        self.spawnScale = spawnScale
        self.strikeScale = strikeScale
        self.overrunScale = overrunScale
        self.curveAmount = curveAmount
        super.init()
        let r = Tunables.ballRadiusPoints
        path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        fillColor = overrideFillColor ?? Self.opticYellow
        strokeColor = .white
        lineWidth = 1
        glowWidth = 10
        auraNode.strokeColor = .clear
        auraNode.fillColor = fillColor.withAlphaComponent(kind == .double ? 0.22 : 0.14)
        auraNode.glowWidth = kind == .double ? 18 : 10
        auraNode.zPosition = -1
        addChild(auraNode)

        warningRingNode.strokeColor = fillColor.withAlphaComponent(kind == .double ? 0.95 : 0.65)
        warningRingNode.lineWidth = kind == .double ? 3 : 2
        warningRingNode.glowWidth = kind == .double ? 10 : 6
        warningRingNode.fillColor = .clear
        warningRingNode.zPosition = -1
        addChild(warningRingNode)

        focusRingNode.strokeColor = UIColor.white.withAlphaComponent(0.0)
        focusRingNode.lineWidth = 1.6
        focusRingNode.glowWidth = 0
        focusRingNode.fillColor = .clear
        focusRingNode.zPosition = -1
        addChild(focusRingNode)

        tailNode.fillColor = fillColor.withAlphaComponent(0.2)
        tailNode.strokeColor = .clear
        tailNode.glowWidth = kind == .double ? 10 : 6
        tailNode.zPosition = -3
        addChild(tailNode)

        shadowNode.fillColor = UIColor.black.withAlphaComponent(Tunables.bounceShadowAlpha)
        shadowNode.strokeColor = .clear
        shadowNode.zPosition = -2
        addChild(shadowNode)

        wallShadowNode.fillColor = UIColor.black.withAlphaComponent(0.18)
        wallShadowNode.strokeColor = .clear
        wallShadowNode.alpha = 0
        wallShadowNode.zPosition = -2
        addChild(wallShadowNode)

        rimShadeNode.path = Self.lowerRightRimPath(radius: r * 0.95)
        rimShadeNode.fillColor = Self.opticYellowRim.withAlphaComponent(0.34)
        rimShadeNode.strokeColor = .clear
        rimShadeNode.zPosition = 0.4
        addChild(rimShadeNode)

        coreNode.fillColor = UIColor.white.withAlphaComponent(0.18)
        coreNode.strokeColor = .clear
        coreNode.zPosition = 1
        addChild(coreNode)

        specularNode.fillColor = UIColor.white.withAlphaComponent(0.3)
        specularNode.strokeColor = .clear
        specularNode.zPosition = 2
        addChild(specularNode)

        let seamColor = UIColor.white.withAlphaComponent(0.82)
        seamPrimary.path = Self.seamPath(radius: r * 0.84, phase: 0.0)
        seamPrimary.strokeColor = seamColor
        seamPrimary.lineWidth = max(1.1, r * 0.082)
        seamPrimary.lineCap = .round
        seamPrimary.fillColor = .clear
        seamGroup.addChild(seamPrimary)

        seamSecondary.path = Self.seamPath(radius: r * 0.64, phase: .pi * 0.5)
        seamSecondary.strokeColor = seamColor.withAlphaComponent(0.62)
        seamSecondary.lineWidth = max(0.9, r * 0.068)
        seamSecondary.lineCap = .round
        seamSecondary.fillColor = .clear
        seamSecondary.xScale = 0.88
        seamSecondary.yScale = 0.72
        seamGroup.addChild(seamSecondary)
        seamGroup.zPosition = 1
        addChild(seamGroup)

        switch role {
        case .serve:
            warningRingNode.lineWidth += 1
            warningRingNode.glowWidth += 4
            auraNode.fillColor = fillColor.withAlphaComponent(0.22)
            coreNode.fillColor = UIColor.white.withAlphaComponent(0.24)
        case .returnBall:
            auraNode.fillColor = fillColor.withAlphaComponent(0.18)
            coreNode.fillColor = UIColor.white.withAlphaComponent(0.28)
        case .changeup:
            warningRingNode.strokeColor = UIColor.white.withAlphaComponent(0.92)
            coreNode.fillColor = UIColor.white.withAlphaComponent(0.34)
        case .rally:
            break
        }

        let telegraph = SKAction.sequence([
            .group([
                .scale(to: 0.4, duration: travelSeconds),
                .fadeOut(withDuration: travelSeconds)
            ]),
            .removeFromParent()
        ])
        warningRingNode.run(telegraph)

        let auraPulse = SKAction.repeatForever(.sequence([
            .group([
                .fadeAlpha(to: kind == .double ? 0.95 : 0.72, duration: 0.22),
                .scale(to: kind == .double ? 1.16 : 1.08, duration: 0.22)
            ]),
            .group([
                .fadeAlpha(to: kind == .double ? 0.42 : 0.28, duration: 0.22),
                .scale(to: 1.0, duration: 0.22)
            ])
        ]))
        auraNode.run(auraPulse)

        if kind == .double {
            lineWidth = 3
            glowWidth = 14
            coreNode.path = CGPath(ellipseIn: CGRect(x: -r * 0.42, y: -r * 0.42, width: r * 0.84, height: r * 0.84), transform: nil)
            coreNode.fillColor = UIColor.white.withAlphaComponent(0.88)
        }
        if wallStyleMode {
            glowWidth = 4
            auraNode.glowWidth = 5
            warningRingNode.glowWidth = 4
            tailNode.glowWidth = 3
            auraNode.fillColor = fillColor.withAlphaComponent(0.12)
            warningRingNode.lineWidth += 0.4
            coreNode.fillColor = UIColor.white.withAlphaComponent(0.26)
        }
        updatePresentation(progress: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setTrackingEmphasis(_ emphasis: CGFloat) {
        trackingEmphasis = max(0, min(1, emphasis))
    }

    var effectiveArrivalTime: Double {
        liveTravelBaselineOverride?.arrivalTime
            ?? normalizationState?.normalizedArrivalTime
            ?? reentryState?.arrivalTime
            ?? arrivalTime
    }

    var effectiveSpawnTime: Double {
        liveTravelBaselineOverride?.spawnTime
            ?? normalizationState?.normalizedSpawnTime
            ?? reentryState?.spawnTime
            ?? spawnTime
    }

    var effectiveTravelSeconds: Double {
        liveTravelBaselineOverride?.travelSeconds
            ?? normalizationState?.travelSeconds
            ?? reentryState?.travelSeconds
            ?? travelSeconds
    }

    var effectiveSpawnPoint: CGPoint {
        liveTravelBaselineOverride?.spawnPoint
            ?? normalizationState?.startPoint
            ?? reentryState?.startPoint
            ?? spawnPoint
    }

    var effectiveStrikePoint: CGPoint {
        liveTravelBaselineOverride?.strikePoint
            ?? normalizationState?.strikePoint
            ?? reentryState?.strikePoint
            ?? strikePoint
    }

    var effectiveSpawnScale: CGFloat {
        liveTravelBaselineOverride?.spawnScale ?? spawnScale
    }

    var effectiveStrikeScale: CGFloat {
        liveTravelBaselineOverride?.strikeScale ?? strikeScale
    }

    var effectiveOverrunScale: CGFloat {
        liveTravelBaselineOverride?.overrunScale ?? overrunScale
    }

    var effectiveCurveAmount: CGFloat {
        liveTravelBaselineOverride?.curveAmount ?? curveAmount
    }

    func isHittable(at trackTime: Double) -> Bool {
        let armed = normalizationState?.frame(at: trackTime).armed
            ?? reentryState?.frame(at: trackTime).armed
            ?? true
        return ownershipPhase.isHittable && armed
    }

    var hasOwnedMotionState: Bool {
        reentryState != nil || normalizationState != nil
    }

    func beginReentry(_ state: RallyReentryBallState) {
        liveTravelBaselineOverride = nil
        normalizationState = nil
        reentryState = state
        ownershipPhase = .reentry
        position = state.startPoint
        alpha = 1
        zRotation = 0
    }

    func beginNormalization(_ state: RallyBallNormalizationState) {
        reentryState = nil
        normalizationState = state
        ownershipPhase = .normalization
        alpha = 1
        zRotation = 0
    }

    func finalizeNormalization() {
        guard let normalizationState else { return }
        liveTravelBaselineOverride = normalizationState.makeLiveTravelBaseline(
            spawnScale: effectiveSpawnScale,
            overrunScale: effectiveOverrunScale
        )
        self.normalizationState = nil
        ownershipPhase = .liveTravel
    }

    func applyReentryFrame(_ frame: RallyReentryBallFrame, trackTime: Double) {
        position = frame.point
        xScale = frame.xScale
        yScale = frame.yScale
        alpha = 1
        warningRingNode.alpha = frame.armed ? 0.22 : 0.08
        focusRingNode.alpha = frame.armed ? 0.14 : 0
        auraNode.alpha = frame.armed ? 0.34 : 0.18
        coreNode.alpha = frame.armed ? 0.28 : 0.2
        shadowNode.alpha = frame.shadowAlpha
        shadowNode.xScale = 1.0 + (1 - frame.shadowAlpha) * 0.42
        shadowNode.yScale = 0.9
        wallShadowNode.alpha = 0
        seamGroup.zRotation = 0.1
        zRotation = 0
        updateSpecular(
            progress: 0.88,
            altitude: max(0, (1 - frame.shadowAlpha) * 42),
            compression: max(0, frame.yScale - 1)
        )
        if let reentryState {
            updateTail(progress: min(1, CGFloat((trackTime - reentryState.startTime) / max(0.0001, reentryState.travelSeconds))), eased: 0.82, bounceProgress: 0.74, overrun: 0)
        }
        // Return-leg urgency read: tail brightens and lengthens with the
        // accelerating return speed instead of holding a fixed dim alpha.
        tailNode.alpha = Tunables.wallReturnTailAlphaFloor
            + (Tunables.wallReturnTailAlphaPeak - Tunables.wallReturnTailAlphaFloor) * frame.speedScalar
        tailNode.xScale *= 0.88 + frame.speedScalar * 0.42
        tailNode.yScale *= 0.94 + frame.speedScalar * 0.18
    }

    @discardableResult
    func updateReentry(trackTime: Double) -> Bool {
        guard let reentryState else { return false }
        let frame = reentryState.frame(at: trackTime)
        applyReentryFrame(frame, trackTime: trackTime)

        if frame.isComplete {
            self.reentryState = nil
            return true
        }
        return false
    }

    @discardableResult
    func updateNormalization(trackTime: Double) -> Bool {
        guard let normalizationState else { return false }
        let frame = normalizationState.frame(at: trackTime)
        position = frame.point
        xScale = frame.xScale
        yScale = frame.yScale
        alpha = 1
        warningRingNode.alpha = frame.armed ? 0.14 : 0.06
        focusRingNode.alpha = frame.armed ? 0.12 : 0
        auraNode.alpha = frame.armed ? 0.28 : 0.16
        coreNode.alpha = frame.armed ? 0.24 : 0.18
        tailNode.alpha = frame.isNormalized ? 0.08 : 0.12
        shadowNode.alpha = frame.shadowAlpha
        shadowNode.xScale = 1.0 + (1 - frame.shadowAlpha) * 0.34
        shadowNode.yScale = 0.9
        wallShadowNode.alpha = 0
        seamGroup.zRotation = 0.04
        zRotation = 0
        updateSpecular(
            progress: frame.isNormalized ? 0.82 : 0.9,
            altitude: max(0, (1 - frame.shadowAlpha) * 30),
            compression: max(0, frame.xScale - 1)
        )
        updateTail(
            progress: min(1, CGFloat((trackTime - normalizationState.startTime) / max(0.0001, normalizationState.travelSeconds))),
            eased: frame.isNormalized ? 0.74 : 0.86,
            bounceProgress: 0.76,
            overrun: max(0, CGFloat((trackTime - normalizationState.strikeTime) / 0.24))
        )

        if frame.isExpired {
            finalizeNormalization()
            return true
        }
        return false
    }

    func approachToStrike(at trackTime: Double) -> CGFloat {
        let progress = max(0, min(1.12, CGFloat((trackTime - effectiveSpawnTime) / effectiveTravelSeconds)))
        let distanceToArrival = abs(1 - progress)
        let nearWindow = max(0, 1 - distanceToArrival / Tunables.wallApproachWindowRatio)
        return min(1, nearWindow)
    }

    func updatePresentation(progress rawProgress: CGFloat) {
        let progress = max(0, min(1.18, rawProgress))
        let eased = remappedProgress(for: progress)
        let overrun = max(0, progress - 1.0)
        let bounceProgress = bounceProgressForShape()
        let adjusted = progressThroughBounce(for: eased, bounceProgress: bounceProgress)
        let startPoint = effectiveSpawnPoint
        let endPoint = effectiveStrikePoint
        let baseX = lerp(from: startPoint.x, to: endPoint.x, progress: adjusted)
        let baseY = lerp(from: startPoint.y, to: endPoint.y, progress: adjusted)
        let curveDirection: CGFloat = lane == .left ? -1 : 1
        let curve = sin(eased * .pi) * curveAmountForShape() * abs(endPoint.x - startPoint.x)
        let arcLift = flightLift(for: eased, bounceProgress: bounceProgress)
        let bounceKick = bounceKickLift(for: eased, bounceProgress: bounceProgress)
        let compression = bounceCompression(for: eased, bounceProgress: bounceProgress)
        let launchStretch = wallLaunchStretch(for: eased)
        let altitude = max(0, arcLift + bounceKick)

        position = CGPoint(
            x: baseX + curveDirection * curve,
            y: baseY + arcLift + bounceKick - overrun * overrunDropDistance()
        )

        let scale: CGFloat
        if wallStyleMode, progress <= 1 {
            let contactEmphasis = wallContactEmphasis(for: eased)
            let nearScale = strikeScaleForShape()
            let farScale = nearScale * Tunables.ballDepthScaleFar
            scale = lerp(
                from: farScale,
                to: nearScale,
                progress: eased
            ) + contactEmphasis * 0.08
        } else if progress <= 1 {
            scale = lerp(from: effectiveSpawnScale, to: strikeScaleForShape(), progress: eased)
        } else {
            scale = lerp(
                from: strikeScaleForShape(),
                to: overrunScaleForShape(),
                progress: min(1, overrun * 2.5)
            )
        }
        xScale = scale * (1 + compression * 0.48 - launchStretch * 0.10)
        yScale = scale * (1 - compression * 0.28 + launchStretch * 0.22)

        zRotation = curveDirection * rotationForShape(progress: eased)
        seamGroup.zRotation = seamRotation(for: eased) * curveDirection
        alpha = progress <= 1 ? 1.0 : max(0.55, 1 - overrun * 1.8)
        let trackingLift = trackingEmphasisForProgress(progress: eased, bounceProgress: bounceProgress)
        let wallApproachLift: CGFloat = wallStyleMode ? max(0, 1 - abs(eased - 0.78) / 0.32) : 0
        let wallLockLift: CGFloat = wallStyleMode ? max(0, 1 - abs(eased - 0.86) / 0.14) : 0
        let wallVisualScalar: CGFloat = wallStyleMode ? 0.48 : 1.0
        warningRingNode.alpha = progress <= 1 ? min(1, ((1 - eased * 0.92) + trackingLift * 0.52 + wallApproachLift * 0.18) * wallVisualScalar) : 0
        auraNode.alpha = min(1, (auraAlpha(for: progress) + trackingLift * 0.18 + wallApproachLift * 0.12 + wallLockLift * 0.08) * wallVisualScalar)
        coreNode.alpha = min(1, coreAlpha(for: progress) + trackingLift * 0.12 + wallApproachLift * 0.05 + wallLockLift * 0.10)
        coreNode.setScale(coreScale(for: progress) + trackingLift * 0.08 + wallApproachLift * 0.05 + wallLockLift * 0.08)
        warningRingNode.lineWidth = ringWidth(for: progress) + trackingLift * 1.2
        warningRingNode.glowWidth = (baseRingGlowWidth() + trackingLift * 10) * wallVisualScalar
        warningRingNode.strokeColor = trackingStrokeColor(intensity: trackingLift)
        focusRingNode.alpha = (focusRingAlpha(progress: eased, trackingLift: trackingLift) + wallLockLift * 0.36) * wallVisualScalar
        focusRingNode.lineWidth = 1.4 + trackingLift * 1.6 + wallLockLift * 1.2
        focusRingNode.glowWidth = (trackingLift * (kind == .double ? 14 : 10) + wallLockLift * 8) * wallVisualScalar
        focusRingNode.setScale(1.0 + trackingLift * 0.18 - wallLockLift * 0.08)
        focusRingNode.strokeColor = focusRingColor(intensity: min(1, trackingLift + wallLockLift * 0.55))
        updateSpecular(progress: eased, altitude: altitude, compression: compression)
        updateTail(progress: progress, eased: eased, bounceProgress: bounceProgress, overrun: overrun)
        updateShadow(progress: eased, bounceProgress: bounceProgress, overrun: overrun, altitude: altitude)
    }

    func applyLiveExchangeFrame(_ frame: RallyContinuousBallExchangeFrame) {
        position = frame.point
        xScale = frame.xScale
        yScale = frame.yScale
        alpha = frame.alpha

        warningRingNode.alpha = 0
        focusRingNode.alpha = 0
        auraNode.alpha = max(0.12, frame.shadowAlpha * 0.62)
        coreNode.alpha = max(0.18, frame.shadowAlpha * 0.82)
        let reboundSpeedBoost: CGFloat = frame.phase == .wallRebound ? 1.0 : 0.42
        tailNode.alpha = 0.08 + reboundSpeedBoost * 0.28
        tailNode.xScale = 0.92 + reboundSpeedBoost * 0.46
        tailNode.yScale = 0.76 + reboundSpeedBoost * 0.18

        shadowNode.alpha = frame.shadowAlpha
        shadowNode.xScale = frame.shadowXScale
        shadowNode.yScale = 0.82 + reboundSpeedBoost * 0.08

        wallShadowNode.alpha = max(0, frame.shadowAlpha - 0.08)
        wallShadowNode.xScale = frame.shadowXScale * 0.92
        wallShadowNode.yScale = 0.88

        seamGroup.zRotation = frame.phase == .wallRebound ? 0.18 : 0.04
        zRotation = frame.phase == .wallCompression || frame.phase == .wallDwell ? 0.04 : 0
        updateSpecular(
            progress: frame.phase == .wallRebound ? 0.92 : 0.74,
            altitude: max(0, (1 - frame.shadowAlpha) * 48),
            compression: max(0, frame.xScale - 1)
        )
    }

    func contactWindowPhase(at trackTime: Double) -> ContactWindowPhase {
        let rawProgress = CGFloat(max(0, min(1.12, (trackTime - effectiveSpawnTime) / effectiveTravelSeconds)))
        let progress = remappedProgress(for: rawProgress)
        let bounce = bounceProgressForShape()
        if progress < bounce { return .approach }
        let postBounce = (progress - bounce) / max(0.001, 1 - bounce)
        switch postBounce {
        case ..<0.28: return .rise
        case ..<0.68: return .peak
        default:      return .fall
        }
    }

    private func lerp(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    private func remappedProgress(for progress: CGFloat) -> CGFloat {
        if wallStyleMode {
            let clamped = min(1, progress)
            if clamped < Tunables.wallLaunchHoldProgress {
                let hold = clamped / max(0.001, Tunables.wallLaunchHoldProgress)
                return hold * 0.018
            } else if clamped < Tunables.wallLaunchReleaseProgress {
                let release = (clamped - Tunables.wallLaunchHoldProgress) / max(0.001, Tunables.wallLaunchReleaseProgress - Tunables.wallLaunchHoldProgress)
                return 0.018 + pow(release, 0.58) * 0.26
            } else if clamped < Tunables.wallCruiseProgress {
                let mid = (clamped - Tunables.wallLaunchReleaseProgress) / max(0.001, Tunables.wallCruiseProgress - Tunables.wallLaunchReleaseProgress)
                return 0.278 + (1 - pow(1 - mid, 1.34)) * 0.58
            } else {
                let settle = (clamped - Tunables.wallCruiseProgress) / max(0.001, 1 - Tunables.wallCruiseProgress)
                return 0.858 + (1 - pow(1 - settle, 1.96)) * 0.142
            }
        }
        switch shotShape {
        case .drive:
            return progress * progress * (3 - 2 * progress)
        case .topspin:
            let steeper = min(1, pow(progress, 0.86))
            return steeper * steeper * (3 - 2 * steeper)
        case .skid:
            let delayed = pow(progress, 1.22)
            return delayed * delayed * (3 - 2 * delayed)
        case .floater:
            let hanging = min(1, pow(progress, 1.45))
            return hanging * hanging * (3 - 2 * hanging)
        }
    }

    private func progressThroughBounce(for progress: CGFloat, bounceProgress: CGFloat) -> CGFloat {
        if wallStyleMode {
            let compressionCenter = Tunables.wallRacketCompressionCenter
            let compressionWidth = Tunables.wallRacketCompressionWidth
            if progress < compressionCenter - compressionWidth {
                let local = progress / max(0.001, compressionCenter - compressionWidth)
                let accelerated = 1 - pow(1 - local, 1.42)
                return accelerated * 0.986
            }

            let local = (progress - (compressionCenter - compressionWidth)) / max(0.001, compressionWidth * 2)
            let eased = min(1, max(0, local))
            let brake = sin(eased * .pi) * 0.036
            return max(0.94, min(1, 0.986 + eased * 0.014 - brake))
        }
        if progress <= bounceProgress {
            let local = progress / max(0.001, bounceProgress)
            return bounceProgress * local * local * (3 - 2 * local)
        }
        let local = (progress - bounceProgress) / max(0.001, 1 - bounceProgress)
        let accelerated = min(1, pow(local, postBounceAccelerationForShape()))
        return bounceProgress + (1 - bounceProgress) * accelerated
    }

    private func flightLift(for progress: CGFloat, bounceProgress: CGFloat) -> CGFloat {
        if wallStyleMode {
            let laneDistance = abs(strikePoint.x - spawnPoint.x)
            let releaseProgress = min(1, progress / max(0.001, Tunables.wallLaunchReleaseProgress))
            let launchLift = sin(min(.pi / 2, releaseProgress * (.pi / 2))) * laneDistance * Tunables.wallInboundLiftRatio
            let cruiseLift = sin(min(.pi, progress * .pi * 0.96)) * laneDistance * 0.010
            let gravityPull = pow(max(0, progress - 0.28), 1.56) * laneDistance * Tunables.wallInboundGravityRatio
            let racketSink = wallContactEmphasis(for: progress) * laneDistance * 0.016
            return max(0, launchLift + cruiseLift - gravityPull - racketSink)
        }
        if progress <= bounceProgress {
            let local = progress / max(0.001, bounceProgress)
            let height = wallStyleMode ? arcHeightForShape() * 0.78 : arcHeightForShape()
            return sin(local * .pi) * height
        }
        let local = (progress - bounceProgress) / max(0.001, 1 - bounceProgress)
        let reboundHeight = wallStyleMode ? bounceKickHeightForShape() * 0.82 : bounceKickHeightForShape()
        let reboundScalar: CGFloat = wallStyleMode ? 0.3 : 0.45
        return sin(local * .pi * 0.82) * reboundHeight * reboundScalar
    }

    private func bounceKickLift(for progress: CGFloat, bounceProgress: CGFloat) -> CGFloat {
        if wallStyleMode {
            return 0
        }
        guard progress >= bounceProgress else { return 0 }
        let local = (progress - bounceProgress) / max(0.001, 1 - bounceProgress)
        let kickScale: CGFloat = wallStyleMode ? 0.82 : 1.0
        let kick = sin(min(.pi, local * .pi)) * bounceKickHeightForShape() * kickScale
        return -kick
    }

    private func bounceCompression(for progress: CGFloat, bounceProgress: CGFloat) -> CGFloat {
        if wallStyleMode {
            let compression = wallContactEmphasis(for: progress) * Tunables.wallRacketCompressionAmount
            let launchStretch = wallLaunchStretch(for: progress) * 0.34
            return max(0, compression + launchStretch)
        }
        let distance = abs(progress - bounceProgress)
        let width = max(0.035, bounceCompressionForShape())
        guard distance < width else { return 0 }
        return 1 - distance / width
    }

    private func updateShadow(progress: CGFloat, bounceProgress: CGFloat, overrun: CGFloat, altitude: CGFloat) {
        let altitudeScalar = max(0, min(1, altitude / max(18, arcHeightForShape())))
        if wallStyleMode {
            let depthScale = lerp(from: Tunables.ballDepthScaleFar, to: Tunables.ballDepthScaleNear, progress: min(1, progress))
            let wallContact = wallContactEmphasis(for: progress)
            let release = wallLaunchStretch(for: progress)
            shadowNode.xScale = (0.82 + depthScale * 0.62) * (1 + altitudeScalar * 0.12)
            shadowNode.yScale = (0.54 + depthScale * 0.24) * (1 - altitudeScalar * 0.20)
            shadowNode.position = CGPoint(
                x: shadowOffsetX(for: progress, altitudeScalar: altitudeScalar) * 0.42,
                y: -10 - altitudeScalar * 10
            )
            shadowNode.alpha = max(
                0.08,
                Tunables.bounceShadowAlpha * (0.92 - altitudeScalar * Tunables.ballShadowHighAlphaScalar) - overrun * 0.10
            )
            wallShadowNode.alpha = wallContact * (0.12 + trackingEmphasis * 0.08) + release * 0.18
            wallShadowNode.position = CGPoint(x: curveDirectionForLane() * (6 - release * 5), y: 6 + wallContact * 12)
            wallShadowNode.xScale = 0.84 + wallContact * 0.28 + release * 0.18
            wallShadowNode.yScale = 0.52 + wallContact * 0.18 - release * 0.06
            return
        }

        let depthScale = lerp(from: 0.48, to: 1.18, progress: min(1, progress)) + altitudeScalar * 0.18
        let widthBoost = 1.0 + altitudeScalar * 0.22
        shadowNode.xScale = depthScale * widthBoost
        shadowNode.yScale = depthScale * (0.86 - altitudeScalar * 0.18)
        shadowNode.position = CGPoint(
            x: shadowOffsetX(for: progress, altitudeScalar: altitudeScalar),
            y: shadowOffsetY(for: progress, bounceProgress: bounceProgress, overrun: overrun)
        )
        let fadeStart = max(0, bounceProgress - 0.14)
        let alpha: CGFloat
        if progress >= bounceProgress {
            alpha = Tunables.bounceShadowAlpha * max(0.22, 0.62 - altitudeScalar * 0.24)
        } else if progress >= fadeStart {
            let fade = 1 - ((progress - fadeStart) / max(0.001, bounceProgress - fadeStart))
            alpha = Tunables.bounceShadowAlpha * max(0.28, fade) * (0.94 - altitudeScalar * 0.3)
        } else {
            alpha = Tunables.bounceShadowAlpha * (0.96 - altitudeScalar * 0.28)
        }
        shadowNode.alpha = max(0, alpha - overrun * 0.18)

        if wallStyleMode {
            let wallContact = wallContactEmphasis(for: progress)
            let release = wallLaunchStretch(for: progress)
            wallShadowNode.alpha = wallContact * (0.12 + trackingEmphasis * 0.08) + release * 0.18
            wallShadowNode.position = CGPoint(x: curveDirectionForLane() * (6 - release * 5), y: 6 + wallContact * 12)
            wallShadowNode.xScale = 0.84 + wallContact * 0.28 + release * 0.18
            wallShadowNode.yScale = 0.52 + wallContact * 0.18 - release * 0.06
        } else {
            wallShadowNode.alpha = 0
        }
    }

    private func updateTail(progress: CGFloat, eased: CGFloat, bounceProgress: CGFloat, overrun: CGFloat) {
        let curveDirection: CGFloat = lane == .left ? -1 : 1
        let motion = max(0, 1 - eased)
        let airborne = max(0, (bounceProgress - min(eased, bounceProgress)) / max(0.001, bounceProgress))
        let speedScalar = wallStyleMode
            ? max(Tunables.ballTrailMinSpeedScalar, min(Tunables.ballTrailMaxSpeedScalar, 0.28 + eased * 0.88))
            : max(Tunables.ballTrailMinSpeedScalar, min(Tunables.ballTrailMaxSpeedScalar, 0.18 + motion * 0.82))
        let baseLength = tailLengthForRole() * (0.72 + speedScalar * 0.92)
        let xOffset = -curveDirection * baseLength * 0.34
        let yOffset = -14 - baseLength * 0.18
        tailNode.position = CGPoint(x: xOffset, y: yOffset)
        tailNode.zRotation = zRotation + curveDirection * 0.18
        tailNode.xScale = 0.62 + baseLength / 24
        tailNode.yScale = 0.66 + speedScalar * 0.26 + airborne * 0.12

        let roleAlpha = tailAlphaForRole()
        if overrun > 0 {
            tailNode.alpha = 0
        } else if wallStyleMode {
            tailNode.alpha = roleAlpha * (0.22 + speedScalar * 0.42)
        } else if eased >= bounceProgress {
            tailNode.alpha = roleAlpha * speedScalar * 0.32
        } else {
            tailNode.alpha = roleAlpha * max(airborne, 0.24) * max(0.18, 1 - eased * 0.88)
        }
    }

    private func shadowOffsetY(for progress: CGFloat, bounceProgress: CGFloat, overrun: CGFloat) -> CGFloat {
        let offset = progress < bounceProgress ? 18 - progress * 8 : 10 + overrun * 18
        return -offset
    }

    private func shadowOffsetX(for progress: CGFloat, altitudeScalar: CGFloat) -> CGFloat {
        let lightDirection = curveDirectionForLane() * -1
        let drift = (0.18 + progress * 0.12 + altitudeScalar * 0.14) * Tunables.ballRadiusPoints
        return lightDirection * drift
    }

    private func wallContactEmphasis(for progress: CGFloat) -> CGFloat {
        max(0, 1 - abs(progress - Tunables.wallRacketCompressionCenter) / Tunables.wallRacketCompressionWidth)
    }

    private func wallLaunchStretch(for progress: CGFloat) -> CGFloat {
        guard wallStyleMode else { return 0 }
        let release = max(0, 1 - progress / max(0.001, Tunables.wallLaunchReleaseProgress))
        return pow(release, 0.72)
    }

    private func seamRotation(for progress: CGFloat) -> CGFloat {
        let spinRate: CGFloat
        switch shotShape {
        case .drive:
            spinRate = wallStyleMode ? 9.6 : 7.6
        case .topspin:
            spinRate = wallStyleMode ? 11.6 : 9.2
        case .skid:
            spinRate = wallStyleMode ? -6.0 : -4.4
        case .floater:
            spinRate = wallStyleMode ? 3.0 : 2.4
        }
        return progress * .pi * spinRate
    }

    private func updateSpecular(progress: CGFloat, altitude: CGFloat, compression: CGFloat) {
        let highlightTravel = lerp(from: -5, to: 7, progress: progress)
        let altitudeScalar = max(0, min(1, altitude / max(18, arcHeightForShape())))
        specularNode.position = CGPoint(
            x: highlightTravel,
            y: 6 + altitudeScalar * 3 - compression * 1.6
        )
        specularNode.xScale = 1.0 + compression * 0.34
        specularNode.yScale = 0.76 - compression * 0.18
        specularNode.alpha = 0.18 + (1 - progress) * 0.14 + altitudeScalar * 0.10
    }

    private func curveDirectionForLane() -> CGFloat {
        lane == .left ? -1 : 1
    }

    private func arcHeightForShape() -> CGFloat {
        let base: CGFloat
        switch shotShape {
        case .drive: base = Tunables.driveArcHeight
        case .topspin: base = Tunables.topspinArcHeight
        case .skid: base = Tunables.skidArcHeight
        case .floater: base = Tunables.floaterArcHeight
        }
        switch role {
        case .serve: return base * 0.76
        case .returnBall: return base * 0.92
        case .changeup: return base * 1.18
        case .rally: return base
        }
    }

    private func curveAmountForShape() -> CGFloat {
        let base: CGFloat
        switch shotShape {
        case .drive: base = effectiveCurveAmount * 0.9
        case .topspin: base = effectiveCurveAmount * 1.18
        case .skid: base = effectiveCurveAmount * 0.78
        case .floater: base = effectiveCurveAmount * 1.08
        }
        switch role {
        case .serve: return base * 0.82
        case .returnBall: return base * 0.94
        case .changeup: return base * 1.12
        case .rally: return base
        }
    }

    private func strikeScaleForShape() -> CGFloat {
        let base: CGFloat
        switch shotShape {
        case .drive: base = effectiveStrikeScale * 1.03
        case .topspin: base = effectiveStrikeScale * 1.02
        case .skid: base = effectiveStrikeScale * 0.98
        case .floater: base = effectiveStrikeScale * 0.94
        }
        switch role {
        case .serve: return base * 1.04
        case .returnBall: return base * 0.98
        case .changeup: return base * 1.06
        case .rally: return base
        }
    }

    private func overrunScaleForShape() -> CGFloat {
        let base: CGFloat
        switch shotShape {
        case .drive: base = effectiveOverrunScale * 1.02
        case .topspin: base = effectiveOverrunScale * 1.03
        case .skid: base = effectiveOverrunScale * 0.97
        case .floater: base = effectiveOverrunScale * 0.95
        }
        switch role {
        case .serve: return base * 1.02
        case .returnBall: return base * 0.98
        case .changeup: return base * 1.05
        case .rally: return base
        }
    }

    private func overrunDropDistance() -> CGFloat {
        switch shotShape {
        case .drive: return 40
        case .topspin: return 52
        case .skid: return 30
        case .floater: return 24
        }
    }

    private func bounceProgressForShape() -> CGFloat {
        let base: CGFloat
        switch shotShape {
        case .drive: base = Tunables.driveBounceProgress
        case .topspin: base = Tunables.topspinBounceProgress
        case .skid: base = Tunables.skidBounceProgress
        case .floater: base = Tunables.floaterBounceProgress
        }
        switch role {
        case .serve: return min(0.88, base + 0.04)
        case .returnBall: return min(0.84, base + 0.02)
        case .changeup: return max(0.58, base - 0.04)
        case .rally: return base
        }
    }

    private func bounceKickHeightForShape() -> CGFloat {
        let base: CGFloat
        switch shotShape {
        case .drive: base = Tunables.driveBounceKick
        case .topspin: base = Tunables.topspinBounceKick
        case .skid: base = Tunables.skidBounceKick
        case .floater: base = Tunables.floaterBounceKick
        }
        switch role {
        case .serve: return base * 0.74
        case .returnBall: return base * 0.92
        case .changeup: return base * 1.22
        case .rally: return base
        }
    }

    private func bounceCompressionForShape() -> CGFloat {
        switch shotShape {
        case .drive: return Tunables.driveBounceCompression
        case .topspin: return Tunables.topspinBounceCompression
        case .skid: return Tunables.skidBounceCompression
        case .floater: return Tunables.floaterBounceCompression
        }
    }

    private func postBounceAccelerationForShape() -> CGFloat {
        let base: CGFloat
        switch shotShape {
        case .drive: base = Tunables.drivePostBounceAcceleration
        case .topspin: base = Tunables.topspinPostBounceAcceleration
        case .skid: base = Tunables.skidPostBounceAcceleration
        case .floater: base = Tunables.floaterPostBounceAcceleration
        }
        switch role {
        case .serve: return base * 1.08
        case .returnBall: return base * 0.96
        case .changeup: return base * 0.92
        case .rally: return base
        }
    }

    private func rotationForShape(progress: CGFloat) -> CGFloat {
        switch shotShape {
        case .drive: return 0.05 + 0.08 * progress
        case .topspin: return 0.07 + 0.12 * progress
        case .skid: return 0.03 + 0.05 * progress
        case .floater: return 0.06 + 0.07 * progress
        }
    }

    private func auraAlpha(for progress: CGFloat) -> CGFloat {
        let base: CGFloat
        switch role {
        case .serve: base = 0.82
        case .returnBall: base = 0.74
        case .changeup: base = 0.9
        case .rally: base = kind == .double ? 0.78 : 0.58
        }
        return max(0.18, base - progress * 0.42)
    }

    private func coreAlpha(for progress: CGFloat) -> CGFloat {
        let base: CGFloat
        switch role {
        case .serve: base = 0.42
        case .returnBall: base = 0.54
        case .changeup: base = 0.64
        case .rally: base = kind == .double ? 0.82 : 0.28
        }
        return max(0.08, base - progress * 0.18)
    }

    private func coreScale(for progress: CGFloat) -> CGFloat {
        switch role {
        case .serve:
            return 0.86 + (1 - progress) * 0.08
        case .returnBall:
            return 0.94 + (1 - progress) * 0.06
        case .changeup:
            return 1.0 + (1 - progress) * 0.08
        case .rally:
            return kind == .double ? 1.0 : 0.82
        }
    }

    private func ringWidth(for progress: CGFloat) -> CGFloat {
        let base: CGFloat
        switch role {
        case .serve: base = 3.2
        case .returnBall: base = 2.2
        case .changeup: base = 2.8
        case .rally: base = kind == .double ? 3.0 : 2.0
        }
        return max(1.2, base - progress * 0.8)
    }

    private func baseRingGlowWidth() -> CGFloat {
        switch role {
        case .serve: return kind == .double ? 14 : 10
        case .returnBall: return kind == .double ? 10 : 6
        case .changeup: return kind == .double ? 10 : 6
        case .rally: return kind == .double ? 10 : 6
        }
    }

    private func trackingEmphasisForProgress(progress: CGFloat, bounceProgress: CGFloat) -> CGFloat {
        guard trackingEmphasis > 0 else { return 0 }
        if progress >= bounceProgress {
            return trackingEmphasis * 0.18
        }
        let airborne = max(0, (bounceProgress - min(progress, bounceProgress)) / max(0.001, bounceProgress))
        return trackingEmphasis * (0.42 + airborne * 0.58)
    }

    private func trackingStrokeColor(intensity: CGFloat) -> UIColor {
        guard intensity > 0.001 else {
            switch role {
            case .changeup:
                return UIColor.white.withAlphaComponent(0.92)
            default:
                return fillColor.withAlphaComponent(kind == .double ? 0.95 : 0.65)
            }
        }
        return fillColor.blended(withFraction: intensity * 0.58, of: .white)
            ?? fillColor.withAlphaComponent(kind == .double ? 0.95 : 0.65)
    }

    private func focusRingAlpha(progress: CGFloat, trackingLift: CGFloat) -> CGFloat {
        guard trackingLift > 0.001 else { return 0 }
        let phaseLift: CGFloat
        switch role {
        case .serve: phaseLift = 0.12
        case .returnBall: phaseLift = 0.08
        case .changeup: phaseLift = 0.18
        case .rally: phaseLift = kind == .double ? 0.22 : 0.04
        }
        return min(0.92, trackingLift * (0.34 + phaseLift) * max(0.22, 1 - progress * 0.72))
    }

    private func focusRingColor(intensity: CGFloat) -> UIColor {
        let emphasized = fillColor.blended(withFraction: min(0.8, intensity * 0.7), of: .white) ?? fillColor
        if kind == .double {
            return emphasized.blended(withFraction: 0.35, of: UIColor(red: 1.0, green: 0.9, blue: 0.74, alpha: 1))
                ?? emphasized
        }
        if role == .changeup {
            return UIColor.white.blended(withFraction: 0.42, of: emphasized) ?? emphasized
        }
        return emphasized
    }

    private func tailLengthForRole() -> CGFloat {
        let shapeBase: CGFloat
        switch shotShape {
        case .drive: shapeBase = 14
        case .topspin: shapeBase = 18
        case .skid: shapeBase = 20
        case .floater: shapeBase = 12
        }
        switch role {
        case .serve: return shapeBase * 1.14
        case .returnBall: return shapeBase * 0.9
        case .changeup: return shapeBase * 1.06
        case .rally: return shapeBase
        }
    }

    private func tailAlphaForRole() -> CGFloat {
        switch role {
        case .serve: return 0.34
        case .returnBall: return 0.24
        case .changeup: return 0.3
        case .rally: return kind == .double ? 0.34 : 0.22
        }
    }

    private static func lowerRightRimPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: radius * 0.18, y: -radius * 0.96))
        path.addCurve(
            to: CGPoint(x: radius * 0.96, y: -radius * 0.18),
            control1: CGPoint(x: radius * 0.58, y: -radius * 0.92),
            control2: CGPoint(x: radius * 0.92, y: -radius * 0.58)
        )
        path.addCurve(
            to: CGPoint(x: radius * 0.48, y: -radius * 0.60),
            control1: CGPoint(x: radius * 0.86, y: -radius * 0.32),
            control2: CGPoint(x: radius * 0.68, y: -radius * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: radius * 0.18, y: -radius * 0.96),
            control1: CGPoint(x: radius * 0.34, y: -radius * 0.70),
            control2: CGPoint(x: radius * 0.24, y: -radius * 0.84)
        )
        path.closeSubpath()
        return path
    }

    private static func seamPath(radius: CGFloat, phase: CGFloat) -> CGPath {
        let path = UIBezierPath()
        let start = phase + (.pi * 0.16)
        let end = phase + (.pi * 0.84)
        path.addArc(withCenter: .zero, radius: radius, startAngle: start, endAngle: end, clockwise: true)
        return path.cgPath
    }
}

private extension UIColor {
    func mixed(with other: UIColor, ratio: CGFloat) -> UIColor {
        blended(withFraction: ratio, of: other) ?? self
    }

    func brightened(_ amount: CGFloat) -> UIColor {
        blended(withFraction: amount, of: .white) ?? self
    }

    func blended(withFraction fraction: CGFloat, of other: UIColor) -> UIColor? {
        let clamped = min(max(fraction, 0), 1)

        var lhsRed: CGFloat = 0
        var lhsGreen: CGFloat = 0
        var lhsBlue: CGFloat = 0
        var lhsAlpha: CGFloat = 0
        var rhsRed: CGFloat = 0
        var rhsGreen: CGFloat = 0
        var rhsBlue: CGFloat = 0
        var rhsAlpha: CGFloat = 0

        guard getRed(&lhsRed, green: &lhsGreen, blue: &lhsBlue, alpha: &lhsAlpha),
              other.getRed(&rhsRed, green: &rhsGreen, blue: &rhsBlue, alpha: &rhsAlpha) else {
            return nil
        }

        let inv = 1 - clamped
        return UIColor(
            red: lhsRed * inv + rhsRed * clamped,
            green: lhsGreen * inv + rhsGreen * clamped,
            blue: lhsBlue * inv + rhsBlue * clamped,
            alpha: lhsAlpha * inv + rhsAlpha * clamped
        )
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
