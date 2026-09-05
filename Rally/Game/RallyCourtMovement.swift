import CoreGraphics
import Foundation

/// Court travel is driven by the incoming ball's fixed landing point, never
/// by its current position or by a contact point attached to the moving player.
enum RallyCourtMovement {
    static func returnContactX(lane: Lane, reach: CGFloat, width: CGFloat) -> CGFloat {
        let stance = width * (lane == .left ? 0.32 : 0.68)
        return min(width * 0.92, max(width * 0.08, stance + reach))
    }

    static func stanceX(contactX: CGFloat, reach: CGFloat, width: CGFloat) -> CGFloat {
        min(width * 0.76, max(width * 0.24, contactX - reach))
    }

    static func advance(from position: CGFloat, toward target: CGFloat,
                        deltaTime: TimeInterval, pointsPerMeter: CGFloat,
                        planted: Bool) -> CGFloat {
        guard !planted, position.isFinite, target.isFinite,
              deltaTime.isFinite, deltaTime > 0, pointsPerMeter > 0 else { return position }
        // Ignore a long pause's elapsed time instead of teleporting on resume.
        let dt = min(deltaTime, 1.0 / 15.0)
        let distance = target - position
        if abs(distance) < 0.25 { return target }
        let eased = distance * CGFloat(1 - exp(-dt * 10))
        let maximumStep = pointsPerMeter * 1.35 * CGFloat(dt)
        return position + min(maximumStep, max(-maximumStep, eased))
    }

    /// Distribute the remaining distance over the time until contact. A feasible
    /// approach arrives on time; a late or unreachable target keeps the same
    /// travel-speed limit rather than snapping the player across the court.
    static func arrive(from position: CGFloat, toward target: CGFloat,
                       deltaTime: TimeInterval, secondsRemaining: TimeInterval,
                       pointsPerMeter: CGFloat) -> CGFloat {
        guard position.isFinite, target.isFinite, deltaTime.isFinite, deltaTime > 0,
              secondsRemaining.isFinite, pointsPerMeter.isFinite, pointsPerMeter > 0 else { return position }
        let dt = min(deltaTime, 1.0 / 15.0)
        let distance = target - position
        let guidedStep = distance * CGFloat(dt / max(dt, secondsRemaining))
        let maximumStep = pointsPerMeter * 1.35 * CGFloat(dt)
        return position + min(maximumStep, max(-maximumStep, guidedStep))
    }
}
