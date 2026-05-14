import Foundation

/// How well a swipe lined up with a ball crossing the strike line.
///
/// Timing windows are symmetric around `t=0` (strike-line contact). See
/// `GDD.md §1.1` for the canonical table.
enum HitQuality: String, CaseIterable {
    case perfect
    case great
    case good
    case miss

    /// Half-width of the timing window, in seconds.
    var windowSeconds: Double {
        switch self {
        case .perfect: return 0.033
        case .great:   return 0.066
        case .good:    return 0.100
        case .miss:    return .infinity
        }
    }

    /// Frame-stop duration applied on this hit. Zero for non-perfect.
    var frameStopSeconds: Double {
        switch self {
        case .perfect: return 0.006
        case .great:   return 0.003
        case .good, .miss: return 0
        }
    }

    /// Score value awarded for this grade.
    var baseScore: Int {
        switch self {
        case .perfect: return 100
        case .great:   return 60
        case .good:    return 25
        case .miss:    return 0
        }
    }

    /// Grade a swipe given the signed time delta (positive = late) in seconds.
    static func grade(absDelta: Double) -> HitQuality {
        if absDelta <= HitQuality.perfect.windowSeconds { return .perfect }
        if absDelta <= HitQuality.great.windowSeconds   { return .great }
        if absDelta <= HitQuality.good.windowSeconds    { return .good }
        return .miss
    }
}
