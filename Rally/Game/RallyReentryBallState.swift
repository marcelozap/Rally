import CoreGraphics
import Foundation

struct RallyReentryConfig {
    var returnTravelDuration: TimeInterval
    var contactRearmDelay: TimeInterval
    var normalizationHandoffProgress: CGFloat
    var readabilityBias: CGFloat
    var laneTargetingBias: CGFloat
    var endXScale: CGFloat
    var endYScale: CGFloat
    var endShadowAlpha: CGFloat
    var gravityDrop: CGFloat
    var apexLift: CGFloat

    static let rallyDefault = RallyReentryConfig(
        returnTravelDuration: Tunables.wallReturnTravelSeconds,
        contactRearmDelay: 0.045,
        normalizationHandoffProgress: 0.70,
        readabilityBias: 0.08,
        laneTargetingBias: 0.20,
        endXScale: 1.0,
        endYScale: 1.0,
        endShadowAlpha: Tunables.bounceShadowAlpha,
        gravityDrop: 10,
        apexLift: 8
    )
}

struct RallyReentryBallFrame {
    let point: CGPoint
    let xScale: CGFloat
    let yScale: CGFloat
    let shadowAlpha: CGFloat
    /// Normalized instantaneous return speed, 0…1 (1 = terminal speed at the
    /// player). Drives trail emphasis so the acceleration is readable.
    let speedScalar: CGFloat
    let armed: Bool
    let handoffReady: Bool
    let isComplete: Bool
}

struct RallyReentryBallState {
    let startTime: Double
    let arrivalTime: Double
    let strikeTime: Double
    let startPoint: CGPoint
    let strikePoint: CGPoint
    let config: RallyReentryConfig
    let handoffXScale: CGFloat
    let handoffYScale: CGFloat
    let handoffShadowAlpha: CGFloat

    var spawnTime: Double { startTime }
    var travelSeconds: Double { max(0.0001, arrivalTime - startTime) }
    var rearmTime: Double { min(arrivalTime - 0.01, startTime + contactRearmDelayClamped) }

    private var contactRearmDelayClamped: Double {
        min(config.contactRearmDelay, max(0.02, travelSeconds * 0.72))
    }

    func frame(at trackTime: Double) -> RallyReentryBallFrame {
        let raw = CGFloat(max(0, min(1.16, (trackTime - startTime) / travelSeconds)))
        let progress = min(1, raw)
        let overrun = max(0, raw - 1)

        let curveProgress = acceleratedReturnProgress(progress)
        let verticalMidpoint = (startPoint.y + strikePoint.y) * 0.5
        let midpoint = CGPoint(
            x: (startPoint.x + strikePoint.x) * 0.5 + (strikePoint.x - startPoint.x) * config.laneTargetingBias,
            y: verticalMidpoint + abs(strikePoint.x - startPoint.x) * config.readabilityBias + config.apexLift
        )
        let point = quadratic(start: startPoint, control: midpoint, end: strikePoint, t: curveProgress)
        let gravitySag = progress * progress * config.gravityDrop
        let flightLift = sin(progress * .pi) * config.apexLift * 0.42
        let xScale = lerp(handoffXScale, config.endXScale, curveProgress)
        let yScale = lerp(handoffYScale, config.endYScale, curveProgress)
        let shadowAlpha = lerp(handoffShadowAlpha, config.endShadowAlpha, curveProgress)
        let armed = trackTime >= rearmTime
        let handoffReady = raw >= config.normalizationHandoffProgress && armed

        return RallyReentryBallFrame(
            point: CGPoint(x: point.x, y: point.y + flightLift - gravitySag - overrun * overrun * 12),
            xScale: xScale,
            yScale: yScale,
            shadowAlpha: shadowAlpha,
            speedScalar: returnSpeedScalar(progress),
            armed: armed,
            handoffReady: handoffReady,
            isComplete: raw >= 1.12
        )
    }

    /// Instantaneous velocity of the accelerated return profile, normalized
    /// to terminal speed. v(t) = exit + 2·gain·t for the quadratic travel curve.
    private func returnSpeedScalar(_ t: CGFloat) -> CGFloat {
        let exit = Tunables.wallReturnExitSpeedScalar
        let gain = Tunables.wallReturnAccelerationGain
        let velocity = exit + 2 * gain * max(0, min(1, t))
        return max(0, min(1, velocity / max(0.0001, exit + 2 * gain)))
    }

    private func quadratic(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let inverse = 1 - t
        return CGPoint(
            x: inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x,
            y: inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y
        )
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func easeInOutCubic(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 4 * t * t * t
        }
        let f = (2 * t) - 2
        return 0.5 * f * f * f + 1
    }

    private func acceleratedReturnProgress(_ t: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, t))
        let exit = Tunables.wallReturnExitSpeedScalar
        let gain = Tunables.wallReturnAccelerationGain
        let travel = exit * clamped + gain * clamped * clamped
        return max(0, min(1, travel / (exit + gain)))
    }
}
