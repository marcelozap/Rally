import CoreGraphics

/// The single discriminated union every feedback system listens on.
///
/// Gameplay code only ever calls `GameEventBus.shared.publish(_:)`. It never
/// touches haptics, audio, or particles directly. This is what makes
/// retuning the "juice" cheap.
enum GameEvent {
    case sessionStart
    case sessionEnd(GameResult)

    case hit(quality: HitQuality, lane: Lane, position: CGPoint, combo: Int)
    case miss(lane: Lane)

    /// Fired only when the combo _crosses_ a tier boundary, not every hit.
    case comboTier(Int)
    case comboBreak(previous: Int)

    case cosmeticEquipped(Cosmetic.ID)
}

/// Snapshot of a completed run. Built by `GameScene` and consumed by the
/// game-over overlay + the `PlayerProgress` writer.
///
/// Keep this `Sendable` so it can be safely passed across the event bus
/// without any reference shenanigans.
struct GameResult: Sendable, Equatable {
    var finalScore: Int
    var maxCombo: Int
    var perfectHits: Int
    var greatHits: Int
    var goodHits: Int
    var misses: Int

    var totalHits: Int { perfectHits + greatHits + goodHits }

    /// Hits ÷ (hits + misses), 0…1. Returns 0 if there were no swings yet.
    var accuracy: Double {
        let denom = totalHits + misses
        return denom == 0 ? 0 : Double(totalHits) / Double(denom)
    }

    /// Fraction of all hits that were graded `.perfect`, 0…1.
    var perfectRate: Double {
        totalHits == 0 ? 0 : Double(perfectHits) / Double(totalHits)
    }

    static let empty = GameResult(
        finalScore: 0, maxCombo: 0,
        perfectHits: 0, greatHits: 0, goodHits: 0, misses: 0
    )
}
