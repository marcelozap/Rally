import Foundation

/// Conservative summaries of sampled 2D poses. These are observations to review,
/// not a calibrated tennis technique model or medical/biomechanical assessment.
public enum CoachAnalyzer {
    // These thresholds gate tracking reliability, never athletic performance.
    public static let minimumJointConfidence = 0.4
    public static let minimumTrackedFrames = 12
    public static let minimumCoverage = 0.3
    public static let sufficientCoverage = 0.75
    public static let minimumContinuousDuration = 1.0
    public static let maximumContinuousGap = 0.35
    /// A sampling-quality gate: shoulders to feet must occupy 20% of image height.
    /// This is not a threshold for posture or tennis performance.
    public static let minimumBodyHeight = 0.2
    private static let minimumLimbLength = 0.005
    private static let timeTolerance = 0.000_001
    private static let filmingGuidance = "Film one player with a still camera in good light. Keep the whole body, including hands and feet, visible for several seconds, and move closer if the player looks small."

    public static func analyze(
        frames: [CoachPoseFrame], duration: Double,
        sampledFrameCount: Int, sourceFilename: String
    ) -> CoachReport {
        let safeDuration = duration.isFinite && duration > 0 ? duration : 0
        let safeSampleCount = max(0, max(sampledFrameCount, frames.count))
        let filename = sanitizedFilename(sourceFilename)
        guard safeDuration > 0, sampledFrameCount == frames.count, sampledFrameCount > 0 else {
            return CoachReport(
                sourceFilename: filename, duration: safeDuration,
                sampledFrameCount: safeSampleCount, trackedFrameCount: 0,
                trackedDuration: 0, longestTrackedSegmentDuration: 0,
                quality: .insufficient, metrics: [],
                notes: ["Clip timing or sample counts were incomplete. Choose the video again.", filmingGuidance]
            )
        }

        var trackedCount = 0
        var bendSamples: [CoachMetricKind: [Double]] = [:]
        var latestTimestamp: Double?
        var previousTrackedTimestamp: Double?
        var trackedDuration = 0.0
        var segmentStart = 0.0
        var segmentMinimumX = 0.0
        var segmentMaximumX = 0.0
        var segmentSampleCount = 0
        var longestSegmentDuration = 0.0
        var largestSegmentRange = 0.0
        var rangeSampleCount = 0

        for frame in frames {
            guard frame.timestamp.isFinite, frame.timestamp >= 0, frame.timestamp <= safeDuration,
                  latestTimestamp.map({ frame.timestamp > $0 }) ?? true else {
                previousTrackedTimestamp = nil
                continue
            }
            latestTimestamp = frame.timestamp
            guard let sample = validSample(frame.points) else {
                previousTrackedTimestamp = nil
                continue
            }
            trackedCount += 1
            for (kind, bend) in sample.bends {
                bendSamples[kind, default: []].append(bend)
            }

            if let previous = previousTrackedTimestamp,
               frame.timestamp - previous <= maximumContinuousGap + timeTolerance {
                trackedDuration += frame.timestamp - previous
                segmentMinimumX = min(segmentMinimumX, sample.centerX)
                segmentMaximumX = max(segmentMaximumX, sample.centerX)
                segmentSampleCount += 1
            } else {
                segmentStart = frame.timestamp
                segmentMinimumX = sample.centerX
                segmentMaximumX = sample.centerX
                segmentSampleCount = 1
            }
            let segmentDuration = frame.timestamp - segmentStart
            longestSegmentDuration = max(longestSegmentDuration, segmentDuration)
            // A brief reacquisition cannot create the displayed travel estimate.
            if segmentDuration + timeTolerance >= minimumContinuousDuration,
               segmentMaximumX - segmentMinimumX >= largestSegmentRange {
                largestSegmentRange = segmentMaximumX - segmentMinimumX
                rangeSampleCount = segmentSampleCount
            }
            previousTrackedTimestamp = frame.timestamp
        }

        let coverage = Double(trackedCount) / Double(safeSampleCount)
        let canMeasure = hasEnoughTracking(
            trackedFrameCount: trackedCount, coverage: coverage,
            longestSegmentDuration: longestSegmentDuration
        )
        let quality: CoachTrackingQuality = canMeasure
            ? (coverage >= sufficientCoverage ? .sufficient : .limited)
            : .insufficient
        var metrics: [CoachMetric] = []
        if canMeasure {
            for kind in [CoachMetricKind.leftElbowBend, .rightElbowBend, .leftKneeBend, .rightKneeBend] {
                if let values = bendSamples[kind], let lower = values.min(), let upper = values.max() {
                    metrics.append(CoachMetric(kind: kind, lowerBound: lower, upperBound: upper, sampleCount: values.count))
                }
            }
            metrics.append(CoachMetric(
                kind: .lateralCenterTravel, lowerBound: 0,
                upperBound: largestSegmentRange, sampleCount: rangeSampleCount
            ))
        }

        var notes: [String] = ["Full-body tracking was usable in \(trackedCount) of \(safeSampleCount) sampled frames."]
        if quality == .insufficient {
            notes.append("There was not enough continuous, confident full-body tracking to estimate movement. No technique assessment was made.")
            notes.append(filmingGuidance)
        } else {
            if quality == .limited {
                notes.append("Tracking was partial, so these estimates describe only the visible portions of this clip.")
            }
            notes.append("Review the original clip alongside these 2D estimates. They do not measure shot type, ball contact, racket speed, court distance, or technique quality.")
            notes.append(filmingGuidance)
        }
        return CoachReport(
            sourceFilename: filename, duration: safeDuration,
            sampledFrameCount: safeSampleCount, trackedFrameCount: trackedCount,
            trackedDuration: min(trackedDuration, safeDuration),
            longestTrackedSegmentDuration: longestSegmentDuration,
            quality: quality, metrics: metrics, notes: notes
        )
    }

