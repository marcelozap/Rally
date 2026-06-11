import CoreGraphics
import Foundation

enum RallyManualContactPhase: String {
    case approach
    case absorb
    case compression
    case dwell
    case release
    case separation
}

struct RacketContactConfig {
    var approachSpeedScalar: CGFloat
    var absorbBrakeAmount: CGFloat
    var compressionAmount: CGFloat
    var dwellDuration: TimeInterval
    var releaseDuration: TimeInterval
    var outgoingAcceleration: CGFloat
    var contactOffsetClamp: CGFloat
    var racketPenetrationTolerance: CGFloat
    var xSquashAtPeak: CGFloat
    var ySquashAtPeak: CGFloat
    var xStretchAtRelease: CGFloat
    var yStretchAtRelease: CGFloat
    var sweetSpotRadius: CGFloat
    var offCenterMinScalar: CGFloat
    var stringFlexDistance: CGFloat
    var separationDistance: CGFloat

    static let rallyDefault = RacketContactConfig(
        approachSpeedScalar: 1.08,
        absorbBrakeAmount: 0.72,
        compressionAmount: 0.78,
        dwellDuration: Tunables.racketContactDwellSeconds,
        releaseDuration: Tunables.racketContactReleaseSeconds,
        outgoingAcceleration: 1.24,
        contactOffsetClamp: Tunables.racketContactExitDistance * 0.58,
        racketPenetrationTolerance: 4,
        xSquashAtPeak: Tunables.racketContactCompressionScaleX,
        ySquashAtPeak: Tunables.racketContactCompressionScaleY,
        xStretchAtRelease: Tunables.racketContactReleaseScaleX,
        yStretchAtRelease: Tunables.racketContactReleaseScaleY,
        sweetSpotRadius: 24,
        offCenterMinScalar: 0.58,
        stringFlexDistance: Tunables.racketStringFlexDistance,
        separationDistance: Tunables.racketContactExitDistance
    )

    var approachDuration: TimeInterval {
        max(0.016, Tunables.racketContactApproachSeconds / max(0.25, approachSpeedScalar))
    }

    var absorbDuration: TimeInterval {
        max(0.014, approachDuration * 0.62)
    }

    var compressionDuration: TimeInterval {
        max(0.018, approachDuration * 0.88)
    }

    var totalDuration: TimeInterval {
        approachDuration + absorbDuration + compressionDuration + dwellDuration + releaseDuration
    }
}

struct RallyManualContactFrame {
    let phase: RallyManualContactPhase
    let contactPoint: CGPoint
    let xScale: CGFloat
    let yScale: CGFloat
    let shadowAlpha: CGFloat
    let shadowXScale: CGFloat
    let stringFlexOffset: CGFloat
    let separationSpeed: CGFloat
}

struct RallyManualContactModel {
    let config: RacketContactConfig

    func phase(at progress: CGFloat) -> RallyManualContactPhase {
        let p = max(0, min(1, progress))
        let approachEnd = normalized(config.approachDuration)
        let absorbEnd = normalized(config.approachDuration + config.absorbDuration)
        let compressionEnd = normalized(config.approachDuration + config.absorbDuration + config.compressionDuration)
        let dwellEnd = normalized(config.approachDuration + config.absorbDuration + config.compressionDuration + config.dwellDuration)
        let releaseEnd = normalized(config.totalDuration - 0.0001)

        switch p {
        case ..<approachEnd: return .approach
        case ..<absorbEnd: return .absorb
        case ..<compressionEnd: return .compression
        case ..<dwellEnd: return .dwell
        case ..<releaseEnd: return .release
        default: return .separation
        }
    }

    func contactPosition(
        start: CGPoint,
        contact: CGPoint,
        direction: CGFloat,
        progress: CGFloat,
        offsetFromCenter: CGFloat
    ) -> CGPoint {
        let p = max(0, min(1, progress))
        let safeOffset = min(offsetFromCenter, config.contactOffsetClamp)
        let offCenterBias = sweetSpotScalar(for: safeOffset)
        let approachEnd = normalized(config.approachDuration)
        let dwellEnd = normalized(config.approachDuration + config.absorbDuration + config.compressionDuration + config.dwellDuration)
        let releaseStart = dwellEnd
        let releaseEnd = 1 as CGFloat

        if p < approachEnd {
            let local = easeOutCubic(p / max(0.0001, approachEnd))
            return CGPoint(
                x: lerp(start.x, contact.x, local),
                y: lerp(start.y, contact.y, local)
            )
        }

        let peakCompression = compressionScalar(at: p) * config.compressionAmount * offCenterBias
        let holdOffset = direction * peakCompression * 3.4
        let yDip = peakCompression * 2.2

        if p < releaseStart {
            return CGPoint(
                x: contact.x - holdOffset,
                y: contact.y - yDip
            )
        }

        let local = easeOutCubic((p - releaseStart) / max(0.0001, releaseEnd - releaseStart))
        let exitX = contact.x + direction * config.separationDistance * local
        let exitY = contact.y + (4 + (1 - offCenterBias) * 5) * local
        return CGPoint(
            x: lerp(contact.x - holdOffset, exitX, local),
            y: lerp(contact.y - yDip, exitY, local)
        )
    }

