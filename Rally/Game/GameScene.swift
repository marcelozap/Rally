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
        let racketHandleRotation: CGFloat
        let racketHeadRotation: CGFloat
        let racketHandleX: CGFloat
        let racketHandleY: CGFloat
        let racketHeadX: CGFloat
        let racketHeadY: CGFloat
        let shadowXScale: CGFloat
        let shadowYScale: CGFloat
        let shadowAlpha: CGFloat
    }

    // MARK: - Configuration

    /// How long a single rally session lasts before `sessionEnd` is fired.
    /// The procedural beatmap is generated to match.
    var sessionDurationSeconds: Double = 180
    var racketTuning: RacketGameplayTuning = .balanced
    var avatarSpec: AvatarVisualSpec?
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
    private var startTime: TimeInterval = 0
    private var currentTimeSnapshot: TimeInterval = 0
    private var currentTrackTime: TimeInterval = 0
    private var frameStopUntil: TimeInterval = 0
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
    private var strikeHalo: SKShapeNode!
    private var leftStrikeGate: SKShapeNode!
    private var rightStrikeGate: SKShapeNode!
    private var leftContactPocket: SKShapeNode!
    private var rightContactPocket: SKShapeNode!
    private var leftLaneGlow: SKShapeNode!
    private var rightLaneGlow: SKShapeNode!
    private var background: SynthwaveBackground!
    private var playerRoot: SKNode!
    private var playerTorso: SKShapeNode!
    private var playerNeck: SKShapeNode!
    private var playerHead: SKShapeNode!
    private var playerHair: SKShapeNode!
    private var playerLeadLeg: SKShapeNode!
    private var playerTrailLeg: SKShapeNode!
    private var playerLeadArm: SKShapeNode!
    private var playerTrailArm: SKShapeNode!
    private var playerRacketHandle: SKShapeNode!
    private var playerRacketHead: SKShapeNode!
    private var playerRacketStrings: [SKShapeNode] = []
    private var playerShadow: SKShapeNode!
    private var playerStanceGlow: SKShapeNode!
    private var playerRacketBaseColor: UIColor = UIColor(white: 0.78, alpha: 1)
    private var playerRacketAccentColor: UIColor = UIColor(red: 0, green: 0.9, blue: 1, alpha: 1)
    private var currentBPM: Double = 120
    private var currentTravelSeconds: Double = Tunables.ballTravelSeconds
    private var lastBeatTime: TimeInterval = 0
    private var sessionStartWallTime: TimeInterval = 0
    private var spawnedBallCount: Int = 0
    private var wallNextLane: Lane = .right

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
    private var recentContactLane: Lane?
    private var recoveryTrackUntil: TimeInterval = 0
    private var recoveryLane: Lane?
    private var recoverySeverity: CGFloat = 0

    private var cameraHomePosition: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
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
        setupCourtAvatar()
        setupHUD()
        didChangeSize(size)
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
            currentTravelSeconds = Tunables.ballTravelSeconds * 1.18 * matchPace.travelScalar
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
                    ? "One ball. Let it come in, then release through contact."
                    : "Meet the ball and release through contact.",
                hold: Tunables.openingHintSeconds * 0.45
            )
            if self.sessionMode == .wallRally {
                self.scheduleWallBall(after: 1.05)
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
        let glowWidth = size.width * 0.18
        let glowHeight = size.height * (Tunables.spawnLineYRatio - Tunables.strikeLineYRatio) + 60
        let glowRect = CGRect(x: -glowWidth / 2, y: 0, width: glowWidth, height: glowHeight)
        leftLaneGlow?.path = CGPath(roundedRect: glowRect, cornerWidth: glowWidth / 2, cornerHeight: glowWidth / 2, transform: nil)
        leftLaneGlow?.position = CGPoint(x: size.width * 0.3, y: strikeY)
        rightLaneGlow?.path = CGPath(roundedRect: glowRect, cornerWidth: glowWidth / 2, cornerHeight: glowWidth / 2, transform: nil)
        rightLaneGlow?.position = CGPoint(x: size.width * 0.7, y: strikeY)

        // Re-layout strike line if it exists.
        if let line = strikeLine {
            line.position = CGPoint(x: size.width / 2, y: strikeY)
            line.path = CGPath(
                rect: CGRect(x: -size.width / 2, y: -1, width: size.width, height: 2),
                transform: nil
            )
        }
        strikeHalo?.position = CGPoint(x: size.width / 2, y: strikeY)
        leftStrikeGate?.position = CGPoint(x: size.width * 0.28, y: strikeY)
        rightStrikeGate?.position = CGPoint(x: size.width * 0.72, y: strikeY)
        leftContactPocket?.position = racketContactPoint(for: .left)
        rightContactPocket?.position = racketContactPoint(for: .right)
        if let label = scoreLabel {
            label.position = CGPoint(x: size.width / 2, y: size.height * 0.875)
        }
        hudTopPlate?.path = CGPath(
            roundedRect: CGRect(
                x: -(usesMinimalWallHUD ? 206.0 / 2 : 288.0 / 2),
                y: -(usesMinimalWallHUD ? 82.0 / 2 : 104.0 / 2),
                width: usesMinimalWallHUD ? 206 : 288,
                height: usesMinimalWallHUD ? 82 : 104
            ),
            cornerWidth: usesMinimalWallHUD ? 26 : 30,
            cornerHeight: usesMinimalWallHUD ? 26 : 30,
            transform: nil
        )
        hudTopPlate?.position = CGPoint(x: size.width / 2, y: usesMinimalWallHUD ? size.height * 0.892 : size.height * 0.885)
        hudCaptionLabel?.position = CGPoint(x: size.width / 2, y: size.height * 0.934)
        hudPhaseLabel?.position = CGPoint(x: size.width * 0.27, y: size.height * 0.915)
        hudPhaseValueLabel?.position = CGPoint(x: size.width * 0.27, y: size.height * 0.889)
        hudMaxLabel?.position = CGPoint(x: usesMinimalWallHUD ? size.width * 0.72 : size.width * 0.73, y: usesMinimalWallHUD ? size.height * 0.907 : size.height * 0.915)
        hudMaxValueLabel?.position = CGPoint(x: usesMinimalWallHUD ? size.width * 0.72 : size.width * 0.73, y: usesMinimalWallHUD ? size.height * 0.882 : size.height * 0.889)
        if let combo = comboLabel {
            combo.position = CGPoint(x: size.width / 2, y: usesMinimalWallHUD ? size.height * 0.81 : size.height * 0.838)
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
        let line = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -0.5, width: size.width, height: 1))
        line.position = CGPoint(x: size.width / 2, y: y)
        line.strokeColor = .clear
        line.fillColor = UIColor(red: 0.88, green: 0.96, blue: 1, alpha: 0.08)
        line.glowWidth = 1.5
        line.zPosition = 10
        addChild(line)
        strikeLine = line

        let strikeHalo = SKShapeNode(rectOf: CGSize(width: size.width * 0.54, height: 12), cornerRadius: 6)
        strikeHalo.fillColor = UIColor(white: 1.0, alpha: 0.015)
        strikeHalo.strokeColor = .clear
        strikeHalo.position = CGPoint(x: size.width / 2, y: y)
        strikeHalo.zPosition = 9
        addChild(strikeHalo)
        self.strikeHalo = strikeHalo

        let gateSize = CGSize(width: size.width * 0.16, height: 22)
        let leftGate = SKShapeNode(rectOf: gateSize, cornerRadius: 11)
        leftGate.fillColor = UIColor(red: 0.33, green: 0.88, blue: 0.95, alpha: 0.08)
        leftGate.strokeColor = UIColor(red: 0.33, green: 0.88, blue: 0.95, alpha: 0.26)
        leftGate.lineWidth = 1.5
        leftGate.glowWidth = 6
        leftGate.alpha = 0.18
        leftGate.position = CGPoint(x: size.width * 0.28, y: y)
        leftGate.zPosition = 12
        addChild(leftGate)
        leftStrikeGate = leftGate

        let rightGate = SKShapeNode(rectOf: gateSize, cornerRadius: 11)
        rightGate.fillColor = UIColor(red: 0.93, green: 0.56, blue: 0.46, alpha: 0.08)
        rightGate.strokeColor = UIColor(red: 0.93, green: 0.56, blue: 0.46, alpha: 0.26)
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
    }

    private func setupCourtAvatar() {
        let spec = avatarSpec
        let bodyScale = spec?.bodyScale ?? 1.0
        let skin = spec?.skin ?? UIColor(red: 0.76, green: 0.56, blue: 0.42, alpha: 1)
        let top = spec?.top ?? UIColor(white: 0.92, alpha: 1)
        let bottom = spec?.bottom ?? UIColor(white: 0.14, alpha: 1)
        let racket = spec?.racket ?? UIColor(white: 0.78, alpha: 1)
        let racketAccent = spec?.racketAccent ?? UIColor(red: 0, green: 0.9, blue: 1, alpha: 1)
        playerRacketBaseColor = racket
        playerRacketAccentColor = racketAccent

        let root = SKNode()
        root.zPosition = 14
        root.position = CGPoint(x: size.width / 2, y: size.height * 0.08)
        addChild(root)
        playerRoot = root

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 112 * bodyScale, height: 26 * bodyScale))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.26)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -6)
        shadow.zPosition = -1
        root.addChild(shadow)
        playerShadow = shadow

        let stanceGlow = SKShapeNode(ellipseOf: CGSize(width: 132 * bodyScale, height: 34 * bodyScale))
        stanceGlow.fillColor = racketAccent.withAlphaComponent(0.08)
        stanceGlow.strokeColor = .clear
        stanceGlow.position = CGPoint(x: 0, y: -4)
        stanceGlow.zPosition = -2
        root.addChild(stanceGlow)
        playerStanceGlow = stanceGlow

        let leadLeg = SKShapeNode(rectOf: CGSize(width: 18 * bodyScale, height: 88 * bodyScale), cornerRadius: 8 * bodyScale)
        leadLeg.fillColor = bottom
        leadLeg.strokeColor = .clear
        leadLeg.position = CGPoint(x: 22 * bodyScale, y: 40 * bodyScale)
        root.addChild(leadLeg)
        playerLeadLeg = leadLeg

        let trailLeg = SKShapeNode(rectOf: CGSize(width: 18 * bodyScale, height: 82 * bodyScale), cornerRadius: 8 * bodyScale)
        trailLeg.fillColor = bottom.withAlphaComponent(0.96)
        trailLeg.strokeColor = .clear
        trailLeg.position = CGPoint(x: -18 * bodyScale, y: 38 * bodyScale)
        root.addChild(trailLeg)
        playerTrailLeg = trailLeg

        let torso = SKShapeNode(path: premiumTorsoPath(scale: bodyScale))
        torso.fillColor = top
        torso.strokeColor = .white.withAlphaComponent(0.14)
        torso.lineWidth = 1
        torso.position = CGPoint(x: 0, y: 116 * bodyScale)
        root.addChild(torso)
        playerTorso = torso

        let neck = SKShapeNode(rectOf: CGSize(width: 18 * bodyScale, height: 18 * bodyScale), cornerRadius: 7 * bodyScale)
        neck.fillColor = skin.withAlphaComponent(0.96)
        neck.strokeColor = .clear
        neck.position = CGPoint(x: 0, y: 160 * bodyScale)
        root.addChild(neck)
        playerNeck = neck

        let head = SKShapeNode(circleOfRadius: 28 * bodyScale)
        head.fillColor = skin
        head.strokeColor = .white.withAlphaComponent(0.12)
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: 196 * bodyScale)
        root.addChild(head)
        playerHead = head

        let hair = SKShapeNode(ellipseOf: CGSize(width: 60 * bodyScale, height: 34 * bodyScale))
        hair.fillColor = UIColor(white: 0.12, alpha: 0.96)
        hair.strokeColor = UIColor.white.withAlphaComponent(0.06)
        hair.lineWidth = 1
        hair.position = CGPoint(x: 0, y: 208 * bodyScale)
        hair.zPosition = 1
        root.addChild(hair)
        playerHair = hair

        let leadArm = SKShapeNode(rectOf: CGSize(width: 16 * bodyScale, height: 92 * bodyScale), cornerRadius: 8 * bodyScale)
        leadArm.fillColor = skin
        leadArm.strokeColor = .clear
        leadArm.position = CGPoint(x: 40 * bodyScale, y: 124 * bodyScale)
        leadArm.zRotation = -0.36
        root.addChild(leadArm)
        playerLeadArm = leadArm

        let trailArm = SKShapeNode(rectOf: CGSize(width: 16 * bodyScale, height: 84 * bodyScale), cornerRadius: 8 * bodyScale)
        trailArm.fillColor = skin
        trailArm.strokeColor = .clear
        trailArm.position = CGPoint(x: -42 * bodyScale, y: 128 * bodyScale)
        trailArm.zRotation = 0.26
        root.addChild(trailArm)
        playerTrailArm = trailArm

        let handle = SKShapeNode(rectOf: CGSize(width: 12 * bodyScale, height: 76 * bodyScale), cornerRadius: 6 * bodyScale)
        handle.fillColor = racketAccent
        handle.strokeColor = .white.withAlphaComponent(0.12)
        handle.lineWidth = 1
        handle.position = CGPoint(x: 68 * bodyScale, y: 126 * bodyScale)
        handle.zRotation = -0.42
        root.addChild(handle)
        playerRacketHandle = handle

        let hoop = SKShapeNode(ellipseOf: CGSize(width: 72 * bodyScale, height: 100 * bodyScale))
        hoop.fillColor = racketAccent.withAlphaComponent(0.08)
        hoop.strokeColor = racket
        hoop.lineWidth = 10 * bodyScale
        hoop.glowWidth = 6
        hoop.position = CGPoint(x: 102 * bodyScale, y: 178 * bodyScale)
        hoop.zRotation = -0.28
        root.addChild(hoop)
        playerRacketHead = hoop

        playerRacketStrings.removeAll()
        for offset in [-16, -6, 6, 16] {
            let string = SKShapeNode(rectOf: CGSize(width: 2.4 * bodyScale, height: 68 * bodyScale), cornerRadius: 1.2 * bodyScale)
            string.fillColor = racket.withAlphaComponent(0.42)
            string.strokeColor = .clear
            string.position = CGPoint(x: CGFloat(offset) * bodyScale, y: 0)
            hoop.addChild(string)
            playerRacketStrings.append(string)
        }
        for offset in [-18, 0, 18] {
            let string = SKShapeNode(rectOf: CGSize(width: 48 * bodyScale, height: 2.4 * bodyScale), cornerRadius: 1.2 * bodyScale)
            string.fillColor = racket.withAlphaComponent(0.34)
            string.strokeColor = .clear
            string.position = CGPoint(x: 0, y: CGFloat(offset) * bodyScale)
            hoop.addChild(string)
            playerRacketStrings.append(string)
        }
    }

    private func setupHUD() {
        let topPlateSize = usesMinimalWallHUD
            ? CGSize(width: 206, height: 82)
            : CGSize(width: 288, height: 104)
        let topPlate = SKShapeNode(
            rectOf: topPlateSize,
            cornerRadius: usesMinimalWallHUD ? 26 : 30
        )
        topPlate.fillColor = UIColor(red: 0.03, green: 0.05, blue: 0.09, alpha: 0.42)
        topPlate.strokeColor = UIColor(white: 1.0, alpha: 0.16)
        topPlate.lineWidth = 1.2
        topPlate.glowWidth = 6
        topPlate.position = CGPoint(x: size.width / 2, y: size.height * 0.885)
        topPlate.zPosition = 46
        addChild(topPlate)
        hudTopPlate = topPlate

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
        maxLabel.text = "BEST"
        maxLabel.fontSize = 9
        maxLabel.fontColor = UIColor(white: 1.0, alpha: 0.28)
        maxLabel.position = CGPoint(x: size.width * 0.73, y: size.height * 0.915)
        maxLabel.zPosition = 50
        maxLabel.horizontalAlignmentMode = .right
        addChild(maxLabel)
        hudMaxLabel = maxLabel

        let maxValue = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        maxValue.text = "x0"
        maxValue.fontSize = 14
        maxValue.fontColor = UIColor(white: 1.0, alpha: 0.78)
        maxValue.position = CGPoint(x: size.width * 0.73, y: size.height * 0.889)
        maxValue.zPosition = 50
        maxValue.horizontalAlignmentMode = .right
        addChild(maxValue)
        hudMaxValueLabel = maxValue

        let score = SKLabelNode(fontNamed: "AvenirNext-Bold")
        score.text = "0"
        score.fontSize = usesMinimalWallHUD ? 52 : 46
        score.fontColor = .white
        score.position = CGPoint(x: size.width / 2, y: size.height * 0.875)
        score.zPosition = 50
        score.horizontalAlignmentMode = .center
        addChild(score)
        scoreLabel = score

        if usesMinimalWallHUD {
            caption.alpha = 0
            phaseLabel.alpha = 0
            phaseValue.alpha = 0
        }

        let combo = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        combo.text = ""
        combo.fontSize = 17
        combo.fontColor = UIColor(white: 1, alpha: 0.68)
        combo.position = CGPoint(x: size.width / 2, y: usesMinimalWallHUD ? size.height * 0.81 : size.height * 0.838)
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

        let instruction = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        instruction.text = usesMinimalWallHUD ? "Read the side. Time the swing." : "Swipe toward the lane as the ball meets the line"
        instruction.fontSize = 15
        instruction.fontColor = UIColor(white: 1, alpha: 0.82)
        instruction.position = CGPoint(x: size.width / 2, y: size.height * 0.14)
        instruction.zPosition = 55
        instruction.horizontalAlignmentMode = .center
        instruction.verticalAlignmentMode = .center
        instruction.alpha = 0
        addChild(instruction)
        instructionLabel = instruction
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
        }
        moveBalls(trackTime: currentTrackTime)
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
        guard ball.spawnTime != lastAutoPlaySpawnTime else { return }
        let triggerTime = ball.arrivalTime - 0.02
        guard currentTrackTime >= triggerTime else { return }
        lastAutoPlaySpawnTime = ball.spawnTime
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

    private func updateCourtAvatar(trackTime: Double) {
        guard let playerRoot else { return }

        let activeTouch = swingCurrentScene ?? swingOriginScene
        let idleBreath = sin(trackTime * 2.6) * 4
        let recoveryProgressValue = recoveryProgress(at: trackTime)
        let impactProgress = max(0, min(1, (swingVisualImpactUntil - currentTimeSnapshot) / 0.26))
        let focusLane = sessionMode == .wallRally ? wallFocusLane() : swingVisualLane
        let desiredX: CGFloat
        if sessionMode == .wallRally {
            desiredX = wallStanceTargetX(for: focusLane)
        } else if let activeTouch {
            let clamped = min(size.width * 0.78, max(size.width * 0.22, activeTouch.x))
            desiredX = clamped
        } else {
            desiredX = size.width / 2 + recoveryOffsetX(at: trackTime) + sin(trackTime * 0.8) * 10
        }
        let anticipation = max(0, min(1, (betweenPointLiftUntil - currentTimeSnapshot) / 0.6))
        let movementBlend: CGFloat = sessionMode == .wallRally ? 0.42 : 0.22
        playerRoot.position.x += (desiredX - playerRoot.position.x) * movementBlend
        playerRoot.position.y = size.height * 0.08 + idleBreath - anticipation * 5.5

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
        let targets = poseTargets(
            for: pose,
            leanDirection: leanDirection,
            reach: reach,
            recoveryProgress: recoveryProgressValue
        )

        playerTorso.zRotation += (targets.torsoRotation - playerTorso.zRotation) * 0.2
        playerTorso.xScale += ((1 + abs(idleShoulder) * 0.03) - playerTorso.xScale) * 0.08
        playerHead.zRotation += (targets.headRotation - playerHead.zRotation) * 0.18
        playerHead.position.x += (targets.headX - playerHead.position.x) * 0.14
        playerHead.position.y += ((196 + idleHeadLift) - playerHead.position.y) * 0.12
        playerNeck.zRotation += (targets.headRotation * 0.6 - playerNeck.zRotation) * 0.16
        playerHair.zRotation += (targets.headRotation * 0.72 - playerHair.zRotation) * 0.14
        playerHair.position.x += ((targets.headX * 0.65) - playerHair.position.x) * 0.12
        playerHair.position.y += ((208 + idleHeadLift * 0.8) - playerHair.position.y) * 0.1

        playerLeadLeg.zRotation += ((targets.leadLegRotation + anticipation * 0.08) - playerLeadLeg.zRotation) * 0.18
        playerTrailLeg.zRotation += ((targets.trailLegRotation - anticipation * 0.08) - playerTrailLeg.zRotation) * 0.18
        playerLeadLeg.position.x += (targets.leadLegX - playerLeadLeg.position.x) * 0.16
        playerTrailLeg.position.x += (targets.trailLegX - playerTrailLeg.position.x) * 0.16

        playerLeadArm.zRotation += ((targets.leadArmRotation + idleShoulder - anticipation * 0.04) - playerLeadArm.zRotation) * 0.26
        playerTrailArm.zRotation += ((targets.trailArmRotation - idleShoulder * 0.8 + anticipation * 0.04) - playerTrailArm.zRotation) * 0.22
        playerLeadArm.position.x += (targets.leadArmX - playerLeadArm.position.x) * 0.24
        playerLeadArm.position.y += (targets.leadArmY - playerLeadArm.position.y) * 0.24

        let qualityPose = qualityImpactProfile()
        playerRacketHandle.zRotation += ((targets.racketHandleRotation + qualityPose.handleRotation * qualityFlash) - playerRacketHandle.zRotation) * 0.28
        playerRacketHead.zRotation += ((targets.racketHeadRotation + qualityPose.headRotation * qualityFlash) - playerRacketHead.zRotation) * 0.28
        playerRacketHandle.position.x += ((targets.racketHandleX + qualityPose.handleX * qualityFlash) - playerRacketHandle.position.x) * 0.26
        playerRacketHandle.position.y += ((targets.racketHandleY + qualityPose.handleY * qualityFlash) - playerRacketHandle.position.y) * 0.26
        playerRacketHead.position.x += ((targets.racketHeadX + qualityPose.headX * qualityFlash) - playerRacketHead.position.x) * 0.28
        playerRacketHead.position.y += ((targets.racketHeadY + qualityPose.headY * qualityFlash) - playerRacketHead.position.y) * 0.28

        let swingPalette = swingTrailPalette(intent: swingVisualIntent, lane: swingVisualLane)
        let flashColor = contactFlash > 0.01
            ? UIColor.white.withAlphaComponent(0.35 + contactFlash * 0.55)
            : swingPalette.glow.withAlphaComponent(0.22)
        let liveIntentEnergy = min(1, impactProgress * 0.72 + qualityFlash * 0.58 + anticipation * 0.3)
        playerRacketHead.glowWidth = 10 + contactFlash * 20 + qualityPose.glowBoost * qualityFlash + liveIntentEnergy * 7
        playerRacketHead.fillColor = swingPalette.glow.withAlphaComponent(
            0.07 + liveIntentEnergy * 0.08 + contactFlash * 0.14 + qualityPose.fillBoost * qualityFlash
        )
        playerRacketHead.strokeColor = playerRacketBaseColor
            .blended(withFraction: CGFloat(contactFlash * 0.6), of: .white)?
            .blended(withFraction: CGFloat(liveIntentEnergy * 0.4), of: swingPalette.core)
            ?? playerRacketBaseColor
        playerRacketHandle.strokeColor = flashColor
        playerRacketHandle.fillColor = swingPalette.core.withAlphaComponent(0.74 + contactFlash * 0.16)
        playerRacketStrings.forEach { string in
            string.alpha = 0.38 + contactFlash * 0.44 + qualityPose.stringBoost * qualityFlash
            string.fillColor = UIColor.white
                .blended(withFraction: CGFloat(liveIntentEnergy * 0.34), of: swingPalette.tip)?
                .withAlphaComponent(0.22 + contactFlash * 0.46 + qualityPose.stringBoost * qualityFlash * 0.8)
                ?? UIColor.white.withAlphaComponent(0.22 + contactFlash * 0.46 + qualityPose.stringBoost * qualityFlash * 0.8)
        }
        playerHair.fillColor = UIColor(white: 0.12, alpha: 0.94).blended(withFraction: CGFloat(contactFlash * 0.18), of: .white) ?? UIColor(white: 0.12, alpha: 0.94)
        playerShadow.xScale += (targets.shadowXScale - playerShadow.xScale) * 0.18
        playerShadow.yScale += (targets.shadowYScale - playerShadow.yScale) * 0.18
        playerShadow.alpha += ((targets.shadowAlpha + contactFlash * 0.12) - playerShadow.alpha) * 0.18
        playerStanceGlow.fillColor = swingPalette.glow.withAlphaComponent(
            0.05 + anticipation * 0.04 + impactProgress * 0.08 + qualityFlash * 0.06
        )
        playerStanceGlow.xScale += ((1.0 + impactProgress * 0.18 + recoveryProgressValue * 0.06) - playerStanceGlow.xScale) * 0.18
        playerStanceGlow.yScale += ((1.0 + anticipation * 0.08 + qualityFlash * 0.06) - playerStanceGlow.yScale) * 0.18
        playerStanceGlow.alpha += ((0.42 + impactProgress * 0.22 + qualityFlash * 0.18) - playerStanceGlow.alpha) * 0.16
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

    private func premiumTorsoPath(scale: CGFloat) -> CGPath {
        let width = 84 * scale
        let shoulder = width * 0.54
        let waist = width * 0.36
        let height = 112 * scale
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -shoulder, y: height * 0.34))
        path.addQuadCurve(to: CGPoint(x: -waist, y: -height * 0.5), control: CGPoint(x: -width * 0.56, y: -height * 0.04))
        path.addLine(to: CGPoint(x: waist, y: -height * 0.5))
        path.addQuadCurve(to: CGPoint(x: shoulder, y: height * 0.34), control: CGPoint(x: width * 0.56, y: -height * 0.04))
        path.addQuadCurve(to: CGPoint(x: 0, y: height * 0.5), control: CGPoint(x: width * 0.44, y: height * 0.56))
        path.addQuadCurve(to: CGPoint(x: -shoulder, y: height * 0.34), control: CGPoint(x: -width * 0.44, y: height * 0.56))
        path.closeSubpath()
        return path
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
        recoveryProgress: CGFloat
    ) -> PlayerPoseTargets {
        switch state {
        case .ready:
            let split = sin(currentTrackTime * 4.2) * 0.025
            return PlayerPoseTargets(
                torsoRotation: split,
                headRotation: split * 0.5,
                headX: leanDirection * 4,
                leadLegRotation: 0.08 + split,
                trailLegRotation: -0.06 - split * 0.8,
                leadLegX: 24 + leanDirection * 5,
                trailLegX: -20 - leanDirection * 3,
                leadArmRotation: -0.28 + leanDirection * 0.14,
                trailArmRotation: 0.22 + leanDirection * 0.04,
                leadArmX: 38 + leanDirection * 6,
                leadArmY: 122,
                racketHandleRotation: -0.32 + leanDirection * 0.14,
                racketHeadRotation: -0.18 + leanDirection * 0.12,
                racketHandleX: 62 + leanDirection * 8,
                racketHandleY: 126,
                racketHeadX: 96 + leanDirection * 10,
                racketHeadY: 176,
                shadowXScale: 1.02,
                shadowYScale: 1.0,
                shadowAlpha: 0.24
            )
        case .forehandClean:
            let armReach = 32 + reach * 0.12
            return PlayerPoseTargets(
                torsoRotation: 0.18,
                headRotation: 0.08,
                headX: 10,
                leadLegRotation: 0.14,
                trailLegRotation: -0.1,
                leadLegX: 30,
                trailLegX: -18,
                leadArmRotation: 0.12 + reach * 0.0015,
                trailArmRotation: 0.12,
                leadArmX: 44 + armReach * 0.24,
                leadArmY: 128 + reach * 0.04,
                racketHandleRotation: 0.08 + reach * 0.0018,
                racketHeadRotation: 0.3 + reach * 0.0012,
                racketHandleX: 74 + armReach,
                racketHandleY: 134 + reach * 0.06,
                racketHeadX: 116 + armReach * 1.08,
                racketHeadY: 186 + reach * 0.1,
                shadowXScale: 1.08,
                shadowYScale: 1.02,
                shadowAlpha: 0.28
            )
        case .backhandClean:
            let armReach = 24 + reach * 0.1
            return PlayerPoseTargets(
                torsoRotation: -0.2,
                headRotation: -0.08,
                headX: -12,
                leadLegRotation: -0.04,
                trailLegRotation: 0.14,
                leadLegX: 18,
                trailLegX: -26,
                leadArmRotation: -0.68 - reach * 0.0013,
                trailArmRotation: 0.38,
                leadArmX: 26 - armReach * 0.16,
                leadArmY: 136 + reach * 0.05,
                racketHandleRotation: -0.86 - reach * 0.0018,
                racketHeadRotation: -0.62 - reach * 0.0015,
                racketHandleX: 34 - armReach * 0.56,
                racketHandleY: 142 + reach * 0.08,
                racketHeadX: 48 - armReach * 0.86,
                racketHeadY: 194 + reach * 0.12,
                shadowXScale: 1.07,
                shadowYScale: 1.03,
                shadowAlpha: 0.28
            )
        case .stretchForehand:
            let armReach = 48 + reach * 0.15
            return PlayerPoseTargets(
                torsoRotation: 0.26,
                headRotation: 0.12,
                headX: 16,
                leadLegRotation: 0.22,
                trailLegRotation: -0.16,
                leadLegX: 38,
                trailLegX: -14,
                leadArmRotation: 0.28 + reach * 0.0019,
                trailArmRotation: 0.06,
                leadArmX: 46 + armReach * 0.32,
                leadArmY: 130 + reach * 0.08,
                racketHandleRotation: 0.18 + reach * 0.0021,
                racketHeadRotation: 0.42 + reach * 0.0017,
                racketHandleX: 82 + armReach * 1.02,
                racketHandleY: 136 + reach * 0.1,
                racketHeadX: 128 + armReach * 1.26,
                racketHeadY: 194 + reach * 0.15,
                shadowXScale: 1.16,
                shadowYScale: 0.96,
                shadowAlpha: 0.32
            )
        case .stretchBackhand:
            let armReach = 42 + reach * 0.13
            return PlayerPoseTargets(
                torsoRotation: -0.28,
                headRotation: -0.12,
                headX: -18,
                leadLegRotation: -0.08,
                trailLegRotation: 0.22,
                leadLegX: 14,
                trailLegX: -34,
                leadArmRotation: -0.84 - reach * 0.0016,
                trailArmRotation: 0.42,
                leadArmX: 18 - armReach * 0.34,
                leadArmY: 134 + reach * 0.08,
                racketHandleRotation: -1.0 - reach * 0.002,
                racketHeadRotation: -0.78 - reach * 0.0018,
                racketHandleX: 18 - armReach * 0.9,
                racketHandleY: 144 + reach * 0.1,
                racketHeadX: 16 - armReach * 1.18,
                racketHeadY: 196 + reach * 0.16,
                shadowXScale: 1.15,
                shadowYScale: 0.96,
                shadowAlpha: 0.32
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
                racketHandleRotation: -0.18 + leanDirection * 0.1,
                racketHeadRotation: -0.04 + leanDirection * 0.08,
                racketHandleX: 58 + armReach * 0.34,
                racketHandleY: 122,
                racketHeadX: 82 + armReach * 0.44,
                racketHeadY: 156,
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
                leadLegRotation: direction * 0.06 * severity,
                trailLegRotation: -direction * 0.18 * severity,
                leadLegX: 22 + direction * 10 * severity,
                trailLegX: -18 - direction * 16 * severity,
                leadArmRotation: -0.24 + direction * 0.22 * severity,
                trailArmRotation: 0.24 + direction * 0.14 * severity,
                leadArmX: 38 + direction * 18 * severity,
                leadArmY: 120 - 8 * severity,
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
        for ball in activeBalls {
            let progress = max(0, min(1, (trackTime - ball.spawnTime) / ball.travelSeconds))
            ball.updatePresentation(progress: CGFloat(progress))
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
        for ball in activeBalls {
            let emphasis: CGFloat
            if ball === focusBall {
                emphasis = 1.0
            } else if ball === partner {
                emphasis = 0.7
            } else if ball.lane == focusLane {
                emphasis = sessionMode == .wallRally ? 0.24 + wallOpeningForgivenessBoost() * 0.08 : 0.16
            } else {
                emphasis = 0
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
        let wallBoost: CGFloat = sessionMode == .wallRally ? 1.22 : 1.0
        gate.alpha = min(1, 0.14 + intensity * 0.42 * wallBoost + approach * 0.26 * wallBoost)
        gate.fillColor = palette.glow.withAlphaComponent(0.05 + intensity * 0.1 * wallBoost + approach * 0.14 * wallBoost)
        gate.strokeColor = palette.core.withAlphaComponent(0.18 + intensity * 0.32 * wallBoost + approach * 0.28 * wallBoost)
        gate.glowWidth = 4 + intensity * 8 * wallBoost + approach * 10 * wallBoost
        gate.lineWidth = 1.2 + intensity * 0.8 * wallBoost + approach * 1.0 * wallBoost
        gate.xScale = 1.0 + intensity * 0.08 * wallBoost + approach * 0.18 * wallBoost
        gate.yScale = 1.0 + intensity * 0.12 * wallBoost + approach * 0.28 * wallBoost
        gate.zRotation = (lane == .right ? 1 : -1) * approach * 0.04
        if live > 0.85 {
            gate.fillColor = palette.tip.withAlphaComponent(0.12 + approach * 0.12)
        }
    }

    private func applyContactPocketStyle(_ pocket: SKShapeNode?, lane: Lane, intensity: CGFloat, approach: CGFloat) {
        guard let pocket else { return }
        let palette = swingTrailPalette(intent: swingVisualIntent, lane: lane)
        let contactBias = recentContactLane == lane ? recentContactPocketBias() : 0
        let wallBoost: CGFloat = sessionMode == .wallRally ? 1.26 : 1.0
        pocket.position = racketContactPoint(for: lane)
        pocket.alpha = min(1, 0.12 + intensity * 0.22 * wallBoost + approach * 0.48 * wallBoost + contactBias * 0.18)
        pocket.strokeColor = palette.core.withAlphaComponent(0.14 + intensity * 0.18 * wallBoost + approach * 0.48 * wallBoost + contactBias * 0.22)
        pocket.fillColor = palette.glow.withAlphaComponent(0.02 + approach * 0.12 * wallBoost + contactBias * 0.1)
        pocket.glowWidth = 4 + intensity * 4 * wallBoost + approach * 10 * wallBoost + contactBias * 8
        pocket.lineWidth = 1.2 + intensity * 0.6 * wallBoost + approach * 1.6 * wallBoost + contactBias * 0.8
        pocket.xScale = 1.0 + approach * 0.28 * wallBoost + contactBias * 0.18
        pocket.yScale = 1.0 + approach * 0.28 * wallBoost + contactBias * 0.18
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
        spawnedBallCount += 1
        let travelSeconds = currentTravelSeconds
        let spawnTime = note.arrivalTime - travelSeconds
        let spawnY = size.height * Tunables.spawnLineYRatio
        let strikeY = size.height * Tunables.strikeLineYRatio
        let horizonCenterX = size.width / 2
        let horizonSpread = size.width * Tunables.horizonLaneInsetRatio * racketTuning.horizonSpreadScalar
        let strikeInset = size.width * Tunables.strikeLaneInsetRatio * racketTuning.strikeWidthScalar
        let spawnX = horizonCenterX + (note.lane == .left ? -horizonSpread : horizonSpread)
        let strikeX = note.lane == .left ? strikeInset : size.width - strikeInset
        let shotShape = selectShotShape(for: note)
        let ballRole: BeatmapNote.Role = sessionMode == .wallRally ? .returnBall : note.role
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
            strikeScale: Tunables.ballStrikeScale * racketTuning.strikeScaleScalar,
            overrunScale: Tunables.ballOverrunScale * racketTuning.overrunScaleScalar,
            curveAmount: wallCurveAmount() * racketTuning.curveScalar,
            overrideFillColor: sessionMode == .wallRally
                ? UIColor(red: 0.93, green: 0.97, blue: 0.36, alpha: 1)
                : nil
        )
        addChild(ball)
        activeBalls.append(ball)
        if sessionMode == .wallRally {
            stageWallFeedCue(for: ball)
        }
        stagePointCueIfNeeded(for: note)
    }

    private func scheduleWallBall(after delay: Double) {
        guard sessionMode == .wallRally, !sessionEnded else { return }
        guard activeBalls.isEmpty else { return }
        let lane = nextWallSpawnLane()
        let arrivalTime = currentTrackTime + delay
        let note = BeatmapNote(
            arrivalTime: arrivalTime,
            lane: lane,
            kind: .normal,
            role: .rally
        )
        spawnBall(note)
    }

    private func stagePointCueIfNeeded(for note: BeatmapNote) {
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
            showInstruction("Two-ball pressure. Stay centered and answer both lanes clean.", hold: 0.7)
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
                showInstruction("Set your feet and read the first strike.", hold: 0.7)
            }
        case .changeup:
            if note.kind != .double {
                CameraShake.nudge(cameraNode, dx: 0, dy: -3, outMs: 45, backMs: 150)
                showInstruction("Variation incoming. Stay composed at contact.", hold: 0.68)
            }
        case .returnBall:
            if activeBalls.count <= 2 {
                showInstruction("Pick it up early and take the return clean.", hold: 0.64)
            }
        case .rally:
            break
        }
    }

    private func showOpeningTutorialCue(for note: BeatmapNote) -> Bool {
        guard spawnedBallCount <= 6 else { return false }

        switch spawnedBallCount {
        case 1:
            showInstruction("First ball. Let your feet set, then time it clean.", hold: 1.02)
            return true
        case 2:
            showInstruction("Same ball back again. Read the side and swing there.", hold: 0.98)
            return true
        case 3:
            showInstruction("Good. The stance is set for you, so just focus on timing.", hold: 0.94)
            return true
        case 4:
            showInstruction("Now settle into rhythm. Same wall, same answer.", hold: 0.9)
            return true
        case 5:
            showInstruction("Stay smooth. One streak, one ball, one wall.", hold: 0.88)
            return true
        case 6:
            showInstruction("Tempo rises slowly. Timing first, speed second.", hold: 0.86)
            return true
        default:
            return false
        }
    }

    private func stageWallFeedCue(for ball: BallNode) {
        guard sessionMode == .wallRally else { return }
        let openingStrength = max(0, 1 - wallOpeningProgress())
        guard openingStrength > 0 else { return }

        let feedColor = UIColor(red: 0.93, green: 0.97, blue: 0.36, alpha: 1)
        let pocketPoint = racketContactPoint(for: ball.lane)
        let spawnHalo = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * (1.8 + openingStrength * 0.55))
        spawnHalo.position = ball.position
        spawnHalo.zPosition = 22
        spawnHalo.strokeColor = feedColor.withAlphaComponent(0.72)
        spawnHalo.fillColor = feedColor.withAlphaComponent(0.12 + openingStrength * 0.06)
        spawnHalo.lineWidth = 1.4 + openingStrength * 0.6
        spawnHalo.glowWidth = 8 + openingStrength * 6
        addChild(spawnHalo)

        let pocket = SKShapeNode(circleOfRadius: 18 + openingStrength * 4)
        pocket.position = pocketPoint
        pocket.zPosition = 21
        pocket.strokeColor = feedColor.withAlphaComponent(0.44 + openingStrength * 0.12)
        pocket.fillColor = UIColor.white.withAlphaComponent(0.03 + openingStrength * 0.03)
        pocket.lineWidth = 1.2
        pocket.glowWidth = 5 + openingStrength * 4
        addChild(pocket)

        let guidePath = CGMutablePath()
        guidePath.move(to: ball.position)
        guidePath.addQuadCurve(
            to: pocketPoint,
            control: CGPoint(
                x: (ball.position.x + pocketPoint.x) * 0.5,
                y: ball.position.y - size.height * (0.06 + openingStrength * 0.015)
            )
        )
        let guide = SKShapeNode(path: guidePath)
        guide.zPosition = 20
        guide.strokeColor = feedColor.withAlphaComponent(0.18 + openingStrength * 0.08)
        guide.lineWidth = 1.2 + openingStrength * 0.4
        guide.glowWidth = 4 + openingStrength * 3
        guide.lineCap = .round
        addChild(guide)

        let handoff = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * (0.92 + openingStrength * 0.1))
        handoff.position = ball.position
        handoff.zPosition = 23
        handoff.fillColor = feedColor.withAlphaComponent(0.32 + openingStrength * 0.12)
        handoff.strokeColor = UIColor.white.withAlphaComponent(0.34)
        handoff.lineWidth = 0.8
        handoff.glowWidth = 10
        addChild(handoff)

        spawnHalo.run(.sequence([
            .group([
                .scale(to: 0.62, duration: 0.15),
                .fadeOut(withDuration: 0.16 + openingStrength * 0.03)
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
                .fadeOut(withDuration: 0.15 + openingStrength * 0.04)
            ]),
            .removeFromParent()
        ]))
        guide.run(.sequence([
            .group([
                .fadeAlpha(to: 0.06, duration: 0.11),
                .scaleX(to: 0.985, duration: 0.11)
            ]),
            .group([
                .fadeOut(withDuration: 0.1 + openingStrength * 0.04),
                .scaleX(to: 1.0, duration: 0.1)
            ]),
            .removeFromParent()
        ]))
        let handoffMove = SKAction.customAction(withDuration: 0.14 + openingStrength * 0.03) { [weak handoff] _, elapsed in
            guard let handoff else { return }
            let duration = 0.14 + openingStrength * 0.03
            let t = max(0, min(1, elapsed / duration))
            let inverse = 1 - t
            let control = CGPoint(
                x: (ball.position.x + pocketPoint.x) * 0.5,
                y: ball.position.y - self.size.height * (0.055 + openingStrength * 0.012)
            )
            let x = inverse * inverse * ball.position.x + 2 * inverse * t * control.x + t * t * pocketPoint.x
            let y = inverse * inverse * ball.position.y + 2 * inverse * t * control.y + t * t * pocketPoint.y
            handoff.position = CGPoint(x: x, y: y)
            handoff.alpha = 0.95 * inverse
            handoff.setScale(1 - CGFloat(t) * 0.22)
        }
        handoff.run(.sequence([handoffMove, .removeFromParent()]))
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
            swingCurrentScene = scenePoint
            swingVisualReach = 0
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
            let speed = hypot(v.x, v.y)

            // Ignore taps and accidental contact — only deliberate motion
            // commits a swing.
            let minimumDistance = sessionMode == .wallRally
                ? Tunables.swingMinDistance * 0.34
                : Tunables.swingMinDistance
            let minimumSpeed = sessionMode == .wallRally
                ? Tunables.swingFastVelocity * 0.30
                : 0
            guard distance >= minimumDistance || speed >= minimumSpeed else { return }

            // Lane is decided by the dominant horizontal sign. Verticality
            // is currently informational only (reserved for future "lob" or
            // "drop shot" variants).
            let lane: Lane = sessionMode == .wallRally
                ? (scenePoint.x < size.width / 2 ? .left : .right)
                : (dx < 0 ? .left : .right)
            swingVisualLane = lane
            swingVisualImpactUntil = currentTimeSnapshot + 0.26
            swingVisualReach = distance
            let swingIntent = classifySwingIntent(dx: dx, dy: dy)
            swingVisualIntent = swingIntent
            let strokeSide = strokeSide(for: lane)
            resolveSwing(
                lane: lane,
                swingSpeed: speed,
                swingIntent: swingIntent,
                strokeSide: strokeSide
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

        guard let target = preferredSwingTarget(in: lane) else {
            // No ball to hit — count as a miss so the player feels the cost
            // of mashing.
            registerMiss(lane: lane)
            return
        }
        let signedDelta = currentTrackTime - target.arrivalTime
        let delta = abs(signedDelta)
        let contactDistance = spatialContactDistance(to: target, lane: lane)
        if contactDistance > wallAssistMissRadius(for: lane) {
            registerMiss(lane: lane)
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
            registerMiss(lane: lane)
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
            ])
            return
        }
        registerHit(
            ball: target,
            quality: quality,
            strokeSide: strokeSide,
            swingIntent: swingIntent,
            contactDistance: contactDistance
        )
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
            .filter { $0.lane == lane }
            .filter { abs($0.arrivalTime - trackTime) <= targetSlack }
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
        contactDistance: CGFloat
    ) {
        activeBalls.removeAll { $0 === ball }
        // Perfect hits get the ball-shatter treatment; other grades just
        // disappear cleanly so the impact-emphasis stays earned.
        if quality == .perfect {
            shatterBall(ball)
        } else {
            ball.removeFromParent()
        }

        flashLaneGlow(lane: ball.lane, quality: quality)
        swingVisualLane = ball.lane
        recentContactLane = ball.lane
        swingVisualImpactUntil = currentTimeSnapshot + wallContactImpactDuration(for: quality)
        swingVisualReach = max(swingVisualReach, 52)
        contactFlashUntil = currentTimeSnapshot + wallContactFlashDuration(for: quality)
        recentContactQuality = quality
        recentContactUntil = currentTimeSnapshot + wallContactAfterglowDuration(for: quality)
        stageContactImprint(
            at: racketContactPoint(for: ball.lane),
            lane: ball.lane,
            intent: swingIntent,
            quality: quality
        )
        stageWallStrikeBurst(
            at: racketContactPoint(for: ball.lane),
            lane: ball.lane,
            quality: quality
        )
        stageContactCameraResponse(for: ball, quality: quality)
        applyRecoveryState(after: ball, quality: quality, contactDistance: contactDistance)

        combo += 1
        maxCombo = max(maxCombo, combo)
        let comboMultiplier = max(1, combo / 5)
        let strokeScoreBoost = scoreBoost(for: strokeSide, swingIntent: swingIntent, shotShape: ball.shotShape)
        score += Int((Double(quality.baseScore * comboMultiplier) * strokeScoreBoost).rounded())
        switch quality {
        case .perfect: perfectHits += 1
        case .great:   greatHits   += 1
        case .good:    goodHits    += 1
        case .miss:    break
        }
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
            stageWallReturn(from: racketContactPoint(for: ball.lane), lane: ball.lane, quality: quality)
            wallHitCelebration(quality: quality, lane: ball.lane)
            scheduleWallBall(
                after: wallCadenceSeconds(for: quality)
                    * wallReturnSnapScalar(for: quality)
                    * wallEarlyRallySnapBonus(for: quality)
            )
        }
        recordInCurrentSegment(quality: quality)
        recentHUDImpactUntil = currentTimeSnapshot + wallHUDImpactDuration(for: quality)
        updateHUD()

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
        pressureExchangeStreak = 0
        activeBalls.forEach { $0.removeFromParent() }
        activeBalls.removeAll()
        applyMissRecovery(for: lane)
        recordInCurrentSegment(quality: .miss)
        if sessionMode == .wallRally {
            let previous = combo
            combo = 0
            lastComboTier = 0
            updateHUD()
            stageResetBeat(duration: previous > 0 ? 0.4 : 0.34)
            GameEventBus.shared.publish(.miss(lane: lane))
            if previous > 0 {
                showInstruction("Reset. Same ball again. Rebuild fast.", hold: 0.7)
            } else {
                showInstruction("Let the next one come in and answer clean.", hold: 0.68)
            }
            if previous >= 5 {
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
            showInstruction("Timing slipped. Reset your feet for the next ball.", hold: 0.96)
        }
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
        showInstruction("Momentum gone. Re-center and rebuild quickly.", hold: 0.95)

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
            hudCaptionLabel?.alpha = 0
            hudPhaseLabel?.alpha = 0
            hudPhaseValueLabel?.text = ""
            hudPhaseValueLabel?.alpha = 0
            timeLabel?.alpha = 0
            hudMaxLabel?.alpha = 1
            hudMaxLabel?.text = "BEST"
        } else {
            hudCaptionLabel?.alpha = 1
            hudPhaseLabel?.alpha = 1
            hudPhaseValueLabel?.alpha = 1
            timeLabel?.alpha = 1
            hudPhaseValueLabel?.text = flow?.currentPhase.rawValue ?? "EXCHANGE"
            hudPhaseValueLabel?.fontColor = bannerColor(for: flow?.currentPhase ?? .exchange).withAlphaComponent(0.88)
        }
        hudMaxValueLabel?.text = "x\(maxCombo)"
        if (sessionMode == .wallRally ? combo > 0 : combo > 1), let comboLabel {
            comboLabel.text = comboDescriptor(for: combo)
            comboLabel.fontColor = comboAccentColor(for: combo)
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
            switch quality {
            case .perfect:
                scoreScale = 1.17
                scoreOut = 0.05
                scoreBack = 0.16
            case .great:
                scoreScale = 1.13
                scoreOut = 0.045
                scoreBack = 0.14
            case .good:
                scoreScale = 1.08
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
            switch quality {
            case .perfect:
                comboScale = 1.18
                comboOut = 0.05
                comboBack = 0.18
            case .great:
                comboScale = 1.13
                comboOut = 0.045
                comboBack = 0.16
            case .good:
                comboScale = 1.08
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

    private func stageWallStrikeBurst(at point: CGPoint, lane: Lane, quality: HitQuality) {
        guard sessionMode == .wallRally else { return }

        let openingBoost = wallOpeningCelebrationBoost()
        let color: UIColor
        let ringScale: CGFloat
        let ringDuration: TimeInterval
        switch quality {
        case .perfect:
            color = UIColor(red: 1.0, green: 0.88, blue: 0.42, alpha: 1)
            ringScale = 2.35 + openingBoost * 0.2
            ringDuration = 0.2
        case .great:
            color = UIColor(red: 0.68, green: 0.93, blue: 1.0, alpha: 1)
            ringScale = 2.1 + openingBoost * 0.16
            ringDuration = 0.22
        case .good:
            color = UIColor(red: 0.8, green: 0.95, blue: 0.86, alpha: 1)
            ringScale = 1.9 + openingBoost * 0.14
            ringDuration = 0.24
        case .miss:
            return
        }

        let ring = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.68)
        ring.position = point
        ring.strokeColor = color.withAlphaComponent(0.94)
        ring.fillColor = .clear
        ring.lineWidth = 2.4
        ring.glowWidth = 10
        ring.zPosition = 64
        addChild(ring)

        let flash = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.52)
        flash.position = point
        flash.fillColor = color.withAlphaComponent(0.46)
        flash.strokeColor = .white.withAlphaComponent(0.32)
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
                .scale(to: 1.7 + openingBoost * 0.12, duration: ringDuration * 0.72),
                .fadeOut(withDuration: ringDuration * 0.72)
            ]),
            .removeFromParent()
        ]))
    }

    private func wallHitCelebration(quality: HitQuality, lane: Lane) {
        guard sessionMode == .wallRally else { return }
        let laneDirection: CGFloat = lane == .right ? 1 : -1
        let openingBoost = wallOpeningCelebrationBoost()
        switch quality {
        case .perfect:
            CameraShake.drift(
                cameraNode,
                dx: laneDirection * (6 + openingBoost * 1.6),
                dy: -(6 + openingBoost * 1.4),
                settleDx: laneDirection * 1.2,
                settleDy: -1.2,
                outMs: 44,
                driftMs: 96,
                backMs: 180
            )
            showMomentBanner(
                text: wallPerfectMomentText(for: combo),
                color: UIColor(red: 1.0, green: 0.84, blue: 0.38, alpha: 1),
                hold: 0.18,
                startScale: 0.92,
                peakScale: 1.02
            )
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
            if let moment = wallGreatMomentText(for: combo) {
                showMomentBanner(
                    text: moment,
                    color: UIColor(red: 0.62, green: 0.92, blue: 1.0, alpha: 1),
                    hold: 0.16,
                    startScale: 0.94,
                    peakScale: 1.01
                )
            }
        case .good:
            if combo == 1 {
                showMomentBanner(
                    text: "RALLY ON",
                    color: UIColor(red: 0.76, green: 0.94, blue: 0.86, alpha: 1),
                    hold: 0.14,
                    startScale: 0.95,
                    peakScale: 1.0
                )
            } else if combo == 2 {
                showMomentBanner(
                    text: "FEEL IT",
                    color: UIColor(red: 0.72, green: 0.9, blue: 1.0, alpha: 1),
                    hold: 0.13,
                    startScale: 0.95,
                    peakScale: 1.0
                )
            } else if combo == 4 {
                showMomentBanner(
                    text: "RHYTHM",
                    color: UIColor(red: 0.88, green: 0.8, blue: 0.48, alpha: 1),
                    hold: 0.14,
                    startScale: 0.95,
                    peakScale: 1.0
                )
            }
        case .miss:
            break
        }
    }

    private func wallPerfectMomentText(for combo: Int) -> String {
        if combo >= 12 {
            return combo % 3 == 0 ? "HEATER" : "ON FIRE"
        } else if combo >= 8 {
            return combo % 2 == 0 ? "UNTOUCHABLE" : "LOCKED"
        } else if combo >= 5 && combo % 5 == 0 {
            return "ON FIRE"
        } else if combo <= 2 {
            return "SWEET"
        }
        return "CRUSHED"
    }

    private func wallGreatMomentText(for combo: Int) -> String? {
        if combo >= 10 && combo % 5 == 0 {
            return "CAN'T MISS"
        } else if combo >= 8 && combo % 4 == 0 {
            return "HEATER"
        } else if combo >= 4 && combo % 4 == 0 {
            return "LOCKED"
        }
        return nil
    }

    private func stageWallReturn(from point: CGPoint, lane: Lane, quality: HitQuality) {
        guard sessionMode == .wallRally else { return }
        let endX = lane == .left
            ? size.width * Tunables.horizonLaneInsetRatio
            : size.width * (1 - Tunables.horizonLaneInsetRatio)
        let endPoint = CGPoint(x: endX, y: size.height * Tunables.spawnLineYRatio)
        let color: UIColor
        let duration: TimeInterval
        let width: CGFloat
        let openingSnap = max(0, 1 - wallOpeningProgress())
        let comboDrive = min(1.0, Double(max(0, combo - 1)) / 10.0)
        switch quality {
        case .perfect:
            color = UIColor(red: 1.0, green: 0.88, blue: 0.42, alpha: 1)
            duration = 0.182 - openingSnap * 0.016 - comboDrive * 0.01
            width = 6.2
        case .great:
            color = UIColor(red: 0.64, green: 0.92, blue: 1.0, alpha: 1)
            duration = 0.212 - openingSnap * 0.013 - comboDrive * 0.009
            width = 5.0
        case .good:
            color = UIColor(red: 0.78, green: 0.94, blue: 0.84, alpha: 1)
            duration = 0.248 - openingSnap * 0.011 - comboDrive * 0.007
            width = 4.1
        case .miss:
            return
        }

        let trail = SKShapeNode()
        trail.zPosition = 63
        trail.lineCap = .round
        trail.strokeColor = color.withAlphaComponent(0.88)
        trail.lineWidth = width
        trail.glowWidth = width * 1.8

        let laneDirection: CGFloat = lane == .right ? 1 : -1
        let control = CGPoint(
            x: (point.x + endPoint.x) * 0.5 + laneDirection * size.width * 0.009,
            y: point.y - size.height * 0.014 + openingSnap * size.height * 0.006 - CGFloat(comboDrive) * size.height * 0.004
        )
        let path = CGMutablePath()
        path.move(to: point)
        path.addQuadCurve(to: endPoint, control: control)
        trail.path = path
        addChild(trail)

        let ghost = SKShapeNode(circleOfRadius: quality == .perfect ? 8 : 7)
        ghost.fillColor = UIColor(red: 0.93, green: 0.97, blue: 0.36, alpha: 1)
        ghost.strokeColor = color.withAlphaComponent(0.72)
        ghost.lineWidth = 1.2
        ghost.glowWidth = 8
        ghost.position = point
        ghost.zPosition = 64
        addChild(ghost)

        let move = SKAction.customAction(withDuration: duration) { [weak ghost] _, elapsed in
            guard let ghost else { return }
            let t = max(0, min(1, elapsed / duration))
            let inverse = 1 - t
            let x = inverse * inverse * point.x + 2 * inverse * t * control.x + t * t * endPoint.x
            let y = inverse * inverse * point.y + 2 * inverse * t * control.y + t * t * endPoint.y
            ghost.position = CGPoint(x: x, y: y)
            ghost.setScale(0.98 + (1 - CGFloat(t)) * 0.06 - CGFloat(t) * 0.14)
            ghost.alpha = inverse * 0.98
        }
        ghost.run(.sequence([
            move,
            .removeFromParent()
        ]))

        trail.run(.sequence([
            .group([
                .fadeOut(withDuration: duration * 0.92),
                .scaleY(to: 0.8, duration: duration * 0.92)
            ]),
            .removeFromParent()
        ]))
    }

    private func contactCandidateScore(for ball: BallNode, around trackTime: Double, contactPoint: CGPoint) -> CGFloat {
        let timeScore = CGFloat(abs(ball.arrivalTime - trackTime) * 1000)
        let distanceScore = ball.position.distance(to: contactPoint)
        if sessionMode == .wallRally {
            let approach = ball.approachToStrike(at: trackTime)
            let approachBonus = (1 - approach) * 22
            return timeScore * 0.92 + distanceScore * 0.76 + approachBonus
        }
        return timeScore + distanceScore * 0.9
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
            openingScalar = 0.97
        case 2:
            openingScalar = 0.94
        case 3:
            openingScalar = 0.92
        default:
            openingScalar = combo >= 6 ? 0.88 : (combo >= 3 ? 0.91 : 0.94)
        }
        return Tunables.ballTravelSeconds * 1.0 * matchPace.travelScalar * openingScalar
    }

    private func wallCurveAmount() -> CGFloat {
        guard sessionMode == .wallRally else { return Tunables.laneCurveAmount }
        let openingBonus = wallOpeningCelebrationBoost()
        return Tunables.laneCurveAmount * max(0.16, 0.26 - openingBonus * 0.04)
    }

    private func wallCadenceSeconds(for quality: HitQuality) -> Double {
        let base: Double
        switch (matchPace, quality) {
        case (.calm, .perfect):
            base = 0.7
        case (.calm, .great):
            base = 0.76
        case (.calm, .good):
            base = 0.84
        case (.calm, .miss):
            base = 1.08
        case (.standard, .perfect):
            base = 0.62
        case (.standard, .great):
            base = 0.68
        case (.standard, .good):
            base = 0.76
        case (.standard, .miss):
            base = 1.0
        case (.quick, .perfect):
            base = 0.54
        case (.quick, .great):
            base = 0.6
        case (.quick, .good):
            base = 0.68
        case (.quick, .miss):
            base = 0.92
        }
        let comboScalar = combo >= 8 ? 0.8 : (combo >= 4 ? 0.88 : 0.94)
        return base * wallOpeningCadenceScalar() * comboScalar
    }

    private func wallMissRestartSeconds(previousCombo: Int) -> Double {
        let base = wallCadenceSeconds(for: .miss)
        if previousCombo >= 6 {
            return base * 0.62
        }
        if previousCombo >= 2 {
            return base * 0.68
        }
        return base * 0.72
    }

    private func wallReturnSnapScalar(for quality: HitQuality) -> Double {
        guard sessionMode == .wallRally else { return 1.0 }
        let openingBonus = max(0, 1.0 - wallOpeningProgress())
        switch quality {
        case .perfect:
            return 0.84 - openingBonus * 0.04
        case .great:
            return 0.88 - openingBonus * 0.03
        case .good:
            return 0.92 - openingBonus * 0.02
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
        lane == .left ? size.width * 0.34 : size.width * 0.66
    }

    private func wallStrikeFreezeScalar(for quality: HitQuality) -> Double {
        guard sessionMode == .wallRally else { return 1.0 }
        let openingBoost = Double(wallOpeningCelebrationBoost())
        switch quality {
        case .perfect:
            return 1.12 + openingBoost * 0.08
        case .great:
            return 1.08 + openingBoost * 0.06
        case .good:
            return 1.04 + openingBoost * 0.04
        case .miss:
            return 1.0
        }
    }

    private func wallOpeningCadenceScalar() -> Double {
        switch spawnedBallCount {
        case ..<2:
            return 1.24
        case 2:
            return 1.17
        case 3:
            return 1.1
        case 4:
            return 1.05
        default:
            return 1.0
        }
    }

    private func wallOpeningProgress() -> Double {
        min(1, Double(max(0, spawnedBallCount - 1)) / 5)
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
            ? effectiveRacketMissRadius(for: lane) * (1.74 + wallOpeningForgivenessBoost() * 0.24)
            : effectiveRacketMissRadius(for: lane)
    }

    private func adjustedWallGradingDistance(_ distance: CGFloat, lane: Lane) -> CGFloat {
        guard sessionMode == .wallRally else { return distance }
        let offCenter = effectiveRacketOffCenterRadius(for: lane) * 1.12
        let assistRadius = wallAssistMissRadius(for: lane)
        guard distance > offCenter, distance < assistRadius else { return distance }
        return offCenter + (distance - offCenter) * 0.28
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
        let sweetSpot = effectiveRacketSweetSpot(for: lane) * (1.34 + openingBoost * 0.08)
        let offCenter = effectiveRacketOffCenterRadius(for: lane) * (1.28 + openingBoost * 0.08)
        let fastEnough = swingSpeed >= Tunables.swingFastVelocity * 0.24

        if quality == .good,
           fastEnough,
           gradingDistance <= offCenter,
           delta <= HitQuality.great.windowSeconds * windowScalar * (1.24 + Double(openingBoost) * 0.08) {
            return .great
        }

        if quality == .great,
           gradingDistance <= sweetSpot,
           delta <= HitQuality.perfect.windowSeconds * windowScalar * (1.34 + Double(openingBoost) * 0.08) {
            return .perfect
        }

        if quality == .miss,
           fastEnough,
           gradingDistance <= offCenter * 0.98,
           delta <= HitQuality.good.windowSeconds * windowScalar * (1.16 + Double(openingBoost) * 0.1) {
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

    private func stageResetBeat(duration: TimeInterval) {
        betweenPointLiftUntil = max(betweenPointLiftUntil, currentTimeSnapshot + duration)
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
        switch quality {
        case .perfect:
            let dx = laneDirection * (ball.role == .changeup ? 8 : 5)
            let dy: CGFloat = ball.role == .serve ? -5 : (ball.role == .changeup ? -7 : -4)
            CameraShake.drift(
                cameraNode,
                dx: dx,
                dy: dy,
                settleDx: dx * 0.22,
                settleDy: dy * 0.18,
                outMs: 48,
                driftMs: 110,
                backMs: 220
            )
        case .great:
            CameraShake.drift(
                cameraNode,
                dx: laneDirection * 3,
                dy: -3,
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
        let ring = SKShapeNode(circleOfRadius: quality == .perfect ? 18 : (quality == .great ? 14 : 11))
        ring.position = point
        ring.fillColor = .clear
        ring.strokeColor = palette.glow.withAlphaComponent(quality == .good ? 0.46 : 0.78)
        ring.lineWidth = quality == .perfect ? 2.4 : 1.7
        ring.glowWidth = quality == .perfect ? 12 : 7
        ring.zPosition = 64
        addChild(ring)

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

        ring.run(.sequence([
            .group([
                .scale(to: quality == .perfect ? 1.9 : 1.55, duration: 0.2),
                .fadeOut(withDuration: 0.2)
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
            if ball.role == .returnBall && phase != .warmUp {
                showInstruction("You held it. Re-center for the next exchange.", hold: 0.62)
            }
        case .miss:
            break
        }
    }

    private func showInstruction(_ text: String, hold: TimeInterval) {
        guard showCoachingCues else { return }
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

    private func registerMultiHit(_ hits: [(BallNode, HitQuality, StrokeSide, SwingIntent, CGFloat)]) {
        for (ball, quality, strokeSide, swingIntent, contactDistance) in hits {
            guard activeBalls.contains(where: { $0 === ball }) else { continue }
            registerHit(
                ball: ball,
                quality: quality,
                strokeSide: strokeSide,
                swingIntent: swingIntent,
                contactDistance: contactDistance
            )
        }
    }

    private func linkedDoublePartner(for ball: BallNode) -> BallNode? {
        activeBalls.first { candidate in
            guard candidate !== ball else { return false }
            guard candidate.lane != ball.lane else { return false }
            guard abs(candidate.arrivalTime - ball.arrivalTime) <= Tunables.doubleArrivalToleranceSeconds else {
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
            return 1.5 + Double(wallOpeningForgivenessBoost()) * 0.08
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
            ? Tunables.recoveryBaseSeconds * 0.54
            : Tunables.recoveryBaseSeconds
        let stretchSeconds = sessionMode == .wallRally
            ? Tunables.recoveryStretchSeconds * 0.48
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
            if cleanReturnPickups <= 2 || quality == .perfect {
                showInstruction("Clean return taken on the rise.", hold: 0.78)
            }
        }

        if ball.role == .changeup, (quality == .great || quality == .perfect) {
            changeupWinners += 1
            let winnerText = strokeSide == .forehand && swingIntent == .drive
                ? "Forehand variation lands clean."
                : "Variation lands clean."
            showInstruction(winnerText, hold: 0.82)
        }

        if phase == .pressure || phase == .breaker {
            if ball.role != .serve, (quality == .great || quality == .perfect) {
                pressureExchangeStreak += 1
                if pressureExchangeStreak == 4 {
                    pressureHolds += 1
                    pressureExchangeStreak = 0
                    showInstruction("Pressure absorbed. You stayed composed through it.", hold: 0.86)
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

    let lane: Lane
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
    private var trackingEmphasis: CGFloat = 0
    private let auraNode = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 1.4)
    private let warningRingNode = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 2.1)
    private let focusRingNode = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 2.65)
    private let tailNode = SKShapeNode(ellipseOf: CGSize(width: Tunables.ballRadiusPoints * 2.8, height: Tunables.ballRadiusPoints * 0.92))
    private let shadowNode = SKShapeNode(ellipseOf: CGSize(width: Tunables.ballRadiusPoints * 1.6, height: Tunables.ballRadiusPoints * 0.62))
    private let coreNode = SKShapeNode(circleOfRadius: Tunables.ballRadiusPoints * 0.34)

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
        fillColor = overrideFillColor ?? (lane == .left
            ? UIColor(red: 0, green: 1, blue: 1, alpha: 1)
            : UIColor(red: 1, green: 0.2, blue: 0.7, alpha: 1))
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

        coreNode.fillColor = UIColor.white.withAlphaComponent(0.18)
        coreNode.strokeColor = .clear
        coreNode.zPosition = 1
        addChild(coreNode)

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
            glowWidth = max(glowWidth, 12)
            auraNode.fillColor = fillColor.withAlphaComponent(0.18)
            warningRingNode.lineWidth += 0.4
            coreNode.fillColor = UIColor.white.withAlphaComponent(0.32)
        }
        updatePresentation(progress: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setTrackingEmphasis(_ emphasis: CGFloat) {
        trackingEmphasis = max(0, min(1, emphasis))
    }

    func approachToStrike(at trackTime: Double) -> CGFloat {
        let progress = max(0, min(1.12, CGFloat((trackTime - spawnTime) / travelSeconds)))
        let distanceToArrival = abs(1 - progress)
        let nearWindow = max(0, 1 - distanceToArrival / 0.32)
        return min(1, nearWindow)
    }

    func updatePresentation(progress rawProgress: CGFloat) {
        let progress = max(0, min(1.18, rawProgress))
        let eased = remappedProgress(for: progress)
        let overrun = max(0, progress - 1.0)
        let bounceProgress = bounceProgressForShape()
        let adjusted = progressThroughBounce(for: eased, bounceProgress: bounceProgress)
        let baseX = lerp(from: spawnPoint.x, to: strikePoint.x, progress: adjusted)
        let baseY = lerp(from: spawnPoint.y, to: strikePoint.y, progress: adjusted)
        let curveDirection: CGFloat = lane == .left ? -1 : 1
        let curve = sin(eased * .pi) * curveAmountForShape() * abs(strikePoint.x - spawnPoint.x)
        let arcLift = flightLift(for: eased, bounceProgress: bounceProgress)
        let bounceKick = bounceKickLift(for: eased, bounceProgress: bounceProgress)
        let compression = bounceCompression(for: eased, bounceProgress: bounceProgress)

        position = CGPoint(
            x: baseX + curveDirection * curve,
            y: baseY + arcLift + bounceKick - overrun * overrunDropDistance()
        )

        let scale: CGFloat
        if wallStyleMode, progress <= 1 {
            let contactEmphasis = wallContactEmphasis(for: eased)
            scale = lerp(
                from: spawnScale * 0.46,
                to: strikeScaleForShape() * 1.34,
                progress: eased
            ) + contactEmphasis * 0.14
        } else if progress <= 1 {
            scale = lerp(from: spawnScale, to: strikeScaleForShape(), progress: eased)
        } else {
            scale = lerp(
                from: strikeScaleForShape(),
                to: overrunScaleForShape(),
                progress: min(1, overrun * 2.5)
            )
        }
        xScale = scale * (1 + compression * 0.38)
        yScale = scale * (1 - compression * 0.24)

        zRotation = curveDirection * rotationForShape(progress: eased)
        alpha = progress <= 1 ? 1.0 : max(0.55, 1 - overrun * 1.8)
        let trackingLift = trackingEmphasisForProgress(progress: eased, bounceProgress: bounceProgress)
        let wallApproachLift: CGFloat = wallStyleMode ? max(0, 1 - abs(eased - 0.78) / 0.32) : 0
        let wallLockLift: CGFloat = wallStyleMode ? max(0, 1 - abs(eased - 0.86) / 0.14) : 0
        warningRingNode.alpha = progress <= 1 ? min(1, (1 - eased * 0.92) + trackingLift * 0.52 + wallApproachLift * 0.18) : 0
        auraNode.alpha = min(1, auraAlpha(for: progress) + trackingLift * 0.18 + wallApproachLift * 0.12 + wallLockLift * 0.08)
        coreNode.alpha = min(1, coreAlpha(for: progress) + trackingLift * 0.18 + wallApproachLift * 0.08 + wallLockLift * 0.14)
        coreNode.setScale(coreScale(for: progress) + trackingLift * 0.08 + wallApproachLift * 0.05 + wallLockLift * 0.08)
        warningRingNode.lineWidth = ringWidth(for: progress) + trackingLift * 1.2
        warningRingNode.glowWidth = baseRingGlowWidth() + trackingLift * 10
        warningRingNode.strokeColor = trackingStrokeColor(intensity: trackingLift)
        focusRingNode.alpha = focusRingAlpha(progress: eased, trackingLift: trackingLift) + wallLockLift * 0.36
        focusRingNode.lineWidth = 1.4 + trackingLift * 1.6 + wallLockLift * 1.2
        focusRingNode.glowWidth = trackingLift * (kind == .double ? 14 : 10) + wallLockLift * 8
        focusRingNode.setScale(1.0 + trackingLift * 0.18 - wallLockLift * 0.08)
        focusRingNode.strokeColor = focusRingColor(intensity: min(1, trackingLift + wallLockLift * 0.55))
        updateTail(progress: progress, eased: eased, bounceProgress: bounceProgress, overrun: overrun)
        updateShadow(progress: eased, bounceProgress: bounceProgress, overrun: overrun)
    }

    func contactWindowPhase(at trackTime: Double) -> ContactWindowPhase {
        let rawProgress = CGFloat(max(0, min(1.12, (trackTime - spawnTime) / travelSeconds)))
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
            return 1 - pow(1 - min(1, progress), 1.7)
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
            let wallContactPoint: CGFloat = 0.86
            if progress < wallContactPoint {
                let local = progress / wallContactPoint
                let accelerated = 1 - pow(1 - local, 1.55)
                return accelerated * 0.965
            } else {
                let local = (progress - wallContactPoint) / max(0.001, 1 - wallContactPoint)
                let easedOut = 1 - pow(1 - local, 2.8)
                let held = 0.965 + easedOut * 0.035
                let contactBrake = wallContactEmphasis(for: progress) * 0.085
                return max(0, min(1, held - contactBrake))
            }
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
            let forwardLift = sin(progress * .pi) * laneDistance * 0.016
            return forwardLift
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
            return wallContactEmphasis(for: progress) * 0.46
        }
        let distance = abs(progress - bounceProgress)
        let width = max(0.035, bounceCompressionForShape())
        guard distance < width else { return 0 }
        return 1 - distance / width
    }

    private func updateShadow(progress: CGFloat, bounceProgress: CGFloat, overrun: CGFloat) {
        let depthScale = lerp(from: 0.42, to: 1.22, progress: min(1, progress))
        let widthBoost = progress >= bounceProgress ? 1.0 : 1.0
        shadowNode.setScale(depthScale * widthBoost)
        shadowNode.position = CGPoint(x: 0, y: shadowOffsetY(for: progress, bounceProgress: bounceProgress, overrun: overrun))
        let fadeStart = max(0, bounceProgress - 0.14)
        let alpha: CGFloat
        if progress >= bounceProgress {
            alpha = 0
        } else if progress >= fadeStart {
            let fade = 1 - ((progress - fadeStart) / max(0.001, bounceProgress - fadeStart))
            alpha = Tunables.bounceShadowAlpha * fade
        } else {
            alpha = Tunables.bounceShadowAlpha
        }
        shadowNode.alpha = max(0, alpha - overrun * 0.18)
    }

    private func updateTail(progress: CGFloat, eased: CGFloat, bounceProgress: CGFloat, overrun: CGFloat) {
        let curveDirection: CGFloat = lane == .left ? -1 : 1
        let motion = max(0, 1 - eased)
        let airborne = max(0, (bounceProgress - min(eased, bounceProgress)) / max(0.001, bounceProgress))
        let baseLength = tailLengthForRole() * (0.82 + motion * 0.74)
        let xOffset = -curveDirection * baseLength * 0.34
        let yOffset = -14 - baseLength * 0.18
        tailNode.position = CGPoint(x: xOffset, y: yOffset)
        tailNode.zRotation = zRotation + curveDirection * 0.18
        tailNode.xScale = 0.72 + baseLength / 26
        tailNode.yScale = 0.74 + airborne * 0.18

        let roleAlpha = tailAlphaForRole()
        if eased >= bounceProgress || overrun > 0 {
            tailNode.alpha = 0
        } else {
            tailNode.alpha = roleAlpha * airborne * max(0.18, 1 - eased * 0.88)
        }
    }

    private func shadowOffsetY(for progress: CGFloat, bounceProgress: CGFloat, overrun: CGFloat) -> CGFloat {
        let offset = progress < bounceProgress ? 18 - progress * 8 : 10 + overrun * 18
        return -offset
    }

    private func wallContactEmphasis(for progress: CGFloat) -> CGFloat {
        max(0, 1 - abs(progress - 0.89) / 0.11)
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
        case .drive: base = curveAmount * 0.9
        case .topspin: base = curveAmount * 1.18
        case .skid: base = curveAmount * 0.78
        case .floater: base = curveAmount * 1.08
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
        case .drive: base = strikeScale * 1.03
        case .topspin: base = strikeScale * 1.02
        case .skid: base = strikeScale * 0.98
        case .floater: base = strikeScale * 0.94
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
        case .drive: base = overrunScale * 1.02
        case .topspin: base = overrunScale * 1.03
        case .skid: base = overrunScale * 0.97
        case .floater: base = overrunScale * 0.95
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
}

private extension UIColor {
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
