import CoreGraphics
import Foundation

#if DEBUG
enum RallyBackhandValidator {
    static func audit(_ sample: RallyBackhandSample) -> [RallyAuditItem] {
        var items: [RallyAuditItem] = []
        items.appendIfNeeded(make("B01", "Forehand torso turn", value: sample.forehandTorsoTurn, range: RallyAvatarAuditConstants.forehandTorsoTurn, tooLow: "Forehand torso turn is too flat.", tooHigh: "Forehand torso turn is overcooked."))
        items.appendIfNeeded(make("B02", "Backhand torso turn", value: sample.backhandTorsoTurn, range: RallyAvatarAuditConstants.backhandTorsoTurn, tooLow: "Backhand torso turn is not closed enough.", tooHigh: "Backhand torso turn is too cranked and awkward."))
        items.appendIfNeeded(make("B03", "Support arm reach", value: sample.backhandSupportArmReach, range: RallyAvatarAuditConstants.backhandSupportArmReach, tooLow: "Support arm is missing from the two-handed backhand.", tooHigh: "Support arm is exaggerated and puppet-like."))
        items.appendIfNeeded(make("B04", "Backhand contact side", value: sample.backhandContactOffset, range: RallyAvatarAuditConstants.backhandContactOffset, tooLow: "Backhand contact is too far across the body.", tooHigh: "Backhand contact is too centered and reads like a mirrored forehand."))
        items.appendIfNeeded(make("B05", "Recovery duration", value: sample.recoveryDuration, range: RallyAvatarAuditConstants.backhandRecoveryDuration, tooLow: "Backhand recovery snaps too hard and feels robotic.", tooHigh: "Backhand recovery hangs too long and feels stiff."))

        if sample.mirroredSimilarityScore > 0.72 {
            items.append(
                RallyAuditItem(
                    domain: "backhand",
                    code: "B06",
                    name: "Mirrored forehand risk",
                    severity: sample.mirroredSimilarityScore > 0.84 ? .critical : .error,
                    delta: sample.mirroredSimilarityScore - 0.72,
                    detail: "Backhand still reads too much like a mirrored forehand."
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
            domain: "backhand",
            code: id,
            name: name,
            severity: severity,
            delta: delta,
            detail: value < range.target.lowerBound ? tooLow : tooHigh
        )
    }
}
#endif
