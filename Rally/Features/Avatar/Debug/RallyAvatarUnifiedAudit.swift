import CoreGraphics
import Foundation

#if DEBUG
struct RallyAvatarUnifiedAuditConfig {
    let context: String
    let proportions: RallyAvatarProportionSample
    let face: RallyFaceSample
    let framing: RallyFramingSample
    let backhand: RallyBackhandSample?
}

struct RallyAvatarUnifiedAuditResult {
    let items: [RallyAuditItem]

    var worstFirst: [RallyAuditItem] {
        items.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            return abs($0.delta) > abs($1.delta)
        }
    }

    var isShippable: Bool {
        !items.contains { $0.severity >= .error }
    }
}

enum RallyAvatarUnifiedAudit {
    static func run(_ config: RallyAvatarUnifiedAuditConfig) -> RallyAvatarUnifiedAuditResult {
        var items = RallyAvatarProportionAudit.audit(config.proportions)
        items.append(contentsOf: RallyAvatarFaceAudit.audit(config.face))
        items.append(contentsOf: RallyAvatarFramingAudit.audit(config.framing))
        if let backhand = config.backhand {
            items.append(contentsOf: RallyBackhandValidator.audit(backhand))
        }
        return RallyAvatarUnifiedAuditResult(items: items)
    }

    static func log(_ result: RallyAvatarUnifiedAuditResult, context: String) {
        guard !result.items.isEmpty else {
            print("RALLY_AUDIT[\(context)] PASS")
            return
        }

        let grouped = Dictionary(grouping: result.worstFirst, by: \.domain)
        print("RALLY_AUDIT[\(context)] FAIL count=\(result.items.count) shippable=\(result.isShippable)")
        for domain in grouped.keys.sorted() {
            print("  [\(domain.uppercased())]")
            for item in grouped[domain, default: []] {
                print("    \(item.severity.label) \(item.code) \(item.name) delta=\(format(item.delta)) :: \(item.detail)")
            }
        }
        let top = result.worstFirst.prefix(3)
        if !top.isEmpty {
            print("  Patch priority:")
            for item in top {
                let direction = item.delta > 0 ? "decrease" : "increase"
                print("    - \(item.name): \(direction) by \(format(abs(item.delta)))")
            }
        }
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.3f", value)
    }
}

enum RallyAvatarFramingAudit {
    static func audit(_ sample: RallyFramingSample) -> [RallyAuditItem] {
        var items: [RallyAuditItem] = []
        items.appendIfNeeded(make("C01", "Camera pitch", value: sample.cameraPitchDegrees, range: RallyAvatarAuditConstants.cameraPitchDegrees, tooLow: "Camera is too flat and dead.", tooHigh: "Camera is pitching too hard and amplifying uncanny proportions."))
        items.appendIfNeeded(make("C02", "Camera distance", value: sample.cameraDistance, range: RallyAvatarAuditConstants.cameraDistance, tooLow: "Camera is too close and head-dominant.", tooHigh: "Camera is too far and making the stage empty."))
        items.appendIfNeeded(make("C03", "Body coverage", value: sample.bodyCoverageRatio, range: RallyAvatarAuditConstants.bodyCoverageRatio, tooLow: "Body is too small in frame.", tooHigh: "Body is too oversized and cramped in frame."))
        items.appendIfNeeded(make("C04", "Head coverage", value: sample.headCoverageRatio, range: RallyAvatarAuditConstants.headCoverageRatio, tooLow: "Head is too tiny to read.", tooHigh: "Head is dominating the frame."))
        if !sample.feetVisible {
            items.append(RallyAuditItem(domain: "framing", code: "C05", name: "Floating legs risk", severity: .critical, delta: 1, detail: "Feet are not safely visible in frame."))
        }
        if sample.shoulderCropRisk {
            items.append(RallyAuditItem(domain: "framing", code: "C06", name: "Shoulder crop risk", severity: .error, delta: 1, detail: "Shoulders are too close to the crop boundary."))
        }
        if sample.mannequinCenterRisk {
            items.append(RallyAuditItem(domain: "framing", code: "C07", name: "Mannequin-center risk", severity: .warning, delta: 1, detail: "Avatar is too symmetrically centered and shrine-like."))
        }
        return items
    }

    private static func make(
        _ id: String,
        _ name: String,
        value: CGFloat,
        range: RallyAuditRange,
        tooLow: String,
        tooHigh: String
    ) -> RallyAuditItem? {
        let delta = range.delta(for: value)
        guard delta != 0 || range.hardCapBreach(for: value) else { return nil }
        let severity: RallyAuditSeverity = range.hardCapBreach(for: value) ? .error : .warning
        return RallyAuditItem(
            domain: "framing",
            code: id,
            name: name,
            severity: severity,
            delta: delta,
            detail: value < range.target.lowerBound ? tooLow : tooHigh
        )
    }
}
#endif
