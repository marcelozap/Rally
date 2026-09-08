import Foundation

public enum CoachJoint: String, CaseIterable, Codable, Sendable {
    case nose
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
}

/// Image-plane coordinates with a top-left origin and equal scale on both axes.
/// For an oriented image: x = normalizedX * width / height; y = 1 - normalizedY.
/// Distances are therefore fractions of image height, never metres or court distance.
public struct CoachKeypoint: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let confidence: Double

    public init(x: Double, y: Double, confidence: Double) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

public struct CoachPoseFrame: Sendable {
    public let timestamp: Double
    public let points: [CoachJoint: CoachKeypoint]

    /// Include an empty points dictionary for each failed or ambiguous sample.
    /// Removing those samples could incorrectly bridge a break in tracking.
    public init(timestamp: Double, points: [CoachJoint: CoachKeypoint]) {
        self.timestamp = timestamp
        self.points = points
    }
}

public enum CoachTrackingQuality: String, Codable, Sendable {
    case sufficient, limited, insufficient

    public var title: String {
        switch self {
        case .sufficient: return "Clear tracking"
        case .limited: return "Partial tracking"
        case .insufficient: return "Not enough tracking"
        }
    }
}

public enum CoachMetricKind: String, CaseIterable, Codable, Sendable {
    case leftElbowBend, rightElbowBend, leftKneeBend, rightKneeBend, lateralCenterTravel

    public var title: String {
        switch self {
        case .leftElbowBend: return "Left elbow bend"
        case .rightElbowBend: return "Right elbow bend"
        case .leftKneeBend: return "Left knee bend"
        case .rightKneeBend: return "Right knee bend"
        case .lateralCenterTravel: return "Sideways hip-center range"
        }
    }
}

public struct CoachMetric: Identifiable, Codable, Sendable, Equatable {
    public let kind: CoachMetricKind
    /// Angles use degrees of bend (0 = straight). Travel uses fractions of image height.
    public let lowerBound: Double
    public let upperBound: Double
    public let sampleCount: Int

    public var id: String { kind.rawValue }
    public var title: String { kind.title }
    public var value: String {
        if kind == .lateralCenterTravel {
            return "\(Self.wholeNumber(upperBound * 100))% of frame height"
        }
        return "\(Self.wholeNumber(lowerBound))–\(Self.wholeNumber(upperBound))°"
    }
    public var detail: String {
        if kind == .lateralCenterTravel {
            return "Estimated horizontal range of the hip midpoint within one uninterrupted tracked segment. Camera movement and depth affect this image-plane estimate."
        }
        return "Estimated 2D bend across \(sampleCount) tracked samples; 0° is straight. Camera angle, clothing, and pose estimation affect the range."
    }

    public init(kind: CoachMetricKind, lowerBound: Double, upperBound: Double, sampleCount: Int) {
        self.kind = kind
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.sampleCount = sampleCount
    }

