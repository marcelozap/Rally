import Foundation

public enum CoachHittingHand: String, CaseIterable, Codable, Sendable {
    case left, right
    public var title: String { rawValue.capitalized }
    var joints: (wrist: CoachJoint, shoulder: CoachJoint) {
        self == .left ? (.leftWrist, .leftShoulder) : (.rightWrist, .rightShoulder)
    }
}

/// Parameters use seconds and image-height coordinates, not pixels or metres.
/// These are provisional 10 Hz settings, not tennis-performance thresholds.
public struct CoachSmoothingSettings: Codable, Equatable, Sendable {
    public var minimumCutoffHz = 3.0
    public var speedCoefficient = 30.0
    public var derivativeCutoffHz = 1.0
    public var maximumGapSeconds = 0.25
    public init() {}

    var isValid: Bool {
        minimumCutoffHz.isFinite && minimumCutoffHz > 0
            && speedCoefficient.isFinite && speedCoefficient >= 0
            && derivativeCutoffHz.isFinite && derivativeCutoffHz > 0
            && maximumGapSeconds.isFinite && maximumGapSeconds > 0
            && maximumGapSeconds <= 0.35
    }
}

/// Independent implementation of the One Euro equations reviewed in gateKPT.
/// Unlike that adapter, invalid observations never enter filters and gaps reset
/// state. The derivative uses consecutive raw inputs, avoiding feedback of lag.
public struct CoachPoseSmoother: Sendable {
    private struct Scalar: Sendable {
        var raw: Double
        var filtered: Double
        var derivative: Double = 0

        mutating func update(_ value: Double, dt: Double, settings: CoachSmoothingSettings) -> Double? {
            let rate = (value - raw) / dt
            guard rate.isFinite else { return nil }
            let derivativeAlpha = Self.alpha(settings.derivativeCutoffHz, dt)
            let nextDerivative = derivativeAlpha * rate + (1 - derivativeAlpha) * derivative
            let cutoff = settings.minimumCutoffHz + settings.speedCoefficient * abs(nextDerivative)
            guard cutoff.isFinite else { return nil }
            let weight = Self.alpha(cutoff, dt)
            let next = weight * value + (1 - weight) * filtered
            guard next.isFinite else { return nil }
            raw = value
            derivative = nextDerivative
            filtered = next
            return next
        }

        private static func alpha(_ cutoff: Double, _ dt: Double) -> Double {
            1 / (1 + 1 / (2 * .pi * cutoff * dt))
        }
    }

    private struct JointFilter: Sendable {
        var x: Scalar
        var y: Scalar
        var timestamp: Double
    }

    public let settings: CoachSmoothingSettings
    private var filters: [CoachJoint: JointFilter] = [:]
    private var latestTimestamp: Double?

    public init(settings: CoachSmoothingSettings = CoachSmoothingSettings()) {
        self.settings = settings
    }

    public mutating func reset() {
        filters.removeAll()
        latestTimestamp = nil
    }

    public mutating func apply(_ frame: CoachPoseFrame) -> CoachPoseFrame {
        guard settings.isValid, frame.timestamp.isFinite, frame.timestamp >= 0,
              latestTimestamp.map({ frame.timestamp > $0 }) ?? true else {
            filters.removeAll()
            return CoachPoseFrame(timestamp: frame.timestamp, points: [:])
        }
        latestTimestamp = frame.timestamp
        var output: [CoachJoint: CoachKeypoint] = [:]
        for joint in CoachJoint.allCases {
            guard let point = frame.points[joint], Self.isUsable(point) else {
                filters[joint] = nil
                continue
            }
            if var filter = filters[joint], frame.timestamp - filter.timestamp <= settings.maximumGapSeconds {
                let dt = frame.timestamp - filter.timestamp
                guard let x = filter.x.update(point.x, dt: dt, settings: settings),
                      let y = filter.y.update(point.y, dt: dt, settings: settings) else {
                    filters[joint] = nil
                    continue
                }
                filter.timestamp = frame.timestamp
                filters[joint] = filter
                output[joint] = CoachKeypoint(x: x, y: y, confidence: point.confidence)
            } else {
                filters[joint] = JointFilter(
                    x: Scalar(raw: point.x, filtered: point.x),
                    y: Scalar(raw: point.y, filtered: point.y), timestamp: frame.timestamp
                )
                output[joint] = point
            }
        }
        return CoachPoseFrame(timestamp: frame.timestamp, points: output)
    }

    static func isUsable(_ point: CoachKeypoint) -> Bool {
        point.x.isFinite && point.x >= 0 && (point.x * 100).isFinite
            && point.y.isFinite && (0...1).contains(point.y)
            && point.confidence.isFinite && (CoachAnalyzer.minimumJointConfidence...1).contains(point.confidence)
    }
}