    private struct Sample {
        let centerX: Double
        let bends: [CoachMetricKind: Double]
    }

    /// Shared by analysis and saved-report validation, including floating-point
    /// tolerance for exact sample boundaries such as 1.2 - 0.2 seconds.
    static func hasEnoughTracking(trackedFrameCount: Int, coverage: Double, longestSegmentDuration: Double) -> Bool {
        trackedFrameCount >= minimumTrackedFrames && coverage >= minimumCoverage
            && longestSegmentDuration + timeTolerance >= minimumContinuousDuration
    }

    private static func validSample(_ points: [CoachJoint: CoachKeypoint]) -> Sample? {
        // Nose is optional; all limbs used by the report must be observed.
        for joint in CoachJoint.allCases where joint != .nose {
            guard let point = points[joint], point.x.isFinite, point.x >= 0, (point.x * 100).isFinite,
                  point.y.isFinite, (0...1).contains(point.y),
                  point.confidence.isFinite, (minimumJointConfidence...1).contains(point.confidence) else {
                return nil
            }
        }
        guard let leftShoulder = points[.leftShoulder], let rightShoulder = points[.rightShoulder],
              let leftAnkle = points[.leftAnkle], let rightAnkle = points[.rightAnkle],
              abs((leftAnkle.y + rightAnkle.y - leftShoulder.y - rightShoulder.y) / 2) >= minimumBodyHeight else {
            return nil
        }
        guard let leftHip = points[.leftHip], let rightHip = points[.rightHip] else { return nil }
        // Halve before adding to prevent overflow on malformed input.
        let centerX = leftHip.x / 2 + rightHip.x / 2
        guard centerX.isFinite else { return nil }
        let definitions: [(CoachMetricKind, CoachJoint, CoachJoint, CoachJoint)] = [
            (.leftElbowBend, .leftShoulder, .leftElbow, .leftWrist),
            (.rightElbowBend, .rightShoulder, .rightElbow, .rightWrist),
            (.leftKneeBend, .leftHip, .leftKnee, .leftAnkle),
            (.rightKneeBend, .rightHip, .rightKnee, .rightAnkle)
        ]
        var bends: [CoachMetricKind: Double] = [:]
        for (kind, first, center, last) in definitions {
            guard let a = points[first], let b = points[center], let c = points[last],
                  let bend = bendDegrees(a, b, c) else { return nil }
            bends[kind] = bend
        }
        return Sample(centerX: centerX, bends: bends)
    }

    private static func bendDegrees(_ a: CoachKeypoint, _ b: CoachKeypoint, _ c: CoachKeypoint) -> Double? {
        let ux = a.x - b.x, uy = a.y - b.y
        let vx = c.x - b.x, vy = c.y - b.y
        let uLength = hypot(ux, uy), vLength = hypot(vx, vy)
        guard uLength.isFinite, vLength.isFinite,
              uLength >= minimumLimbLength, vLength >= minimumLimbLength else { return nil }
        // Normalizing first avoids overflow and keeps the acos argument bounded.
        let dot = (ux / uLength) * (vx / vLength) + (uy / uLength) * (vy / vLength)
        guard dot.isFinite else { return nil }
        return max(0, min(180, 180 - acos(max(-1, min(1, dot))) * 180 / .pi))
    }

    private static func sanitizedFilename(_ source: String) -> String {
        // Preserve a useful local name, never persist the selected file's full path.
        let basename = source.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last.map(String.init) ?? ""
        let printable = String(basename.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return printable.isEmpty ? "Tennis clip" : String(printable.prefix(240))
    }
}
