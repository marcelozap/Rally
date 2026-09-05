import Foundation

/// Shared timing boundaries for the short rally against the player's double.
enum RallyMirrorRules {
    static let durationSeconds: Double = 20

    /// Half an exchange; retain one pulse throughout each four-shot phrase.
    static func beatSeconds(forCombo combo: Int) -> Double {
        if combo < 4 { return 0.76 }
        if combo < 8 { return 0.70 }
        return 0.64
    }

    static func remainingSeconds(at elapsed: Double) -> Double {
        guard elapsed.isFinite else { return 0 }
        return min(durationSeconds, max(0, durationSeconds - elapsed))
    }

    static func hasFinished(at elapsed: Double) -> Bool {
        !elapsed.isFinite || elapsed >= durationSeconds
    }

    /// An incoming ball needs a contact moment before the run ends.
    static func canStartIncoming(at elapsed: Double, travelSeconds: Double) -> Bool {
        guard elapsed.isFinite, travelSeconds.isFinite, elapsed >= 0, travelSeconds >= 0 else { return false }
        return elapsed + travelSeconds < durationSeconds
    }

    /// Contact expires by its scheduled arrival, independently of rendered ball height.
    static func hasMissedContact(at elapsed: Double, arrivalTime: Double) -> Bool {
        guard elapsed.isFinite, arrivalTime.isFinite else { return false }
        return elapsed > arrivalTime + 0.34
    }
}
