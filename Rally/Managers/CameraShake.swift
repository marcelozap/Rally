import SpriteKit

/// Damped-sine screen shake applied to a target node (typically `SKScene`'s
/// camera). Frame-stop-aware: if the scene's `speed` is 0, shake actions
/// don't tick — they resume once gameplay does, which is exactly the
/// behavior we want for the Flappy-style "freeze + then shake" sequence.
enum CameraShake {

    /// Apply a damped shake to `target` for `durationMs` with peak offset
    /// `amplitude` in points. Existing shake actions on `.shake` key are
    /// cancelled and replaced (so back-to-back hits never accumulate).
    static func shake(_ target: SKNode, amplitude: CGFloat, durationMs: Double) {
        guard amplitude > 0, durationMs > 0 else { return }
        target.removeAction(forKey: "shake")
        let home = target.position
        let duration = durationMs.seconds
        let action = SKAction.customAction(withDuration: duration) { node, elapsed in
            let t = elapsed / CGFloat(duration)
            let decay = pow(1 - t, 2)
            let phase = CGFloat.random(in: 0..<(.pi * 2))
            let dx = sin(phase) * amplitude * decay
            let dy = cos(phase * 1.3) * amplitude * decay
            node.position = CGPoint(x: home.x + dx, y: home.y + dy)
        }
        let reset = SKAction.run { target.position = home }
        target.run(.sequence([action, reset]), withKey: "shake")
    }

    /// A more directed camera move than `shake`: quickly nudges the target
    /// toward an offset, then settles back to center. Useful for countdown
    /// release, phase rises, and reset beats where random shake would feel
    /// too noisy.
    static func nudge(_ target: SKNode, dx: CGFloat, dy: CGFloat, outMs: Double, backMs: Double) {
        guard outMs > 0, backMs > 0 else { return }
        target.removeAction(forKey: "nudge")
        let home = target.position
        let push = SKAction.move(
            to: CGPoint(x: home.x + dx, y: home.y + dy),
            duration: outMs.seconds
        )
        push.timingMode = .easeOut
        let settle = SKAction.move(to: home, duration: backMs.seconds)
        settle.timingMode = .easeInEaseOut
        target.run(.sequence([push, settle]), withKey: "nudge")
    }

    /// A short two-stage move that gives the camera a little follow-through
    /// instead of a single push-and-return. Useful for contact reactions
    /// where we want something more premium than shake, but still subtle.
    static func drift(
        _ target: SKNode,
        dx: CGFloat,
        dy: CGFloat,
        settleDx: CGFloat = 0,
        settleDy: CGFloat = 0,
        outMs: Double,
        driftMs: Double,
        backMs: Double
    ) {
        guard outMs > 0, driftMs > 0, backMs > 0 else { return }
        target.removeAction(forKey: "nudge")
        target.removeAction(forKey: "drift")
        let home = target.position

        let push = SKAction.move(
            to: CGPoint(x: home.x + dx, y: home.y + dy),
            duration: outMs.seconds
        )
        push.timingMode = .easeOut
        let drift = SKAction.move(
            to: CGPoint(x: home.x + settleDx, y: home.y + settleDy),
            duration: driftMs.seconds
        )
        drift.timingMode = .easeInEaseOut
        let settle = SKAction.move(to: home, duration: backMs.seconds)
        settle.timingMode = .easeInEaseOut
        target.run(.sequence([push, drift, settle]), withKey: "drift")
    }
}