public struct CoachMotionVector: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public var magnitude: Double { hypot(x, y) }
    var isFinite: Bool { x.isFinite && y.isFinite && magnitude.isFinite }

    static func difference(_ a: Self, _ b: Self, dividedBy dt: Double) -> Self {
        Self(x: (a.x - b.x) / dt, y: (a.y - b.y) / dt)
    }
}

public enum CoachMotionStatus: String, Codable, Sendable {
    case tracked, limited, missing, lowConfidence, warmingUp
    public var title: String {
        switch self {
        case .tracked: return "Tracked arm movement"
        case .limited: return "Limited confidence"
        case .missing: return "Tracking gap"
        case .lowConfidence: return "Confidence too low"
        case .warmingUp: return "Waiting for continuous tracking"
        }
    }
    var hasVelocity: Bool { self == .tracked || self == .limited }
}

public struct CoachMotionSample: Codable, Equatable, Sendable, Identifiable {
    public let timestamp: Double
    public let intervalStart: Double
    public let segment: Int
    public let status: CoachMotionStatus
    public let confidence: Double?
    /// Wrist displacement minus shoulder displacement, per elapsed second.
    public let rawVelocity: CoachMotionVector?
    public let velocity: CoachMotionVector?
    /// Vector acceleration, per second squared; unavailable until two valid
    /// consecutive velocities (three poses) exist in the same segment.
    public let acceleration: CoachMotionVector?
    public var id: Double { timestamp }
}

public struct CoachMotionReview: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let hand: CoachHittingHand
    public let duration: Double
    public let requestedSampleRate: Double
    public let processingSeconds: Double
    public let settings: CoachSmoothingSettings
    public let samples: [CoachMotionSample]

    public var coverage: Double {
        samples.isEmpty ? 0 : Double(samples.filter { $0.velocity != nil }.count) / Double(samples.count)
    }
    public var rawPeak: Double? { samples.compactMap { $0.rawVelocity?.magnitude }.max() }
    public var filteredPeak: Double? { samples.compactMap { $0.velocity?.magnitude }.max() }

    /// Local maxima only, with observed neighbours in the same segment. These
    /// locate increased tracked movement, never ball contact or technique events.
    public var peaks: [CoachMotionSample] {
        guard samples.count >= 3 else { return [] }
        var candidates: [CoachMotionSample] = []
        for index in 1..<(samples.count - 1) {
            let before = samples[index - 1], sample = samples[index], after = samples[index + 1]
            guard before.segment == sample.segment, after.segment == sample.segment,
                  before.status == .tracked, sample.status == .tracked, after.status == .tracked,
                  let a = before.velocity?.magnitude, let b = sample.velocity?.magnitude,
                  let c = after.velocity?.magnitude, b > a, b > c else { continue }
            candidates.append(sample)
        }
        var selected: [CoachMotionSample] = []
        for sample in candidates.sorted(by: { $0.velocity!.magnitude > $1.velocity!.magnitude }) {
            if selected.allSatisfy({ abs($0.timestamp - sample.timestamp) >= 0.4 }) { selected.append(sample) }
            if selected.count == 3 { break }
        }
        return selected.sorted { $0.timestamp < $1.timestamp }
    }

    public func validate() throws {
        guard schemaVersion == 1, settings.isValid,
              duration.isFinite, (2...60).contains(duration), requestedSampleRate == 10,
              processingSeconds.isFinite, processingSeconds >= 0, samples.count <= 600 else {
            throw CoachReportValidationError.invalidReport
        }
        var previous: CoachMotionSample?
        for sample in samples {
            guard sample.timestamp.isFinite, (0...duration).contains(sample.timestamp),
                  sample.intervalStart.isFinite, (0...sample.timestamp).contains(sample.intervalStart),
                  sample.segment >= 0,
                  previous.map({ sample.timestamp > $0.timestamp && sample.segment >= $0.segment }) ?? true,
                  sample.confidence.map({ $0.isFinite && (0...1).contains($0) }) ?? true,
                  sample.rawVelocity.map(\.isFinite) ?? true, sample.velocity.map(\.isFinite) ?? true,
                  sample.acceleration.map(\.isFinite) ?? true else {
                throw CoachReportValidationError.invalidReport
            }
            if sample.status.hasVelocity {
                guard let previous, sample.segment == previous.segment,
                      sample.intervalStart == previous.timestamp,
                      sample.timestamp - sample.intervalStart <= settings.maximumGapSeconds,
                      sample.timestamp > sample.intervalStart,
                      sample.velocity != nil, sample.rawVelocity != nil,
                      let confidence = sample.confidence, confidence >= CoachAnalyzer.minimumJointConfidence,
                      sample.status == (confidence >= 0.6 ? .tracked : .limited) else {
                    throw CoachReportValidationError.invalidReport
                }
                if sample.acceleration != nil && previous.velocity == nil { throw CoachReportValidationError.invalidReport }
            } else if sample.velocity != nil || sample.rawVelocity != nil || sample.acceleration != nil {
                throw CoachReportValidationError.invalidReport
            }
            previous = sample
        }
    }
}

