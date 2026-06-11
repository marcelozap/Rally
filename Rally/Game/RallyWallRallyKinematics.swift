import CoreGraphics
import Foundation

enum RallyWallRallyPhase: String {
    case approach
    case compression
    case dwell
    case decompression
    case rebound
    case recovery
}

struct WallKinematicsConfig {
    var inboundSpeed: CGFloat
    var wallContactBrake: CGFloat
    var compressionAmount: CGFloat
    var dwellDuration: TimeInterval
    var decompressionDuration: TimeInterval
    var reboundAcceleration: CGFloat
    var reboundArcLift: CGFloat
    var shadowFade: CGFloat
    var xSquashAtWall: CGFloat
    var ySquashAtWall: CGFloat
    var xStretchOnRebound: CGFloat
    var yStretchOnRebound: CGFloat
    var reboundTravelDistance: CGFloat
    var totalDuration: TimeInterval

    static let rallyDefault = WallKinematicsConfig(
        inboundSpeed: 1.0,
        wallContactBrake: Tunables.wallReturnExitSpeedScalar,
        compressionAmount: Tunables.wallOutboundCompressionAmount,
        dwellDuration: Tunables.wallOutboundDwellSeconds,
        decompressionDuration: Tunables.wallOutboundReleaseSeconds,
        reboundAcceleration: 1.0 + Tunables.wallReturnAccelerationGain,
        reboundArcLift: Tunables.wallOutboundReboundLiftRatio * 100,
        shadowFade: 0.24,
        xSquashAtWall: 1.42,
        ySquashAtWall: 0.68,
        xStretchOnRebound: 0.92,
        yStretchOnRebound: 1.12,
        reboundTravelDistance: 28,
        totalDuration: 0.22
    )

    var compressionDuration: TimeInterval {
        max(0.028, Tunables.wallOutboundCompressionSeconds)
    }

    var approachDuration: TimeInterval {
        max(0.06, totalDuration - compressionDuration - dwellDuration - decompressionDuration - 0.05)
    }

    var reboundDuration: TimeInterval {
        max(0.038, totalDuration - approachDuration - compressionDuration - dwellDuration - decompressionDuration)
    }
}

struct RallyWallRallyFrame {
    let phase: RallyWallRallyPhase
    let point: CGPoint
    let xScale: CGFloat
    let yScale: CGFloat
    let shadowAlpha: CGFloat
    let shadowXScale: CGFloat
}

struct RallyWallRallyKinematics {
    let config: WallKinematicsConfig

    func phase(at progress: CGFloat) -> RallyWallRallyPhase {
        let p = max(0, min(1, progress))
        let approachEnd = normalized(config.approachDuration)
        let compressionEnd = normalized(config.approachDuration + config.compressionDuration)
        let dwellEnd = normalized(config.approachDuration + config.compressionDuration + config.dwellDuration)
        let decompressionEnd = normalized(config.approachDuration + config.compressionDuration + config.dwellDuration + config.decompressionDuration)
        let reboundEnd = normalized(config.totalDuration - 0.0001)

        switch p {
        case ..<approachEnd: return .approach
        case ..<compressionEnd: return .compression
        case ..<dwellEnd: return .dwell
        case ..<decompressionEnd: return .decompression
        case ..<reboundEnd: return .rebound
        default: return .recovery
        }
    }

    func compressionScalar(at progress: CGFloat) -> CGFloat {
        switch phase(at: progress) {
        case .compression:
            let start = normalized(config.approachDuration)
            let end = normalized(config.approachDuration + config.compressionDuration)
            let local = max(0, min(1, (progress - start) / max(0.0001, end - start)))
            return easeOutCubic(local) * config.compressionAmount
        case .dwell:
            return config.compressionAmount
        case .decompression:
            let start = normalized(config.approachDuration + config.compressionDuration + config.dwellDuration)
            let end = normalized(config.approachDuration + config.compressionDuration + config.dwellDuration + config.decompressionDuration)
            let local = max(0, min(1, (progress - start) / max(0.0001, end - start)))
            return (1 - easeOutCubic(local)) * config.compressionAmount
        default:
            return 0
        }
    }

    func dwellScalar(at progress: CGFloat) -> CGFloat {
        phase(at: progress) == .dwell ? 1 : 0
    }

