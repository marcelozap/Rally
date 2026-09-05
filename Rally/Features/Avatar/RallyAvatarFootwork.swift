import Foundation

/// A lateral shuffle driven by the court travel of the outer SpriteKit player.
/// Anchors are in court meters; rendering converts only the returned offsets
/// into the model's axes. One foot stays planted while the other replants.
struct RallyAvatarFootwork {
    struct FootPose: Equatable {
        var offset: Float = 0
        var lift: Float = 0
        var isPlanted = true
    }

    struct Pose: Equatable {
        var left = FootPose()
        var right = FootPose()
        var pelvisOffset: Float = 0
        var pelvisDrop: Float = 0
        var isStepping: Bool { !left.isPlanted || !right.isPlanted }
    }

    private enum Foot { case left, right }
    private struct Step {
        let foot: Foot
        let start: Float
        let duration: Float
        let travelDistance: Float
        let clearance: Float
        var progress: Float = 0
        var landing: Float? = nil
    }

    private enum Tuning {
        static let substep: TimeInterval = 1 / 120
        static let resetGap: TimeInterval = 0.35
        static let teleportDistance: Float = 0.40
        static let beginTravel: Float = 0.014
        static let settleDistance: Float = 0.025
        static let travelPerStep: Float = 0.18
        static let maximumOffset: Float = 0.23
        static let minimumSpeed: Float = 0.025
        static let brakingFootSpeed: Float = 2.5
    }

    private var previousTime: TimeInterval?
    private var previousPosition: Float = 0
    private var restLeft: Float = 0
    private var restRight: Float = 0
    private var bodyScale: Float = 1
    private var leftAnchor: Float = 0
    private var rightAnchor: Float = 0
    private var velocity: Float = 0
    private var activity: Float = 0
    private var pelvisShift: Float = 0
    private var step: Step?
    private var lastDirection: Float = 0
    private var hasStepped = false
    private var lastPose = Pose()

    mutating func reset() { self = Self() }

    /// Rest positions are the ankle positions projected onto the camera's
    /// horizontal court axis, including the normal ready-stance spread.
    mutating func sample(time: TimeInterval, courtPosition: Float,
                         leftRestX: Float, rightRestX: Float, scale: Float = 1) -> Pose {
        guard time.isFinite, courtPosition.isFinite, leftRestX.isFinite,
              rightRestX.isFinite, scale.isFinite, scale > 0 else {
            reset()
            return Pose()
        }
        guard let oldTime = previousTime else {
            plant(time: time, position: courtPosition, left: leftRestX, right: rightRestX, scale: scale)
            return lastPose
        }
        let elapsed = time - oldTime
        let distance = courtPosition - previousPosition
        let sameStance = abs(leftRestX - restLeft) < 0.001 && abs(rightRestX - restRight) < 0.001 && abs(scale - bodyScale) < 0.001
        if elapsed == 0 && distance == 0 && sameStance { return lastPose }
        guard elapsed > 0, elapsed <= Tuning.resetGap,
              abs(distance) <= Tuning.teleportDistance * scale,
              sameStance else {
            plant(time: time, position: courtPosition, left: leftRestX, right: rightRestX, scale: scale)
            return lastPose
        }

        // Integrate a slow frame as short movements so it cannot skip a foot
        // landing and stretch the supporting leg beyond its natural reach.
        let count = max(1, Int(ceil(elapsed / Tuning.substep - 0.000001)))
        let dt = Float(elapsed) / Float(count)
        let delta = distance / Float(count)
        let startPosition = previousPosition
        for index in 1...count {
            advance(position: startPosition + distance * Float(index) / Float(count), delta: delta, dt: dt)
        }
        previousTime = time
        previousPosition = courtPosition
        return lastPose
    }

    private mutating func plant(time: TimeInterval, position: Float, left: Float, right: Float, scale: Float) {
        previousTime = time
        previousPosition = position
        restLeft = left
        restRight = right
        bodyScale = scale
        leftAnchor = position + left
        rightAnchor = position + right
        velocity = 0
        activity = 0
        pelvisShift = 0
        step = nil
        lastDirection = 0
        hasStepped = false
        lastPose = Pose()
    }

