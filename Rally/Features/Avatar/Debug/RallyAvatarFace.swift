import CoreGraphics
import Foundation

#if DEBUG
enum RallyAvatarFaceAudit {
    static func audit(_ sample: RallyFaceSample) -> [RallyAuditItem] {
        var items: [RallyAuditItem] = []
        items.appendIfNeeded(make("F01", "Eye width", value: sample.eyeWidthRatio, range: RallyAvatarAuditConstants.eyeWidthRatio, tooLow: "Eyes are too small and dead.", tooHigh: "Eyes are too large and Mii-like."))
        items.appendIfNeeded(make("F04", "Eye spacing", value: sample.eyeSpacingRatio, range: RallyAvatarAuditConstants.eyeSpacingRatio, tooLow: "Eyes are too close together.", tooHigh: "Eyes are too far apart and uncanny."))
        items.appendIfNeeded(make("F09", "Brow height", value: sample.browHeightRatio, range: RallyAvatarAuditConstants.browHeightRatio, tooLow: "Brows are too low and aggressive.", tooHigh: "Brows are too high and surprised."))
        items.appendIfNeeded(make("F12", "Mouth height", value: sample.mouthHeightRatio, range: RallyAvatarAuditConstants.mouthHeightRatio, tooLow: "Mouth sits too low and drags the face.", tooHigh: "Mouth sits too high and flattens the lower face."))
        if sample.glassesVisible {
            items.appendIfNeeded(make("F18", "Glasses width", value: sample.glassesWidthRatio, range: RallyAvatarAuditConstants.glassesWidthRatio, tooLow: "Glasses are too tiny to read intentionally.", tooHigh: "Glasses dominate the face and feel costume-like."))
        }

        if sample.eyeWidthRatio > 0.24 && sample.browHeightRatio > 0.15 && sample.glassesWidthRatio > 0.58 {
            items.append(
                RallyAuditItem(
                    domain: "face",
                    code: "F22",
                    name: "Mii head balance",
                    severity: .critical,
                    delta: max(sample.eyeWidthRatio - 0.24, sample.glassesWidthRatio - 0.58),
                    detail: "Eye/brow/glasses balance is pushing the face into Mii territory."
                )
            )
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
            domain: "face",
            code: id,
            name: name,
            severity: severity,
            delta: delta,
            detail: value < range.target.lowerBound ? tooLow : tooHigh
        )
    }
}
#endif
