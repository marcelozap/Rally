import CoreGraphics
import Foundation

/// Interprets a released flick in scene coordinates, where positive y points up.
/// Values that describe strength use a 390-point viewport reference so the same
/// relative gesture feels consistent across phone sizes.
struct RallyFlickInput {
    enum Stroke: Equatable {
        case drive
        case topspin
    }

    enum Feedback: Equatable {
        case early
        case perfect
        case late
    }

    struct Result {
        let lane: Lane
        let stroke: Stroke
        let speed: CGFloat
        let lift: CGFloat
        let direction: CGFloat
    }

    private static let referenceWidth: CGFloat = 390
    private static let minimumRise: CGFloat = 20
    private static let minimumDistance: CGFloat = 28
    private static let minimumUpwardShare: CGFloat = 0.35
    private static let minimumCommitmentSpeed: CGFloat = 140
    private static let fullLiftRise: CGFloat = 140
    private static let startSideWeight: CGFloat = 0.92
    private static let centerZoneRatio: CGFloat = 0.075
    private static let topspinSlope: CGFloat = 1.35

    /// UIKit reports .began only after a pan has already moved. Its cumulative
    /// translation still includes that motion and recovers the actual touch down.
    static func panStart(location: CGPoint, translation: CGPoint) -> CGPoint {
        CGPoint(x: location.x - translation.x, y: location.y - translation.y)
    }

    static func evaluate(
        start: CGPoint,
        end: CGPoint,
        velocity: CGVector,
        duration: TimeInterval,
        viewportWidth: CGFloat
    ) -> Result? {
        guard start.x.isFinite, start.y.isFinite,
              end.x.isFinite, end.y.isFinite,
              velocity.dx.isFinite, velocity.dy.isFinite,
              duration.isFinite, duration > 0,
              viewportWidth.isFinite, viewportWidth > 0 else { return nil }

        let scale = viewportWidth / referenceWidth
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard scale > 0, dx.isFinite, dy.isFinite,
              distance.isFinite, distance > 0,
              dy >= minimumRise * scale,
              distance >= minimumDistance * scale,
              dy / distance >= minimumUpwardShare else { return nil }

        // A fast horizontal/downward release cannot supply upward commitment.
        // Average motion still recognizes a deliberate flick whose finger slows
        // just before lifting from the screen.
        let averageSpeed = distance / CGFloat(duration)
        let speed = max(max(0, velocity.dy), averageSpeed) / scale
        guard speed.isFinite, speed >= minimumCommitmentSpeed else { return nil }

        let center = viewportWidth * 0.5
        let weightedSide = start.x * startSideWeight + end.x * (1 - startSideWeight)
        let lane: Lane
        if abs(weightedSide - center) > viewportWidth * centerZoneRatio {
            lane = weightedSide < center ? .left : .right
        } else if end.x != center {
            lane = end.x < center ? .left : .right
        } else {
            // There is no ball-dependent lane assistance. An exactly centered,
            // vertical gesture always chooses right; diagonals keep their sign.
            lane = dx < 0 ? .left : .right
        }

        return Result(
            lane: lane,
            stroke: dy >= abs(dx) * topspinSlope ? .topspin : .drive,
            speed: speed,
            lift: min(1, max(0, dy / (fullLiftRise * scale))),
            direction: min(1, max(-1, dx / distance))
        )
    }

    /// Negative delta means the player released before ball contact. The exact
    /// perfect-window boundaries are inclusive, independently of flick speed.
    static func timingFeedback(signedDelta: Double, perfectWindow: Double) -> Feedback {
        guard signedDelta.isFinite, perfectWindow.isFinite, perfectWindow >= 0 else {
            return signedDelta < 0 ? .early : .late
        }
        if abs(signedDelta) <= perfectWindow { return .perfect }
        return signedDelta < 0 ? .early : .late
    }

    /// Leave equal room around each neutral target so outward and inward
    /// flicks both steer the shot before it reaches the court boundary.
    static func wallTargetX(lane: Lane, direction: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        let neutral: CGFloat = lane == .left ? 0.32 : 0.68
        let aimed = neutral + min(1, max(-1, direction)) * 0.12
        return min(0.80, max(0.20, aimed)) * viewportWidth
    }
}
