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
}