    private static func wholeNumber(_ value: Double) -> String {
        // Avoid a potentially trapping Double-to-Int conversion on unvalidated values.
        guard value.isFinite else { return "—" }
        return String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

public enum CoachReportValidationError: Error, LocalizedError {
    case invalidReport

    public var errorDescription: String? {
        "This saved coaching report could not be read. Analyze the original clip again."
    }
}

public struct CoachReport: Identifiable, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    public let createdAt: Date
    public let sourceFilename: String
    public let duration: Double
    public let sampledFrameCount: Int
    public let trackedFrameCount: Int
    /// Sum of consecutive, valid tracked intervals; never includes tracking gaps.
    public let trackedDuration: Double
    public let longestTrackedSegmentDuration: Double
    public let quality: CoachTrackingQuality
    public let metrics: [CoachMetric]
    public let notes: [String]
    public let motionReview: CoachMotionReview?

    public var coverage: Double {
        guard sampledFrameCount > 0 else { return 0 }
        return Double(trackedFrameCount) / Double(sampledFrameCount)
    }

    init(
        id: UUID = UUID(), createdAt: Date = Date(), sourceFilename: String,
        duration: Double, sampledFrameCount: Int, trackedFrameCount: Int,
        trackedDuration: Double, longestTrackedSegmentDuration: Double,
        quality: CoachTrackingQuality, metrics: [CoachMetric], notes: [String],
        motionReview: CoachMotionReview? = nil
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.createdAt = createdAt
        self.sourceFilename = sourceFilename
        self.duration = duration
        self.sampledFrameCount = sampledFrameCount
        self.trackedFrameCount = trackedFrameCount
        self.trackedDuration = trackedDuration
        self.longestTrackedSegmentDuration = longestTrackedSegmentDuration
        self.quality = quality
        self.metrics = metrics
        self.notes = notes
        self.motionReview = motionReview
    }

    /// Validate before saving. Decoding also validates, so corrupt/future reports
    /// cannot silently become a plausible result in history.
    public func validate() throws {
        if let motionReview {
            try motionReview.validate()
            guard motionReview.duration == duration else { throw CoachReportValidationError.invalidReport }
        }
        let tolerance = 0.000_001
        guard schemaVersion == Self.currentSchemaVersion,
              createdAt.timeIntervalSince1970.isFinite,
              !sourceFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              sourceFilename.count <= 240,
              !sourceFilename.contains("/"), !sourceFilename.contains("\\"),
              !sourceFilename.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              duration.isFinite, duration >= 0,
              sampledFrameCount >= 0,
              trackedFrameCount >= 0, trackedFrameCount <= sampledFrameCount,
              trackedDuration.isFinite, trackedDuration >= 0, trackedDuration <= duration + tolerance,
              longestTrackedSegmentDuration.isFinite, longestTrackedSegmentDuration >= 0,
              longestTrackedSegmentDuration <= trackedDuration + tolerance,
              notes.count <= 10, !notes.isEmpty,
              notes.allSatisfy({ !$0.isEmpty && $0.count <= 2_000 }),
              metrics.count <= CoachMetricKind.allCases.count,
              Set(metrics.map(\.kind)).count == metrics.count else {
            throw CoachReportValidationError.invalidReport
        }

        let canMeasure = CoachAnalyzer.hasEnoughTracking(
            trackedFrameCount: trackedFrameCount, coverage: coverage,
            longestSegmentDuration: longestTrackedSegmentDuration
        )
        let expectedQuality: CoachTrackingQuality = canMeasure
            ? (coverage >= CoachAnalyzer.sufficientCoverage ? .sufficient : .limited)
            : .insufficient
        guard quality == expectedQuality,
              quality == .insufficient ? metrics.isEmpty : metrics.count == CoachMetricKind.allCases.count else {
            throw CoachReportValidationError.invalidReport
        }

        for metric in metrics {
            guard metric.lowerBound.isFinite, metric.upperBound.isFinite,
                  metric.lowerBound >= 0, metric.upperBound >= metric.lowerBound,
                  metric.sampleCount >= 2, metric.sampleCount <= trackedFrameCount else {
                throw CoachReportValidationError.invalidReport
            }
            if metric.kind == .lateralCenterTravel {
                guard metric.lowerBound == 0, (metric.upperBound * 100).isFinite else {
                    throw CoachReportValidationError.invalidReport
                }
            } else {
                guard metric.upperBound <= 180, metric.sampleCount == trackedFrameCount else {
                    throw CoachReportValidationError.invalidReport
                }
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, createdAt, sourceFilename, duration
        case sampledFrameCount, trackedFrameCount, trackedDuration, longestTrackedSegmentDuration
        case quality, metrics, notes, motionReview
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        id = try values.decode(UUID.self, forKey: .id)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        sourceFilename = try values.decode(String.self, forKey: .sourceFilename)
        duration = try values.decode(Double.self, forKey: .duration)
        sampledFrameCount = try values.decode(Int.self, forKey: .sampledFrameCount)
        trackedFrameCount = try values.decode(Int.self, forKey: .trackedFrameCount)
        trackedDuration = try values.decode(Double.self, forKey: .trackedDuration)
        longestTrackedSegmentDuration = try values.decode(Double.self, forKey: .longestTrackedSegmentDuration)
        quality = try values.decode(CoachTrackingQuality.self, forKey: .quality)
        metrics = try values.decode([CoachMetric].self, forKey: .metrics)
        notes = try values.decode([String].self, forKey: .notes)
        motionReview = try values.decodeIfPresent(CoachMotionReview.self, forKey: .motionReview)
        try validate()
    }
}
