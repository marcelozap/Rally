import Foundation
import XCTest
#if canImport(RallyCoachCore)
@testable import RallyCoachCore
#else
@testable import Rally
#endif

final class CoachAnalyzerTests: XCTestCase {
    func testClearStaticPoseReportsOnlyObservedRangesAndZeroTravel() throws {
        let report = analyze(frames())
        XCTAssertEqual(report.quality, .sufficient)
        XCTAssertEqual(report.trackedFrameCount, 20)
        XCTAssertEqual(report.coverage, 1)
        XCTAssertEqual(report.trackedDuration, 1.9, accuracy: 0.000_001)
        XCTAssertEqual(report.metrics.count, 5)
        XCTAssertEqual(metric(.leftElbowBend, in: report).lowerBound, 90, accuracy: 0.000_001)
        XCTAssertEqual(metric(.rightKneeBend, in: report).upperBound, 0, accuracy: 0.000_001)
        XCTAssertEqual(metric(.lateralCenterTravel, in: report).upperBound, 0)
        XCTAssertTrue(report.notes.contains(where: { $0.contains("do not measure shot type") }))
        try report.validate()
    }

    func testNoseIsOptionalButEveryReportedLimbMustBeConfident() throws {
        var pose = points()
        pose.removeValue(forKey: .nose)
        XCTAssertEqual(analyze(frames(points: pose)).quality, .sufficient)
        for joint in CoachJoint.allCases where joint != .nose {
            var incomplete = pose
            incomplete.removeValue(forKey: joint)
            let report = analyze(frames(points: incomplete))
            XCTAssertEqual(report.trackedFrameCount, 0, "Missing \(joint) must not be inferred")
            XCTAssertEqual(report.quality, .insufficient)
            XCTAssertTrue(report.metrics.isEmpty)
            try report.validate()
        }
    }

    func testLowConfidenceAndInvalidCoordinatesCannotCreateMetrics() throws {
        let invalidPoints = [
            CoachKeypoint(x: 0.4, y: 0.6, confidence: 0.399),
            CoachKeypoint(x: 0.4, y: 0.6, confidence: -.infinity),
            CoachKeypoint(x: 0.4, y: 0.6, confidence: .nan),
            CoachKeypoint(x: 0.4, y: 0.6, confidence: 1.1),
            CoachKeypoint(x: .nan, y: 0.6, confidence: 0.9),
            CoachKeypoint(x: .infinity, y: 0.6, confidence: 0.9),
            CoachKeypoint(x: .greatestFiniteMagnitude, y: 0.6, confidence: 0.9),
            CoachKeypoint(x: -0.1, y: 0.6, confidence: 0.9),
            CoachKeypoint(x: 0.4, y: 1.1, confidence: 0.9),
            CoachKeypoint(x: 0.4, y: .infinity, confidence: 0.9)
        ]
        for invalid in invalidPoints {
            var pose = points()
            pose[.leftKnee] = invalid
            let report = analyze(frames(points: pose))
            XCTAssertEqual(report.quality, .insufficient)
            XCTAssertEqual(report.trackedFrameCount, 0)
            XCTAssertTrue(report.metrics.isEmpty)
            try report.validate()
        }
    }

    func testZeroLengthLimbsAreRejected() throws {
        var pose = points()
        pose[.leftWrist] = pose[.leftElbow]
        let report = analyze(frames(points: pose))
        XCTAssertEqual(report.trackedFrameCount, 0)
        XCTAssertTrue(report.metrics.isEmpty)
        try report.validate()
    }

    func testTinyPlayerIsInsufficientEvenWithHighJointConfidence() throws {
        let tiny = points().mapValues { CoachKeypoint(x: $0.x / 10, y: $0.y / 10, confidence: 1) }
        let report = analyze(frames(points: tiny))
        XCTAssertEqual(report.quality, .insufficient)
        XCTAssertEqual(report.trackedFrameCount, 0)
        XCTAssertTrue(report.metrics.isEmpty)
        XCTAssertTrue(report.notes.contains(where: { $0.contains("move closer") }))
        try report.validate()
    }

    func testExactOneSecondBoundaryCanBeSavedAndDecoded() throws {
        let samples = (0..<13).map { index in
            CoachPoseFrame(timestamp: 0.2 + Double(index) / 12, points: points())
        }
        let report = analyze(samples)
        XCTAssertEqual(report.longestTrackedSegmentDuration, 1, accuracy: 0.000_001)
        XCTAssertEqual(report.quality, .sufficient)
        try report.validate()
        XCTAssertEqual(try JSONDecoder().decode(CoachReport.self, from: JSONEncoder().encode(report)), report)
    }

