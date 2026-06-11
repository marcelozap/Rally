import Foundation
import CoreGraphics

struct RallyBallLiveTravelBaseline {
    let spawnTime: TimeInterval
    let arrivalTime: TimeInterval
    let travelSeconds: TimeInterval
    let spawnPoint: CGPoint
    let strikePoint: CGPoint
    let spawnScale: CGFloat
    let strikeScale: CGFloat
    let overrunScale: CGFloat
    let curveAmount: CGFloat
}

enum RallyBallOwnershipPhase: String {
    case liveTravel
    case racketExchange
    case wallExchange
    case reentry
    case normalization

    var isHittable: Bool {
        switch self {
        case .liveTravel, .reentry, .normalization:
            return true
        case .racketExchange, .wallExchange:
            return false
        }
    }

    var blocksSpawn: Bool {
        true
    }

    var blocksCull: Bool {
        switch self {
        case .reentry, .normalization, .racketExchange, .wallExchange:
            return true
        case .liveTravel:
            return false
        }
    }

    var blocksNormalPresentation: Bool {
        switch self {
        case .liveTravel:
            return false
        case .racketExchange, .wallExchange, .reentry, .normalization:
            return true
        }
    }

    var currentOwnerName: String {
        switch self {
        case .liveTravel:
            return "live-travel"
        case .racketExchange:
            return "racket-exchange"
        case .wallExchange:
            return "wall-exchange"
        case .reentry:
            return "re-entry"
        case .normalization:
            return "normalization"
        }
    }
}