public enum CoachMotionAnalyzer {
    private struct Position {
        let timestamp: Double
        let raw: CoachMotionVector
        let filtered: CoachMotionVector
        let confidence: Double
    }

    public static func analyze(
        frames: [CoachPoseFrame], duration: Double, hand: CoachHittingHand,
        settings: CoachSmoothingSettings = CoachSmoothingSettings(), processingSeconds: Double = 0
    ) throws -> CoachMotionReview {
        guard settings.isValid, duration.isFinite, (2...60).contains(duration), frames.count <= 600 else {
            throw CoachReportValidationError.invalidReport
        }
        var smoother = CoachPoseSmoother(settings: settings)
        var previous: Position?
        var previousVelocity: (value: CoachMotionVector, midpoint: Double)?
        var latestTimestamp: Double?
        var segment = 0
        var samples: [CoachMotionSample] = []
        let joints = hand.joints

        for frame in frames {
            try Task.checkCancellation()
            guard frame.timestamp.isFinite, (0...duration).contains(frame.timestamp),
                  latestTimestamp.map({ frame.timestamp > $0 }) ?? true else {
                smoother.reset()
                previous = nil
                previousVelocity = nil
                segment += 1
                continue
            }
            let filtered = smoother.apply(frame)
            let intervalStart = latestTimestamp ?? frame.timestamp
            latestTimestamp = frame.timestamp
            let rawWrist = frame.points[joints.wrist], rawShoulder = frame.points[joints.shoulder]
            guard let wrist = rawWrist, let shoulder = rawShoulder,
                  CoachPoseSmoother.isUsable(wrist), CoachPoseSmoother.isUsable(shoulder),
                  let smoothWrist = filtered.points[joints.wrist], let smoothShoulder = filtered.points[joints.shoulder] else {
                previous = nil
                previousVelocity = nil
                segment += 1
                let lowConfidence = [rawWrist, rawShoulder].compactMap { $0 }.contains {
                    $0.confidence.isFinite && $0.confidence < CoachAnalyzer.minimumJointConfidence
                }
                samples.append(CoachMotionSample(
                    timestamp: frame.timestamp, intervalStart: intervalStart, segment: segment,
                    status: lowConfidence ? .lowConfidence : .missing, confidence: nil,
                    rawVelocity: nil, velocity: nil, acceleration: nil
                ))
                continue
            }
            let current = Position(
                timestamp: frame.timestamp,
                raw: CoachMotionVector(x: wrist.x - shoulder.x, y: wrist.y - shoulder.y),
                filtered: CoachMotionVector(x: smoothWrist.x - smoothShoulder.x, y: smoothWrist.y - smoothShoulder.y),
                confidence: min(wrist.confidence, shoulder.confidence)
            )
            var rawVelocity: CoachMotionVector?
            var velocity: CoachMotionVector?
            var acceleration: CoachMotionVector?
            var confidence = current.confidence
            if let previous, frame.timestamp - previous.timestamp <= settings.maximumGapSeconds {
                let dt = frame.timestamp - previous.timestamp
                let raw = CoachMotionVector.difference(current.raw, previous.raw, dividedBy: dt)
                let smooth = CoachMotionVector.difference(current.filtered, previous.filtered, dividedBy: dt)
                if raw.isFinite && smooth.isFinite {
                    rawVelocity = raw
                    velocity = smooth
                    confidence = min(confidence, previous.confidence)
                    let midpoint = previous.timestamp + dt / 2
                    if let prior = previousVelocity {
                        let value = CoachMotionVector.difference(smooth, prior.value, dividedBy: midpoint - prior.midpoint)
                        if value.isFinite { acceleration = value }
                    }
                    previousVelocity = (smooth, midpoint)
                } else {
                    previousVelocity = nil
                    segment += 1
                }
            } else {
                previousVelocity = nil
                segment += 1
            }
            samples.append(CoachMotionSample(
                timestamp: frame.timestamp, intervalStart: intervalStart, segment: segment,
                status: velocity == nil ? .warmingUp : (confidence >= 0.6 ? .tracked : .limited),
                confidence: confidence, rawVelocity: rawVelocity, velocity: velocity, acceleration: acceleration
            ))
            previous = current
        }
        try Task.checkCancellation()
        let review = CoachMotionReview(
            schemaVersion: 1, hand: hand, duration: duration, requestedSampleRate: 10,
            processingSeconds: processingSeconds, settings: settings, samples: samples
        )
        try review.validate()
        return review
    }
}