    func absorbScalar(at progress: CGFloat) -> CGFloat {
        guard phase(at: progress) == .absorb else { return 0 }
        let start = normalized(config.approachDuration)
        let end = normalized(config.approachDuration + config.absorbDuration)
        let local = max(0, min(1, (progress - start) / max(0.0001, end - start)))
        return easeOutCubic(local) * config.absorbBrakeAmount
    }

    func compressionScalar(at progress: CGFloat) -> CGFloat {
        switch phase(at: progress) {
        case .compression:
            let start = normalized(config.approachDuration + config.absorbDuration)
            let end = normalized(config.approachDuration + config.absorbDuration + config.compressionDuration)
            let local = max(0, min(1, (progress - start) / max(0.0001, end - start)))
            return easeOutCubic(local)
        case .dwell:
            return 1
        case .release:
            let start = normalized(config.approachDuration + config.absorbDuration + config.compressionDuration + config.dwellDuration)
            let local = max(0, min(1, (progress - start) / max(0.0001, 1 - start)))
            return 1 - easeOutCubic(local)
        default:
            return 0
        }
    }

    func releaseVelocityScalar(at progress: CGFloat) -> CGFloat {
        switch phase(at: progress) {
        case .release:
            let start = normalized(config.approachDuration + config.absorbDuration + config.compressionDuration + config.dwellDuration)
            let local = max(0, min(1, (progress - start) / max(0.0001, 1 - start)))
            return easeOutCubic(local) * config.outgoingAcceleration
        case .separation:
            return config.outgoingAcceleration
        default:
            return 0
        }
    }

    func xScale(at progress: CGFloat, offsetFromCenter: CGFloat) -> CGFloat {
        let sweet = sweetSpotScalar(for: offsetFromCenter)
        let compression = compressionScalar(at: progress) * config.compressionAmount * sweet
        let release = releaseVelocityScalar(at: progress) / max(0.0001, config.outgoingAcceleration)
        let stretched = lerp(1, config.xStretchAtRelease, release)
        if phase(at: progress) == .release || phase(at: progress) == .separation {
            return stretched
        }
        return lerp(1, config.xSquashAtPeak, compression)
    }

    func yScale(at progress: CGFloat, offsetFromCenter: CGFloat) -> CGFloat {
        let sweet = sweetSpotScalar(for: offsetFromCenter)
        let compression = compressionScalar(at: progress) * config.compressionAmount * sweet
        let release = releaseVelocityScalar(at: progress) / max(0.0001, config.outgoingAcceleration)
        let stretched = lerp(1, config.yStretchAtRelease, release)
        if phase(at: progress) == .release || phase(at: progress) == .separation {
            return stretched
        }
        return lerp(1, config.ySquashAtPeak, compression)
    }

    func stringFlexOffset(at progress: CGFloat, offsetFromCenter: CGFloat) -> CGFloat {
        sweetSpotScalar(for: offsetFromCenter) * compressionScalar(at: progress) * config.stringFlexDistance
    }

    func separationSpeed(inboundSpeed: CGFloat, progress: CGFloat, offsetFromCenter: CGFloat) -> CGFloat {
        let sweet = sweetSpotScalar(for: offsetFromCenter)
        let release = max(0, releaseVelocityScalar(at: progress))
        return inboundSpeed * max(0.62, 0.9 * sweet) * max(0.88, release)
    }

    func penetrationCorrection(
        ballCenterX: CGFloat,
        racketFaceX: CGFloat,
        ballRadius: CGFloat,
        ballMovingRight: Bool
    ) -> CGFloat {
        let desired = ballMovingRight
            ? racketFaceX - ballRadius + config.racketPenetrationTolerance
            : racketFaceX + ballRadius - config.racketPenetrationTolerance

        if ballMovingRight {
            return min(ballCenterX, desired)
        } else {
            return max(ballCenterX, desired)
        }
    }

    func frame(
        start: CGPoint,
        contact: CGPoint,
        direction: CGFloat,
        progress: CGFloat,
        inboundSpeed: CGFloat,
        offsetFromCenter: CGFloat
    ) -> RallyManualContactFrame {
        let p = max(0, min(1, progress))
        return RallyManualContactFrame(
            phase: phase(at: p),
            contactPoint: contactPosition(
                start: start,
                contact: contact,
                direction: direction,
                progress: p,
                offsetFromCenter: offsetFromCenter
            ),
            xScale: xScale(at: p, offsetFromCenter: offsetFromCenter),
            yScale: yScale(at: p, offsetFromCenter: offsetFromCenter),
            shadowAlpha: lerp(0.16, 0.34, compressionScalar(at: p)),
            shadowXScale: lerp(0.92, 1.16, compressionScalar(at: p)),
            stringFlexOffset: stringFlexOffset(at: p, offsetFromCenter: offsetFromCenter),
            separationSpeed: separationSpeed(
                inboundSpeed: inboundSpeed,
                progress: p,
                offsetFromCenter: offsetFromCenter
            )
        )
    }

    private func sweetSpotScalar(for offsetFromCenter: CGFloat) -> CGFloat {
        let clamped = min(offsetFromCenter, config.contactOffsetClamp)
        let normalized = min(1, clamped / max(1, config.sweetSpotRadius))
        return lerp(1, config.offCenterMinScalar, normalized)
    }

    private func normalized(_ elapsed: TimeInterval) -> CGFloat {
        CGFloat(elapsed / max(0.0001, config.totalDuration))
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    private func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let inverted = 1 - t
        return 1 - (inverted * inverted * inverted)
    }
}
