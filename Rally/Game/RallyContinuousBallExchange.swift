import CoreGraphics
import Foundation

enum RallyContinuousExchangePhase: String {
    case racketApproach
    case racketAbsorb
    case racketCompression
    case racketDwell
    case racketRelease
    case wallApproach
    case wallCompression
    case wallDwell
    case wallDecompression
    case wallRebound
    case complete
}

struct RallyExchangeConfig {
    var racket: RacketContactConfig
    var wall: WallKinematicsConfig
    var reboundFadeOutLead: CGFloat

    static let rallyDefault = RallyExchangeConfig(
        racket: .rallyDefault,
        wall: .rallyDefault,
        reboundFadeOutLead: 0.22
    )
}

struct RallyContinuousBallExchangeFrame {
    let phase: RallyContinuousExchangePhase
    let point: CGPoint
    let xScale: CGFloat
    let yScale: CGFloat
    let alpha: CGFloat
    let shadowAlpha: CGFloat
    let shadowXScale: CGFloat
    let didBeginWallImpact: Bool
    let isComplete: Bool
}

final class RallyContinuousBallExchange {
    let ball: BallNode

    private let config: RallyExchangeConfig
    private let racketModel: RallyManualContactModel
    private let wallModel: RallyWallRallyKinematics
    private let startPoint: CGPoint
    private let contactPoint: CGPoint
    private let wallContactPoint: CGPoint
    private let direction: CGFloat
    private let inboundSpeed: CGFloat
    private let offsetFromCenter: CGFloat
    private let startTime: TimeInterval

    private var lastPhase: RallyContinuousExchangePhase = .racketApproach
    private var wallImpactTriggered = false

    init(
        ball: BallNode,
        startPoint: CGPoint,
        contactPoint: CGPoint,
        wallContactPoint: CGPoint,
        direction: CGFloat,
        inboundSpeed: CGFloat,
        offsetFromCenter: CGFloat,
        startTime: TimeInterval,
        config: RallyExchangeConfig = .rallyDefault
    ) {
        self.ball = ball
        self.startPoint = startPoint
        self.contactPoint = contactPoint
        self.wallContactPoint = wallContactPoint
        self.direction = direction
        self.inboundSpeed = inboundSpeed
        self.offsetFromCenter = offsetFromCenter
        self.startTime = startTime
        self.config = config
        self.racketModel = RallyManualContactModel(config: config.racket)
        self.wallModel = RallyWallRallyKinematics(config: config.wall)
    }

    var totalDuration: TimeInterval {
        config.racket.totalDuration + config.wall.totalDuration
    }

    func isStranded(at currentTime: TimeInterval, grace: TimeInterval) -> Bool {
        ball.parent == nil || currentTime - startTime > totalDuration + grace
    }

    func frame(at currentTime: TimeInterval) -> RallyContinuousBallExchangeFrame {
        let elapsed = max(0, currentTime - startTime)
        let isComplete = elapsed >= totalDuration

        if elapsed < config.racket.totalDuration {
            let progress = CGFloat(elapsed / max(0.0001, config.racket.totalDuration))
            let racketFrame = racketModel.frame(
                start: startPoint,
                contact: contactPoint,
                direction: direction,
                progress: progress,
                inboundSpeed: inboundSpeed,
                offsetFromCenter: offsetFromCenter
            )
            let phase = map(racketFrame.phase)
            lastPhase = phase
            return RallyContinuousBallExchangeFrame(
                phase: phase,
                point: racketFrame.contactPoint,
                xScale: racketFrame.xScale,
                yScale: racketFrame.yScale,
                alpha: 1,
                shadowAlpha: racketFrame.shadowAlpha,
                shadowXScale: racketFrame.shadowXScale,
                didBeginWallImpact: false,
                isComplete: false
            )
        }

        let releasePoint = racketModel.frame(
            start: startPoint,
            contact: contactPoint,
            direction: direction,
            progress: 1,
            inboundSpeed: inboundSpeed,
            offsetFromCenter: offsetFromCenter
        ).contactPoint

        let wallElapsed = min(config.wall.totalDuration, elapsed - config.racket.totalDuration)
        let wallProgress = CGFloat(wallElapsed / max(0.0001, config.wall.totalDuration))
        let wallFrame = wallModel.frame(
            start: releasePoint,
            wallContact: wallContactPoint,
            reboundDirection: direction,
            progress: wallProgress
        )
        let phase = map(wallFrame.phase)
        let didBeginWallImpact = !wallImpactTriggered && lastPhase != .wallDwell && phase == .wallDwell
        if didBeginWallImpact {
            wallImpactTriggered = true
        }
        lastPhase = phase

        let reboundFade = max(0, wallProgress - (1 - config.reboundFadeOutLead)) / max(0.0001, config.reboundFadeOutLead)
        let alpha = phase == .wallRebound ? max(0.32, 1 - reboundFade * 0.68) : 1
        let depth = depthScalar(forWallProgress: wallProgress)

        return RallyContinuousBallExchangeFrame(
            phase: isComplete ? .complete : phase,
            point: wallFrame.point,
            xScale: wallFrame.xScale * depth,
            yScale: wallFrame.yScale * depth,
            alpha: alpha,
            shadowAlpha: wallFrame.shadowAlpha,
            shadowXScale: wallFrame.shadowXScale * depth,
            didBeginWallImpact: didBeginWallImpact,
            isComplete: isComplete
        )
    }

    /// Perspective shrink on the outbound leg: the ball leaves the racket at
    /// player depth (1.0) and reads as far (wallExchangeDepthFarScale) by the
    /// time it reaches the wall plane. Ease-out so the shrink is fastest right
    /// off the racket — the strongest "traveling away" cue — then settles.
    /// From compression onward the ball stays at far depth until reentry
    /// hands it back toward the player.
    private func depthScalar(forWallProgress progress: CGFloat) -> CGFloat {
        let approachEnd = CGFloat(config.wall.approachDuration / max(0.0001, config.wall.totalDuration))
        let local = max(0, min(1, progress / max(0.0001, approachEnd)))
        let inverted = 1 - local
        let eased = 1 - inverted * inverted
        return 1 + (Tunables.wallExchangeDepthFarScale - 1) * eased
    }

    private func map(_ phase: RallyManualContactPhase) -> RallyContinuousExchangePhase {
        switch phase {
        case .approach: return .racketApproach
        case .absorb: return .racketAbsorb
        case .compression: return .racketCompression
        case .dwell: return .racketDwell
        case .release, .separation: return .racketRelease
        }
    }

    private func map(_ phase: RallyWallRallyPhase) -> RallyContinuousExchangePhase {
        switch phase {
        case .approach: return .wallApproach
        case .compression: return .wallCompression
        case .dwell: return .wallDwell
        case .decompression: return .wallDecompression
        case .rebound, .recovery: return .wallRebound
        }
    }
}