    private mutating func advance(position: Float, delta: Float, dt: Float) {
        let speed = delta / dt
        let moving = abs(speed) > Tuning.minimumSpeed * bodyScale
        let direction: Float = moving ? (speed > 0 ? 1 : -1) : 0
        velocity += (speed - velocity) * (1 - exp(-dt * 16))
        let energy = min(1, abs(velocity) / (0.32 * bodyScale))
        activity += (energy - activity) * (1 - exp(-dt * 22))

        if step == nil {
            let leftError = leftAnchor - position - restLeft
            let rightError = rightAnchor - position - restRight
            let mostError = max(abs(leftError), abs(rightError))
            let threshold = (moving ? Tuning.beginTravel : Tuning.settleDistance) * bodyScale
            if !moving && mostError <= threshold {
                hasStepped = false
                lastDirection = 0
            }
            if mostError > threshold {
                let nextFoot: Foot
                if moving && (!hasStepped || direction != lastDirection) {
                    // Anatomical R leads screen-right when the player faces
                    // away from the camera; this uses projected rest positions.
                    nextFoot = (restLeft - restRight) * direction > 0 ? .left : .right
                } else if moving {
                    nextFoot = leftError * direction < rightError * direction ? .left : .right
                } else {
                    nextFoot = abs(leftError) > abs(rightError) ? .left : .right
                }
                let duration = moving ? max(0.12, 0.22 - abs(velocity) * 0.04 / bodyScale) : 0.18
                let clearance = (moving ? 0.047 + min(0.015, abs(velocity) * 0.012 / bodyScale) : 0.035) * bodyScale
                let supportError = nextFoot == .left ? rightError : leftError
                // A reversal can leave the new support foot already behind the
                // body. Replant sooner instead of sliding it at the reach limit.
                let availableTravel = 0.205 * bodyScale + supportError * direction
                let travel = min(Tuning.travelPerStep * bodyScale, max(0.035 * bodyScale, availableTravel))
                step = Step(foot: nextFoot, start: anchor(nextFoot), duration: duration,
                            travelDistance: travel, clearance: clearance)
                hasStepped = true
                if moving { lastDirection = direction }
            }
        }

        var leftLift: Float = 0
        var rightLift: Float = 0
        if var active = step {
            // Time completes a step after stopping. Actual distance accelerates
            // it during a wide chase, before the planted leg runs out of reach.
            let neutral = active.foot == .left ? restLeft : restRight
            let landingSpan = abs((active.landing ?? position + neutral) - active.start)
            // Smoothstep's peak slope is 1.5. Once the body stops, give the
            // airborne shoe enough time to brake along its existing path rather
            // than finishing a long chase stride at its former running speed.
            let completionDuration = moving ? active.duration : max(active.duration, landingSpan * 1.5 / (Tuning.brakingFootSpeed * bodyScale))
            active.progress = min(1, active.progress + max(dt / completionDuration, abs(delta) / active.travelDistance))
            // Let prediction decay with velocity when travel stops; removing it
            // immediately would snap a nearly landed shoe backward by 9.5cm.
            let ahead = min(0.095 * bodyScale, max(-0.095 * bodyScale, velocity * 0.10))
            var destination = position + neutral + ahead
            let other = active.foot == .left ? rightAnchor : leftAnchor
            let otherRest = active.foot == .left ? restRight : restLeft
            let separation = abs(restLeft - restRight) * 0.60
            destination = neutral > otherRest ? max(destination, other + separation) : min(destination, other - separation)
            // Commit the last part of the swing to one court point. Continuing
            // to chase the root until touchdown would leave horizontal shoe
            // velocity just above the ground, then stop it abruptly on landing.
            if active.progress <= 0.72 || active.landing == nil { active.landing = destination }
            destination = active.landing ?? destination
            let phase = active.progress
            let ease = phase * phase * (3 - 2 * phase)
            let placement = active.start + (destination - active.start) * ease
            let lift = sin(phase * .pi) * active.clearance
            if active.foot == .left {
                leftAnchor = placement
                leftLift = phase < 1 ? lift : 0
            } else {
                rightAnchor = placement
                rightLift = phase < 1 ? lift : 0
            }
            step = phase < 1 ? active : nil
        }

        let limit = Tuning.maximumOffset * bodyScale
        // Discontinuous or extremely fast input must not produce an impossible
        // pose. Normal shuffle travel stays below this final reach guard.
        let leftOffset = min(limit, max(-limit, leftAnchor - position - restLeft))
        let rightOffset = min(limit, max(-limit, rightAnchor - position - restRight))
        let leftPlanted = step?.foot != .left
        let rightPlanted = step?.foot != .right
        let supportX: Float
        if !leftPlanted { supportX = restRight + rightOffset }
        else if !rightPlanted { supportX = restLeft + leftOffset }
        else { supportX = (leftOffset + rightOffset) * 0.5 }
        let shift = min(0.035 * bodyScale, max(-0.035 * bodyScale, supportX * 0.08 + velocity * 0.009))
        pelvisShift += (shift - pelvisShift) * (1 - exp(-dt * 18))
        lastPose = Pose(left: FootPose(offset: leftOffset, lift: leftLift, isPlanted: leftPlanted),
                        right: FootPose(offset: rightOffset, lift: rightLift, isPlanted: rightPlanted),
                        pelvisOffset: pelvisShift,
                        pelvisDrop: activity * 0.048 * bodyScale + max(leftLift, rightLift) * 0.10)
    }

    private func anchor(_ foot: Foot) -> Float { foot == .left ? leftAnchor : rightAnchor }
}
