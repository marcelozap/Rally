import CoreGraphics
import Foundation

#if DEBUG
enum RallyAuditSeverity: Int, Comparable, CaseIterable {
    case info = 0
    case warning = 1
    case error = 2
    case critical = 3

    static func < (lhs: RallyAuditSeverity, rhs: RallyAuditSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
}

struct RallyAuditItem: Identifiable {
    let domain: String
    let code: String
    let name: String
    let severity: RallyAuditSeverity
    let delta: CGFloat
    let detail: String

    var identifier: String { "\(domain):\(code)" }
    var priorityScore: CGFloat { CGFloat(severity.rawValue) * 100 + abs(delta) }
    var id: String { identifier }
}

struct RallyAuditRange {
    let target: ClosedRange<CGFloat>
    let hardMin: CGFloat?
    let hardMax: CGFloat?

    func delta(for value: CGFloat) -> CGFloat {
        if value < target.lowerBound { return value - target.lowerBound }
        if value > target.upperBound { return value - target.upperBound }
        return 0
    }

    func hardCapBreach(for value: CGFloat) -> Bool {
        if let hardMin, value < hardMin { return true }
        if let hardMax, value > hardMax { return true }
        return false
    }
}

enum RallyAvatarAuditConstants {
    static let headHeightRatio = RallyAuditRange(target: 0.112 ... 0.138, hardMin: 0.098, hardMax: 0.143)
    static let legLengthRatio = RallyAuditRange(target: 0.395 ... 0.470, hardMin: 0.330, hardMax: 0.480)
    static let torsoWidthRatio = RallyAuditRange(target: 0.215 ... 0.305, hardMin: 0.190, hardMax: 0.340)
    static let shoulderToHipRatio = RallyAuditRange(target: 1.12 ... 1.34, hardMin: 1.00, hardMax: 1.42)
    static let stanceWidthRatio = RallyAuditRange(target: 0.175 ... 0.265, hardMin: 0.145, hardMax: 0.310)
    static let cameraPitchDegrees = RallyAuditRange(target: 4 ... 12, hardMin: 0, hardMax: 16)
    static let cameraDistance = RallyAuditRange(target: 0.95 ... 1.65, hardMin: 0.75, hardMax: 1.9)
    static let bodyCoverageRatio = RallyAuditRange(target: 0.54 ... 0.74, hardMin: 0.44, hardMax: 0.82)
    static let headCoverageRatio = RallyAuditRange(target: 0.12 ... 0.19, hardMin: 0.09, hardMax: 0.22)
    static let eyeWidthRatio = RallyAuditRange(target: 0.17 ... 0.23, hardMin: 0.12, hardMax: 0.26)
    static let eyeSpacingRatio = RallyAuditRange(target: 0.20 ... 0.29, hardMin: 0.16, hardMax: 0.34)
    static let browHeightRatio = RallyAuditRange(target: 0.09 ... 0.145, hardMin: 0.06, hardMax: 0.18)
    static let mouthHeightRatio = RallyAuditRange(target: -0.13 ... -0.05, hardMin: -0.18, hardMax: -0.02)
    static let glassesWidthRatio = RallyAuditRange(target: 0.40 ... 0.56, hardMin: 0.28, hardMax: 0.64)
    static let forehandTorsoTurn = RallyAuditRange(target: 0.16 ... 0.32, hardMin: 0.10, hardMax: 0.40)
    static let backhandTorsoTurn = RallyAuditRange(target: -0.52 ... -0.28, hardMin: -0.64, hardMax: -0.18)
    static let backhandSupportArmReach = RallyAuditRange(target: 0.12 ... 0.42, hardMin: 0.08, hardMax: 0.58)
    static let backhandContactOffset = RallyAuditRange(target: -1.45 ... -0.58, hardMin: -1.8, hardMax: -0.35)
    static let backhandRecoveryDuration = RallyAuditRange(target: 0.12 ... 0.28, hardMin: 0.08, hardMax: 0.36)
}

struct RallyAvatarProportionSample {
    let headHeightRatio: CGFloat
    let legLengthRatio: CGFloat
    let torsoWidthRatio: CGFloat
    let shoulderToHipRatio: CGFloat
    let stanceWidthRatio: CGFloat
}

struct RallyFaceSample {
    let eyeWidthRatio: CGFloat
    let eyeSpacingRatio: CGFloat
    let browHeightRatio: CGFloat
    let mouthHeightRatio: CGFloat
    let glassesWidthRatio: CGFloat
    let glassesVisible: Bool
}

struct RallyFramingSample {
    let cameraPitchDegrees: CGFloat
    let cameraDistance: CGFloat
    let bodyCoverageRatio: CGFloat
    let headCoverageRatio: CGFloat
    let feetVisible: Bool
    let shoulderCropRisk: Bool
    let mannequinCenterRisk: Bool
}

struct RallyBackhandSample {
    let forehandTorsoTurn: CGFloat
    let backhandTorsoTurn: CGFloat
    let backhandSupportArmReach: CGFloat
    let backhandContactOffset: CGFloat
    let recoveryDuration: CGFloat
    let mirroredSimilarityScore: CGFloat
}

enum RallyAvatarProportionAudit {
    static func audit(_ sample: RallyAvatarProportionSample) -> [RallyAuditItem] {
        [
            makeItem(domain: "proportion", id: "P01", name: "Head ratio", value: sample.headHeightRatio, range: RallyAvatarAuditConstants.headHeightRatio, tooLow: "Head too small and underpowered.", tooHigh: "Head too large and Mii-like."),
            makeItem(domain: "proportion", id: "P02", name: "Leg ratio", value: sample.legLengthRatio, range: RallyAvatarAuditConstants.legLengthRatio, tooLow: "Legs are too short and weak.", tooHigh: "Legs are too long and slenderman-like."),
            makeItem(domain: "proportion", id: "P03", name: "Torso width", value: sample.torsoWidthRatio, range: RallyAvatarAuditConstants.torsoWidthRatio, tooLow: "Torso is too narrow and flimsy.", tooHigh: "Torso is too heavy and blocky."),
            makeItem(domain: "proportion", id: "P04", name: "Shoulder-to-hip balance", value: sample.shoulderToHipRatio, range: RallyAvatarAuditConstants.shoulderToHipRatio, tooLow: "Shoulders are too weak for an athletic silhouette.", tooHigh: "Shoulders are too broad and mannequin-like."),
            makeItem(domain: "proportion", id: "P05", name: "Stance width", value: sample.stanceWidthRatio, range: RallyAvatarAuditConstants.stanceWidthRatio, tooLow: "Stance is too narrow to feel grounded.", tooHigh: "Stance is too wide and posed.")
        ].compactMap { $0 }
    }

    private static func makeItem(
        domain: String,
        id: String,
        name: String,
        value: CGFloat,
        range: RallyAuditRange,
        tooLow: String,
        tooHigh: String
    ) -> RallyAuditItem? {
        let delta = range.delta(for: value)
        guard delta != 0 || range.hardCapBreach(for: value) else { return nil }
        let severity: RallyAuditSeverity = range.hardCapBreach(for: value) ? .critical : (abs(delta) > 0.03 ? .error : .warning)
        return RallyAuditItem(
            domain: domain,
            code: id,
            name: name,
            severity: severity,
            delta: delta,
            detail: value < range.target.lowerBound ? tooLow : tooHigh
        )
    }
}

extension Array where Element == RallyAuditItem {
    mutating func appendIfNeeded(_ item: RallyAuditItem?) {
        if let item { append(item) }
    }
}
#endif