    func testEqualScaleCoordinatesPreserveAngleForPortraitAndLandscape() {
        // Same projected 135-degree joint angle viewed in two image aspect ratios.
        // The adapter converts normalized x back to image-height units first.
        for aspect in [9.0 / 16.0, 16.0 / 9.0] {
            var pose = points().mapValues { CoachKeypoint(x: $0.x / 2, y: $0.y, confidence: $0.confidence) }
            let normalizedTriplet = [(0.1 / aspect, 0.2), (0.1 / aspect, 0.4), (0.3 / aspect, 0.6)]
            for (joint, coordinates) in zip(
                [CoachJoint.leftShoulder, .leftElbow, .leftWrist], normalizedTriplet
            ) {
                pose[joint] = CoachKeypoint(x: coordinates.0 * aspect, y: coordinates.1, confidence: 0.9)
            }
            let report = analyze(frames(points: pose))
            XCTAssertEqual(metric(.leftElbowBend, in: report).upperBound, 45, accuracy: 0.000_001)
        }
    }

    func testBendRangeIncludesStraightAndBentObservedPoses() {
        var samples = frames()
        var straight = points()
        straight[.leftWrist] = CoachKeypoint(x: 0.3, y: 0.6, confidence: 0.9)
        samples[10] = CoachPoseFrame(timestamp: 1, points: straight)
        let report = analyze(samples)
        let elbow = metric(.leftElbowBend, in: report)
        XCTAssertEqual(elbow.lowerBound, 0, accuracy: 0.000_001)
        XCTAssertEqual(elbow.upperBound, 90, accuracy: 0.000_001)
        XCTAssertEqual(elbow.value, "0–90°")
    }

    func testStationarySegmentsSeparatedByMissingPoseDoNotInventTravel() throws {
        var samples = frames(count: 15)
        samples.append(CoachPoseFrame(timestamp: 1.5, points: [:]))
        samples += frames(count: 15, start: 1.6, offsetX: 0.5)
        let report = analyze(samples, duration: 3.1)
        XCTAssertEqual(report.trackedFrameCount, 30)
        XCTAssertEqual(report.trackedDuration, 2.8, accuracy: 0.000_001)
        XCTAssertEqual(report.longestTrackedSegmentDuration, 1.4, accuracy: 0.000_001)
        XCTAssertEqual(metric(.lateralCenterTravel, in: report).upperBound, 0)
        try report.validate()
    }

    func testLongTimestampGapDoesNotBridgeTravelEvenWithoutEmptyFrame() throws {
        let samples = frames(count: 15) + frames(count: 15, start: 5, offsetX: 0.7)
        let report = analyze(samples, duration: 6.5)
        XCTAssertEqual(report.trackedDuration, 2.8, accuracy: 0.000_001)
        XCTAssertEqual(metric(.lateralCenterTravel, in: report).upperBound, 0)
        try report.validate()
    }

