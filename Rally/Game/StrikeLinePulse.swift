import SpriteKit

/// A glowing band overlaying the static strike line. Owned by `GameScene`,
/// pulsed once per inbound ball — the pulse peak is timed to the ball's
/// arrival so the player gets a *visual* timing cue (not just depth-scale)
/// of when to swing.
///
/// Rendering: a thin `SKShapeNode` band laid on top of the existing strike
/// line. At rest it is invisible (alpha 0, no glow). On `schedule(in:)`,
/// it waits, then rises (alpha + glow) and falls back over
/// `Tunables.strikePulseDurationMs`.
///
/// Concurrency: every operation is on the SpriteKit main thread.
final class StrikeLinePulse: SKShapeNode {

    /// Build a pulse band sized for the scene. Caller is responsible for
    /// positioning it on the strike line.
    convenience init(width: CGFloat, color: SKColor) {
        let rect = CGRect(x: -width / 2, y: -2, width: width, height: 4)
        self.init(rect: rect)
        strokeColor = .clear
        fillColor = color
        glowWidth = 0
        alpha = 0
        zPosition = 13   // Sit just above the static strike line (z=12).
        lineWidth = 0
        blendMode = .add
    }

    /// Re-layout the band when the scene resizes. Width should match the
    /// current scene width.
    func resize(toWidth width: CGFloat) {
        let rect = CGRect(x: -width / 2, y: -2, width: width, height: 4)
        path = CGPath(rect: rect, transform: nil)
    }

    /// Schedule a pulse so its peak coincides with `arrivalTime` (in track
    /// seconds). The pulse begins `Tunables.strikePulseLeadMs` before
    /// arrival and runs for `Tunables.strikePulseDurationMs` total.
    ///
    /// If `arrivalTime - currentTrackTime <= leadMs` (ball is arriving
    /// imminently) the pulse fires immediately so the player still gets a
    /// cue, just a short one.
    func schedule(arrivalTime: Double, currentTrackTime: Double) {
        let leadSec = Tunables.live.strikePulseLeadMs.seconds
        let durSec  = Tunables.strikePulseDurationMs.seconds
        let until = arrivalTime - currentTrackTime - leadSec
        let wait = max(0, until)

        let rise = SKAction.group([
            SKAction.fadeAlpha(to: Tunables.strikePulsePeakAlpha, duration: durSec * 0.42),
            SKAction.customAction(withDuration: durSec * 0.42) { [weak self] _, t in
                let p = t / CGFloat(durSec * 0.42)
                self?.glowWidth = Tunables.strikePulseGlowWidth * p
            }
        ])
        rise.timingMode = .easeOut

        let fall = SKAction.group([
            SKAction.fadeAlpha(to: 0, duration: durSec * 0.58),
            SKAction.customAction(withDuration: durSec * 0.58) { [weak self] _, t in
                let p = 1 - t / CGFloat(durSec * 0.58)
                self?.glowWidth = Tunables.strikePulseGlowWidth * p
            }
        ])
        fall.timingMode = .easeIn

        let reset = SKAction.run { [weak self] in
            self?.alpha = 0
            self?.glowWidth = 0
        }

        // Single slot — if the previous pulse hasn't finished by the time
        // the next one is due, the new one takes over. At the default feed
        // intervals (≥ 0.92 s) and pulse duration (0.18 s) overlap is
        // rare; we still guard for the breaker phase.
        removeAction(forKey: "pulse")
        run(.sequence([.wait(forDuration: wait), rise, fall, reset]), withKey: "pulse")
    }

    /// Cancel any pending or running pulse and snap back to invisible.
    /// Called on combo-break to clear stale cues during the death freeze.
    func cancelAll() {
        removeAction(forKey: "pulse")
        alpha = 0
        glowWidth = 0
    }
}
