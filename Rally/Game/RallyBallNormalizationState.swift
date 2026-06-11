import CoreGraphics
import Foundation

struct RallyBallNormalizationConfig {
    var settleDuration: TimeInterval
    var travelDuration: TimeInterval
    var scaleSettleRate: CGFloat
    var shadowSettleRate: CGFloat
    var readabilityLift: CGFloat
    var laneTargetingBias: CGFloat
    var trajectoryTolerance: CGFloat
    var timingNormalizationTolerance: TimeInterval
    var spawnConflictGuard: TimeInterval
    var overrunDropDistance: CGFloat
    var armedDelay: TimeInterval

    static let rallyDefault = RallyBallNormalizationConfig(
        settleDuration: 0.12,
        travelDuration: 0.26,
        scaleSettleRate: 0.96,
        shadowSettleRate: 0.92,
        readabilityLift: 6,
        laneTargetingBias: 0.10,
        trajectoryTolerance: 18,
        timingNormalizationTolerance: 0.04,
        spawnConflictGuard: 0.42,
        overrunDropDistance: 44,
        armedDelay: 0.0
    )
}

enum RallyBallNormalizationPhase: String {
    case settling
    case normalized
    case expired
}

struct RallyBallNormalizationHandoff {
    let startTime: TimeInterval
    let startPoint: CGPoint
    let strikePoint: CGPoint
    let laneDirection: CGFloat
    let xScale: CGFloat
    let yScale: CGFloat
    let shadowAlpha: CGFloat
}

struct RallyBallNormalizationFrame {
    let phase: RallyBallNormalizationPhase
    let point: CGPoint
    let xScale: CGFloat
    let yScale: CGFloat
    let shadowAlpha: CGFloat
    let armed: Bool
    let isNormalized: Bool
    let isExpired: Bool
}

struct RallyBallNormalizationState {
    let startTime: TimeInterval
    let arrivalTime: TimeInterval
    let strikeTime: TimeInterval
    let startPoint: CGPoint
    let strikePoint: CGPoint
    let laneDirection: CGFloat
    let startXScale: CGFloat
    let startYScale: CGFloat
    let startShadowAlpha: CGFloat
    let config: RallyBallNormalizationConfig

    init(
        handoff: RallyBallNormalizationHandoff,
        config: RallyBallNormalizationConfig = .rallyDefault
    ) {
        self.startTime = handoff.startTime
        self.arrivalTime = handoff.startTime + config.travelDuration
        self.strikeTime = handoff.startTime + config.travelDuration
        self.startPoint = handoff.startPoint
        self.strikePoint = handoff.strikePoint
        self.laneDirection = handoff.laneDirection
        self.startXScale = handoff.xScale
        self.startYScale = handoff.yScale
        self.startShadowAlpha = handoff.shadowAlpha
        self.config = config
    }

    var spawnTime: TimeInterval { startTime }
    var travelSeconds: TimeInterval { max(0.0001, strikeTime - startTime) }
    var normalizedSpawnTime: TimeInterval { startTime }
    var normalizedArrivalTime: TimeInterval { strikeTime }
    var spawnConflictGuardExpiry: TimeInterval { startTime + config.spawnConflictGuard }
    var expirationTime: TimeInterval { strikeTime + 0.34 }

    func makeLiveTravelBaseline(
        spawnScale: CGFloat,
        overrunScale: CGFloat
    ) -> RallyBallLiveTravelBaseline {
        RallyBallLiveTravelBaseline(
            spawnTime: normalizedSpawnTime,
            arrivalTime: normalizedArrivalTime,
            travelSeconds: travelSeconds,
            spawnPoint: startPoint,
            strikePoint: strikePoint,
            spawnScale: spawnScale,
            strikeScale: 1.0,
            overrunScale: overrunScale,
            curveAmount: 0
        )
    }

    func frame(at trackTime: TimeInterval) -> RallyBallNormalizationFrame {
        let settleProgress = CGFloat(max(0, min(1, (trackTime - startTime) / max(0.0001, config.settleDuration))))
        let travelProgressRaw = CGFloat(max(0, (trackTime - startTime) / travelSeconds))
        let travelProgress = min(1, travelProgressRaw)
        let overrun = max(0, travelProgressRaw - 1)

        let point = normalizedPoint(progress: travelProgress, overrun: overrun)
        let xScale = settle(start: startXScale, end: 1.0, progress: settleProgress, rate: config.scaleSettleRate)
        let yScale = settle(start: startYScale, end: 1.0, progress: settleProgress, rate: config.scaleSettleRate)
        let shadowAlpha = settle(
            start: startShadowAlpha,
            end: Tunables.bounceShadowAlpha,
            progress: settleProgress,
            rate: config.shadowSettleRate
        )

        let armed = trackTime >= startTime + config.armedDelay
        let isNormalized = trackTime >= startTime + config.settleDuration
        let isExpired = trackTime >= expirationTime
        let phase: RallyBallNormalizationPhase
        if isExpired {
            phase = .expired
        } else if isNormalized {
            phase = .normalized
        } else {
            phase = .settling
        }

        return RallyBallNormalizationFrame(
            phase: phase,
            point: point,
            xScale: xScale,
            yScale: yScale,
            shadowAlpha: shadowAlpha,
            armed: armed,
            isNormalized: isNormalized,
            isExpired: isExpired
        )
    }

    private func normalizedPoint(progress: CGFloat, overrun: CGFloat) -> CGPoint {
        let eased = easeInOutCubic(progress)
        let verticalMidpoint = (startPoint.y + strikePoint.y) * 0.5
        let midpoint = CGPoint(
            x: (startPoint.x + strikePoint.x) * 0.5 + (strikePoint.x - startPoint.x) * config.laneTargetingBias,
            y: verticalMidpoint + config.readabilityLift
        )
        let base = quadratic(start: startPoint, control: midpoint, end: strikePoint, t: eased)
        let drop = overrun * overrun * config.overrunDropDistance
        let laneDrift = overrun * 16 * laneDirection
        return CGPoint(x: base.x + laneDrift, y: base.y - drop)
    }

    private func settle(start: CGFloat, end: CGFloat, progress: CGFloat, rate: CGFloat) -> CGFloat {
        let eased = 1 - pow(max(0, 1 - progress), max(0.001, rate))
        return start + (end - start) * eased
    }

    private func quadratic(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let inverse = 1 - t
        return CGPoint(
            x: inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x,
            y: inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y
        )
    }

    private func easeInOutCubic(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 4 * t * t * t
        }
        let f = (2 * t) - 2
        return 0.5 * f * f * f + 1
    }
}