    func testLateralRangeUsesLargestContinuousExcursionInsteadOfSummedJitter() {
        let samples = (0..<20).map { index in
            CoachPoseFrame(timestamp: Double(index) / 10, points: points(offsetX: index.isMultiple(of: 2) ? 0 : 0.2))
        }
        let report = analyze(samples)
        let travel = metric(.lateralCenterTravel, in: report)
        XCTAssertEqual(travel.upperBound, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(travel.value, "20% of frame height")
        XCTAssertTrue(travel.detail.contains("one uninterrupted tracked segment"))
    }

    func testBriefOutlierSegmentDoesNotBecomeReportedLateralRange() {
        var samples = frames(count: 15)
        samples.append(CoachPoseFrame(timestamp: 1.5, points: [:]))
        samples.append(CoachPoseFrame(timestamp: 1.6, points: points(offsetX: 0)))
        samples.append(CoachPoseFrame(timestamp: 1.7, points: points(offsetX: 1)))
        let report = analyze(samples)
        XCTAssertEqual(metric(.lateralCenterTravel, in: report).upperBound, 0)
    }

    func testCoverageChangesQualityAndSuppressesMetricsBelowGate() throws {
        for (sampleCount, expected) in [(20, CoachTrackingQuality.sufficient), (40, .limited), (80, .insufficient)] {
            var samples = frames()
            samples += (20..<sampleCount).map { CoachPoseFrame(timestamp: Double($0) / 10, points: [:]) }
            let report = analyze(samples, duration: Double(sampleCount) / 10)
            XCTAssertEqual(report.quality, expected)
            XCTAssertEqual(report.metrics.isEmpty, expected == .insufficient)
            try report.validate()
        }
    }

    func testIsolatedDetectionsDoNotMeetContinuousTrackingGate() throws {
        let samples = (0..<40).map { index in
            CoachPoseFrame(timestamp: Double(index) / 10, points: index.isMultiple(of: 2) ? points() : [:])
        }
        let report = analyze(samples, duration: 4)
        XCTAssertEqual(report.trackedFrameCount, 20)
        XCTAssertEqual(report.trackedDuration, 0)
        XCTAssertEqual(report.quality, .insufficient)
        XCTAssertTrue(report.metrics.isEmpty)
        try report.validate()
    }

    func testDuplicateAndOutOfOrderTimestampsCannotInflateEvidence() throws {
        var samples = frames(count: 8)
        samples += (0..<40).map { _ in CoachPoseFrame(timestamp: 0.7, points: points(offsetX: 0.8)) }
        samples.append(CoachPoseFrame(timestamp: 0.5, points: points()))
        let report = analyze(samples, duration: 5)
        XCTAssertEqual(report.trackedFrameCount, 8)
        XCTAssertEqual(report.quality, .insufficient)
        XCTAssertTrue(report.metrics.isEmpty)
        try report.validate()
    }

    func testInvalidTimestampsBreakContinuityAndAreNotTracked() throws {
        for timestamp in [Double.nan, .infinity, -1, 100] {
            var samples = frames(count: 8)
            samples.append(CoachPoseFrame(timestamp: timestamp, points: points()))
            samples += frames(count: 8, start: 0.8, offsetX: 0.5)
            let report = analyze(samples)
            XCTAssertEqual(report.trackedFrameCount, 16)
            XCTAssertEqual(report.quality, .insufficient)
            XCTAssertLessThan(report.longestTrackedSegmentDuration, 1)
            try report.validate()
        }
    }

    func testEmptyClipAndInvalidMetadataGiveUsefulInsufficientReport() throws {
        for duration in [0.0, -1, .nan, .infinity] {
            let report = CoachAnalyzer.analyze(frames: [], duration: duration, sampledFrameCount: 0, sourceFilename: "")
            XCTAssertEqual(report.duration, 0)
            XCTAssertEqual(report.sourceFilename, "Tennis clip")
            XCTAssertEqual(report.quality, .insufficient)
            XCTAssertTrue(report.metrics.isEmpty)
            XCTAssertTrue(report.notes.contains(where: { $0.contains("whole body") }))
            try report.validate()
        }
        let invalidCount = CoachAnalyzer.analyze(frames: frames(), duration: 2, sampledFrameCount: 1, sourceFilename: "rally.mov")
        XCTAssertEqual(invalidCount.quality, .insufficient)
        XCTAssertEqual(invalidCount.sampledFrameCount, 20)
        try invalidCount.validate()
        let missingSample = CoachAnalyzer.analyze(frames: frames(), duration: 2, sampledFrameCount: 21, sourceFilename: "rally.mov")
        XCTAssertEqual(missingSample.quality, .insufficient, "Missing attempts must be represented with empty poses to preserve continuity")
        try missingSample.validate()
    }

    func testFilenameDoesNotPersistSourcePathOrControls() throws {
        for source in ["/private/tmp/serve.mov", "C:\\private\\serve.mov", " /tmp/serve.mov\n"] {
            let report = CoachAnalyzer.analyze(frames: frames(), duration: 2, sampledFrameCount: 20, sourceFilename: source)
            XCTAssertEqual(report.sourceFilename, "serve.mov")
            try report.validate()
        }
    }

    // An upright full-body fixture with 90-degree elbows and straight knees.
    // Nose is intentionally absent because it is not used in any reported metric.
    private func points(offsetX: Double = 0) -> [CoachJoint: CoachKeypoint] {
        let locations: [CoachJoint: (Double, Double)] = [
            .leftShoulder: (0.3, 0.2), .rightShoulder: (0.7, 0.2),
            .leftElbow: (0.3, 0.4), .rightElbow: (0.7, 0.4),
            .leftWrist: (0.5, 0.4), .rightWrist: (0.9, 0.4),
            .leftHip: (0.3, 0.5), .rightHip: (0.7, 0.5),
            .leftKnee: (0.3, 0.7), .rightKnee: (0.7, 0.7),
            .leftAnkle: (0.3, 0.9), .rightAnkle: (0.7, 0.9)
        ]
        return locations.mapValues { CoachKeypoint(x: $0.0 + offsetX, y: $0.1, confidence: 0.9) }
    }

    private func frames(
        count: Int = 20, start: Double = 0, offsetX: Double = 0,
        points: [CoachJoint: CoachKeypoint]? = nil
    ) -> [CoachPoseFrame] {
        (0..<count).map {
            CoachPoseFrame(timestamp: start + Double($0) / 10, points: points ?? self.points(offsetX: offsetX))
        }
    }

    private func analyze(_ frames: [CoachPoseFrame], duration: Double = 2) -> CoachReport {
        CoachAnalyzer.analyze(frames: frames, duration: duration, sampledFrameCount: frames.count, sourceFilename: "rally.mov")
    }

    private func metric(_ kind: CoachMetricKind, in report: CoachReport) -> CoachMetric {
        guard let metric = report.metrics.first(where: { $0.kind == kind }) else {
            XCTFail("Missing expected metric \(kind)")
            return CoachMetric(kind: kind, lowerBound: -1, upperBound: -1, sampleCount: 0)
        }
        return metric
    }
}
