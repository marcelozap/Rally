import CoreGraphics

/// The single discriminated union every feedback system listens on.
///
/// Gameplay code only ever calls `GameEventBus.shared.publish(_:)`. It never
/// touches haptics, audio, or particles directly. This is what makes
/// retuning the "juice" cheap.
enum GameEvent {
    case sessionStart
    case sessionEnd(GameResult)

    case hit(quality: HitQuality, lane: Lane, position: CGPoint, combo: Int, power: CGFloat)
    case miss(lane: Lane)

    /// Fired only when the combo _crosses_ a tier boundary, not every hit.
    case comboTier(Int)
    case comboBreak(previous: Int)

    /// Fired when the `MatchFlowCoordinator` switches phase (warm-up →
    /// exchange, pressure → breaker, etc.). Carries both phases so
    /// listeners can light up only on escalations if they want to.
    case phaseChanged(from: MatchFlowPhase, to: MatchFlowPhase)

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
    var cleanReturnPickups: Int = 0
    var changeupWinners: Int = 0
    var pressureHolds: Int = 0

    /// First / middle / last third of the session. Each entry holds the
    /// hits and misses that occurred during that segment, in arrival-time
    /// order. Drives end-of-run narrative ("Clutch final stretch").
    /// Empty `[]` for backwards-compatible call sites.
    var segments: [SegmentStats] = []

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
        perfectHits: 0, greatHits: 0, goodHits: 0, misses: 0,
        cleanReturnPickups: 0, changeupWinners: 0, pressureHolds: 0,
        segments: []
    )
}

/// Per-third stats. Used by `GameResult.headline` and the segmented row on
/// `GameOverView` to call out where the player peaked / cratered.
struct SegmentStats: Sendable, Equatable {
    var perfectHits: Int
    var greatHits: Int
    var goodHits: Int
    var misses: Int

    var totalHits: Int { perfectHits + greatHits + goodHits }
    var attempts: Int { totalHits + misses }

    var accuracy: Double {
        attempts == 0 ? 0 : Double(totalHits) / Double(attempts)
    }

    var perfectRate: Double {
        totalHits == 0 ? 0 : Double(perfectHits) / Double(totalHits)
    }
}

extension GameResult {

    var matchStoryHighlights: [(label: String, value: Int, tint: String)] {
        [
            ("Clean returns", cleanReturnPickups, "cyan"),
            ("Change-up winners", changeupWinners, "rose"),
            ("Pressure holds", pressureHolds, "gold")
        ]
        .filter { $0.value > 0 }
    }

    /// Returns a 1-line "headline" that summarizes the *shape* of the run
    /// across thirds. Pure — exposed for unit testing.
    ///
    /// Order of precedence:
    /// 1. Strong finish after a weak start ("Slow start — strong finish")
    /// 2. Strong start that fell apart ("Hot opener — couldn't hold it")
    /// 3. Big middle slump ("Found rhythm — lost it — found it again")
    /// 4. Even high accuracy across all thirds ("Wire-to-wire")
    /// 5. Default ("Run complete")
    var narrativeHeadline: String {
        guard segments.count == 3 else { return "Run complete" }
        let first  = segments[0].accuracy
        let middle = segments[1].accuracy
        let last   = segments[2].accuracy

        let strong: Double = 0.85
        let weak:   Double = 0.55
        let bigSwing: Double = 0.18

        if last - first >= bigSwing, last >= strong {
            return "Clutch final stretch"
        }
        if first - last >= bigSwing, first >= strong {
            return "Hot opener — couldn't hold it"
        }
        if first >= strong, last >= strong, middle <= first - bigSwing {
            return "Found rhythm — lost it — found it again"
        }
        if min(first, middle, last) >= strong {
            return "Wire-to-wire"
        }
        if max(first, middle, last) <= weak {
            return "Shaky throughout — keep at it"
        }
        if last >= strong {
            return "Strong close"
        }
        if first >= strong {
            return "Quick out of the gate"
        }
        return "Run complete"
    }

    /// Optional secondary tag (1–2 lines) that color-commentates the
    /// headline. Returns `nil` if there's nothing especially noteworthy.
    var narrativeSubhead: String? {
        guard segments.count == 3 else { return nil }
        let perfects = segments.map(\.perfectHits)
        if let peakIdx = perfects.enumerated().max(by: { $0.element < $1.element })?.offset,
           perfects[peakIdx] >= 8,
           perfects[peakIdx] > perfects.reduce(0, +) / 2
        {
            switch peakIdx {
            case 0: return "Most Perfects landed in the opening third"
            case 1: return "Most Perfects landed mid-match"
            default: return "Most Perfects landed in the closer"
            }
        }
        return nil
    }
}