    func reboundVelocityScalar(at progress: CGFloat) -> CGFloat {
        switch phase(at: progress) {
        case .rebound:
            let start = normalized(config.approachDuration + config.compressionDuration + config.dwellDuration + config.decompressionDuration)
            let local = max(0, min(1, (progress - start) / max(0.0001, 1 - start)))
            return lerp(config.wallContactBrake, config.reboundAcceleration, acceleratingReboundProgress(local))
        case .recovery:
            return config.reboundAcceleration
        default:
            return 0
        }
    }

    func reboundLiftScalar(at progress: CGFloat) -> CGFloat {
        reboundVelocityScalar(at: progress) * config.reboundArcLift
    }

    func shadowAlpha(at progress: CGFloat) -> CGFloat {
        let compression = compressionScalar(at: progress) / max(0.0001, config.compressionAmount)
        let rebound = reboundVelocityScalar(at: progress) / max(0.0001, config.reboundAcceleration)
        return max(0, (0.42 + compression * 0.18) - rebound * config.shadowFade)
    }

    func xScale(at progress: CGFloat) -> CGFloat {
        let phase = phase(at: progress)
        if phase == .rebound || phase == .recovery {
            let rebound = reboundVelocityScalar(at: progress) / max(0.0001, config.reboundAcceleration)
            return lerp(1, config.xStretchOnRebound, rebound)
        }
        let compression = compressionScalar(at: progress) / max(0.0001, config.compressionAmount)
        return lerp(1, config.xSquashAtWall, compression)
    }

    func yScale(at progress: CGFloat) -> CGFloat {
        let phase = phase(at: progress)
        if phase == .rebound || phase == .recovery {
            let rebound = reboundVelocityScalar(at: progress) / max(0.0001, config.reboundAcceleration)
            return lerp(1, config.yStretchOnRebound, rebound)
        }
        let compression = compressionScalar(at: progress) / max(0.0001, config.compressionAmount)
        return lerp(1, config.ySquashAtWall, compression)
    }

    func point(
        start: CGPoint,
        wallContact: CGPoint,
        reboundDirection: CGFloat,
        progress: CGFloat
    ) -> CGPoint {
        let p = max(0, min(1, progress))
        let approachEnd = normalized(config.approachDuration)
        let reboundStart = normalized(config.approachDuration + config.compressionDuration + config.dwellDuration + config.decompressionDuration)

        if p < approachEnd {
            let local = easeOutCubic(p / max(0.0001, approachEnd))
            let control = CGPoint(
                x: (start.x + wallContact.x) * 0.5 + reboundDirection * 8,
                y: start.y + max(10, (wallContact.y - start.y) * 0.18)
            )
            let inverse = 1 - local
            return CGPoint(
                x: inverse * inverse * start.x + 2 * inverse * local * control.x + local * local * wallContact.x,
                y: inverse * inverse * start.y + 2 * inverse * local * control.y + local * local * wallContact.y
            )
        }

        if p < reboundStart {
            let compression = compressionScalar(at: p) / max(0.0001, config.compressionAmount)
            return CGPoint(
                x: wallContact.x + reboundDirection * compression * 3.2,
                y: wallContact.y - compression * 1.8
            )
        }

        let rawLocal = (p - reboundStart) / max(0.0001, 1 - reboundStart)
        let local = acceleratingReboundProgress(rawLocal)
        return CGPoint(
            x: wallContact.x - reboundDirection * config.reboundTravelDistance * local,
            y: wallContact.y - reboundLiftScalar(at: p) * 0.12 * local
        )
    }

    func frame(
        start: CGPoint,
        wallContact: CGPoint,
        reboundDirection: CGFloat,
        progress: CGFloat
    ) -> RallyWallRallyFrame {
        let p = max(0, min(1, progress))
        let compression = compressionScalar(at: p) / max(0.0001, config.compressionAmount)
        return RallyWallRallyFrame(
            phase: phase(at: p),
            point: point(start: start, wallContact: wallContact, reboundDirection: reboundDirection, progress: p),
            xScale: xScale(at: p),
            yScale: yScale(at: p),
            shadowAlpha: shadowAlpha(at: p),
            shadowXScale: lerp(0.86, 1.34, compression)
        )
    }

    private func normalized(_ elapsed: TimeInterval) -> CGFloat {
        CGFloat(elapsed / max(0.0001, config.totalDuration))
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    private func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let inverted = 1 - t
        return 1 - inverted * inverted * inverted
    }

    private func acceleratingReboundProgress(_ t: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, t))
        let eased = clamped * clamped * (2.2 - 1.2 * clamped)
        return max(0, min(1, eased))
    }
}
