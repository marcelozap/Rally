import CoreGraphics

/// The single discriminated union every feedback system listens on.
///
/// Gameplay code only ever calls `GameEventBus.shared.publish(_:)`. It never
/// touches haptics, audio, or particles directly. This is what makes
/// retuning the "juice" cheap.
enum GameEvent {
    case sessionStart
    case sessionEnd(finalScore: Int, maxCombo: Int)

    case hit(quality: HitQuality, lane: Lane, position: CGPoint, combo: Int)
    case miss(lane: Lane)

    /// Fired only when the combo _crosses_ a tier boundary, not every hit.
    case comboTier(Int)
    case comboBreak(previous: Int)

    case cosmeticEquipped(Cosmetic.ID)
}
