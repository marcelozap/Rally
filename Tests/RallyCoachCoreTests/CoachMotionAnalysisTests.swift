import Foundation
import XCTest
#if canImport(RallyCoachCore)
@testable import RallyCoachCore
#else
@testable import Rally
#endif

final class CoachMotionAnalysisTests: XCTestCase {
    func testStationaryJitterIsReducedWithoutInventingStillness() throws {
        let frames = (0..<50).map { pose(Double($0) / 10, wristX: 0.5 + ($0.isMultiple(of: 2) ? 0.004 : -0.004)) }
        let result = try analyze(frames, duration: 5)
        let raw = result.samples.dropFirst(5).compactMap { $0.rawVelocity?.magnitude }
        let filtered = result.samples.dropFirst(5).compactMap { $0.velocity?.magnitude }
        let ratio = filtered.reduce(0, +) / raw.reduce(0, +)
        print("Coach 10 Hz stationary jitter speed ratio: \(ratio)")
        XCTAssertLessThan(ratio, 0.55)
        XCTAssertTrue(filtered.allSatisfy { $0 > 0 })
    }

    func testFastDirectionChangeRetainsMostOfTrackedPeak() throws {
        let frames = (0..<30).map { index in
            pose(Double(index) / 10, wristX: index == 15 ? 0.9 : 0.5)
        }
        let result = try analyze(frames, duration: 3)
        let ratio = try XCTUnwrap(result.filteredPeak) / XCTUnwrap(result.rawPeak)
        print("Coach 10 Hz fast reversal peak retention: \(ratio)")
        XCTAssertGreaterThan(ratio, 0.75)
        XCTAssertLessThanOrEqual(ratio, 1.01)
        XCTAssertGreaterThan(try XCTUnwrap(result.samples[15].velocity).x, 0)
        XCTAssertLessThan(try XCTUnwrap(result.samples[16].velocity).x, 0)
        XCTAssertLessThanOrEqual(abs(try XCTUnwrap(result.peaks.first).timestamp - 1.5), 0.1)
    }

    func testConstantRelativeVelocityConvergesInClearUnits() throws {
        let frames = (0..<30).map { pose(Double($0) / 10, wristX: 0.4 + Double($0) * 0.01) }
        let result = try analyze(frames, duration: 3)
        for sample in result.samples.dropFirst(15) {
            XCTAssertEqual(try XCTUnwrap(sample.rawVelocity).x, 0.1, accuracy: 0.000_001)
            XCTAssertEqual(try XCTUnwrap(sample.velocity).x, 0.1, accuracy: 0.003)
        }
        XCTAssertEqual(result.requestedSampleRate, 10)
    }

    func testSharedBodyTranslationDoesNotBecomeArmMotion() throws {
        let result = try analyze((0..<20).map {
            let offset = Double($0) * 0.01
            return pose(Double($0) / 10, wristX: 0.5 + offset, shoulderX: 0.3 + offset)
        })
        for sample in result.samples.dropFirst() {
            XCTAssertEqual(try XCTUnwrap(sample.rawVelocity).magnitude, 0, accuracy: 0.000_001)
            XCTAssertEqual(try XCTUnwrap(sample.velocity).magnitude, 0, accuracy: 0.000_001)
        }
    }

    func testHittingHandUsesOnlySameSideJoints() throws {
        let frames = (0..<20).map { index -> CoachPoseFrame in
            var points = pose(Double(index) / 10, wristX: 0.5 + Double(index) * 0.01).points
            points[.leftWrist] = CoachKeypoint(x: 0.1, y: 0.5, confidence: 0.9)
            points[.leftShoulder] = CoachKeypoint(x: 0.2, y: 0.3, confidence: 0.9)
            return CoachPoseFrame(timestamp: Double(index) / 10, points: points)
        }
        let right = try analyze(frames)
        let left = try CoachMotionAnalyzer.analyze(frames: frames, duration: 2, hand: .left)
        XCTAssertGreaterThan(try XCTUnwrap(right.rawPeak), 0.09)
        XCTAssertEqual(try XCTUnwrap(left.rawPeak), 0)
        XCTAssertEqual(left.hand, .left)
    }

    func testActualIrregularIntervalsDetermineVelocity() throws {
        let times = [0.0, 0.08, 0.21, 0.30, 0.46, 0.6]
        let result = try analyze(times.map { pose($0, wristX: 0.5 + 0.2 * $0) })
        for sample in result.samples.dropFirst() {
            XCTAssertEqual(try XCTUnwrap(sample.rawVelocity).x, 0.2, accuracy: 0.000_001)
        }
        XCTAssertEqual(result.samples.map(\.timestamp), times)
        XCTAssertNil(result.samples[0].velocity)
        XCTAssertNil(result.samples[1].acceleration)
        XCTAssertNotNil(result.samples[2].acceleration)
    }

    func testAccelerationUsesVelocityMidpointsForIrregularSampling() throws {
        let result = try analyze([0.0, 0.08, 0.21, 0.30].map { pose($0, wristX: 0.5 + $0 * $0) })
        let first = try XCTUnwrap(result.samples[1].velocity)
        let second = try XCTUnwrap(result.samples[2].velocity)
        let expected = (second.x - first.x) / ((0.21 + 0.08) / 2 - 0.08 / 2)
        XCTAssertEqual(try XCTUnwrap(result.samples[2].acceleration).x, expected, accuracy: 0.000_001)
    }

    func testMissingJointIsUnavailableAndBreaksVelocityAndAcceleration() throws {
        var frames = (0..<8).map { pose(Double($0) / 10, wristX: 0.5 + Double($0) * 0.01) }
        frames[3] = CoachPoseFrame(timestamp: 0.3, points: [:])
        let result = try analyze(frames)
        XCTAssertEqual(result.samples[3].status, .missing)
        XCTAssertNil(result.samples[3].rawVelocity)
        XCTAssertNil(result.samples[3].velocity)
        XCTAssertNil(result.samples[4].velocity)
        XCTAssertNil(result.samples[5].acceleration)
        XCTAssertNotNil(result.samples[6].acceleration)
        XCTAssertNotEqual(result.samples[2].segment, result.samples[5].segment)
    }

    func testLowConfidenceIsRejectedBeforeFiltering() throws {
        var smoother = CoachPoseSmoother()
        _ = smoother.apply(pose(0, wristX: 0.5))
        let invalid = smoother.apply(pose(0.1, wristX: 1.5, confidence: 0.1))
        XCTAssertNil(invalid.points[.rightWrist])
        let recovered = smoother.apply(pose(0.2, wristX: 0.7))
        XCTAssertEqual(recovered.points[.rightWrist]?.x, 0.7)
        let review = try analyze([pose(0, wristX: 0.5), pose(0.1, wristX: 1.5, confidence: 0.1), pose(0.2, wristX: 0.7)])
        XCTAssertEqual(review.samples[1].status, .lowConfidence)
        XCTAssertNil(review.samples[1].velocity)
        XCTAssertNil(review.samples[2].velocity)
    }

    func testLimitedConfidenceIsVisibleAndDoesNotProducePeakMarkers() throws {
        let review = try analyze((0..<20).map { pose(Double($0) / 10, wristX: $0 == 10 ? 0.9 : 0.5, confidence: 0.5) })
        XCTAssertTrue(review.samples.dropFirst().allSatisfy { $0.status == .limited })
        XCTAssertTrue(review.peaks.isEmpty)
    }

    func testGapWithoutExplicitMissingFrameResetsAllDerivatives() throws {
        let review = try analyze([pose(0, wristX: 0.5), pose(0.1, wristX: 0.6), pose(1, wristX: 1.2), pose(1.1, wristX: 1.2), pose(1.2, wristX: 1.2)])
        XCTAssertNil(review.samples[2].velocity)
        XCTAssertNil(review.samples[3].acceleration)
        XCTAssertEqual(try XCTUnwrap(review.samples[3].velocity).magnitude, 0)
        XCTAssertEqual(try XCTUnwrap(review.samples[4].acceleration).magnitude, 0)
    }

    func testNewClipStartsWithNoFilterOrDerivativeHistory() throws {
        var smoother = CoachPoseSmoother()
        _ = smoother.apply(pose(0, wristX: 0.2))
        _ = smoother.apply(pose(0.1, wristX: 0.8))
        smoother.reset()
        XCTAssertEqual(smoother.apply(pose(0, wristX: 0.6)).points[.rightWrist]?.x, 0.6)
        let frames = [pose(0, wristX: 0.4), pose(0.1, wristX: 0.5)]
        XCTAssertEqual(try analyze(frames), try analyze(frames))
    }

    func testInvalidCoordinatesDoNotEnterFilters() {
        for value in [Double.nan, .infinity, -.infinity, -0.1, .greatestFiniteMagnitude] {
            var smoother = CoachPoseSmoother()
            XCTAssertNil(smoother.apply(pose(0, wristX: value)).points[.rightWrist])
            XCTAssertEqual(smoother.apply(pose(0.1, wristX: 0.5)).points[.rightWrist]?.x, 0.5)
        }
    }

    func testInvalidAndOutOfOrderTimestampsBreakContinuityAndRecover() throws {
        for time in [Double.nan, .infinity, -1, 60, 0.1, 0.05] {
            let review = try analyze([pose(0, wristX: 0.5), pose(0.1, wristX: 0.6), pose(time, wristX: 1), pose(0.2, wristX: 0.7), pose(0.3, wristX: 0.8)])
            XCTAssertEqual(review.samples.count, 4)
            XCTAssertNil(review.samples[2].velocity)
            XCTAssertNotNil(review.samples[3].velocity)
            XCTAssertNil(review.samples[3].acceleration)
        }
    }

    func testAspectCorrectCoordinatesGiveSamePhysicalImagePlaneMotion() throws {
        var results: [Double] = []
        for aspect in [9.0 / 16, 16.0 / 9] {
            let frames = (0..<20).map { index in
                let normalizedX = (0.3 + Double(index) * 0.005) / aspect
                return pose(Double(index) / 10, wristX: normalizedX * aspect, shoulderX: 0.2)
            }
            results.append(try XCTUnwrap(analyze(frames).filteredPeak))
        }
        XCTAssertEqual(results[0], results[1], accuracy: 0.000_001)
    }

    func testMissingOtherArmNeverBecomesStationarySelectedArm() throws {
        let frames = (0..<20).map { pose(Double($0) / 10, wristX: 0.5) }
        let left = try CoachMotionAnalyzer.analyze(frames: frames, duration: 2, hand: .left)
        XCTAssertNil(left.rawPeak)
        XCTAssertNil(left.filteredPeak)
        XCTAssertEqual(left.coverage, 0)
        XCTAssertTrue(left.samples.allSatisfy { $0.velocity == nil && $0.status == .missing })
    }

    func testCancellationStopsMotionAnalysis() async {
        let frames = (0..<600).map { pose(Double($0) / 10, wristX: 0.5) }
        let task = Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            return try CoachMotionAnalyzer.analyze(frames: frames, duration: 60, hand: .right)
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testMotionReportRoundTripsAndOldReportsStillDecode() throws {
        let motion = try analyze([pose(0, wristX: 0.5), pose(0.1, wristX: 0.6), pose(0.2, wristX: 0.7)])
        let baseline = CoachAnalyzer.analyze(frames: [], duration: 2, sampledFrameCount: 0, sourceFilename: "practice.mov")
        let oldData = try JSONEncoder().encode(baseline)
        XCTAssertNil(try JSONDecoder().decode(CoachReport.self, from: oldData).motionReview)
        let report = CoachReport(sourceFilename: "practice.mov", duration: 2, sampledFrameCount: 3,
                                 trackedFrameCount: 0, trackedDuration: 0, longestTrackedSegmentDuration: 0,
                                 quality: .insufficient, metrics: [], notes: ["Tracking limited."], motionReview: motion)
        try report.validate()
        XCTAssertEqual(try JSONDecoder().decode(CoachReport.self, from: JSONEncoder().encode(report)), report)
    }

    func testInvalidSettingsAndOversizedTimelinesAreRejected() {
        var settings = CoachSmoothingSettings()
        settings.minimumCutoffHz = .nan
        XCTAssertThrowsError(try CoachMotionAnalyzer.analyze(frames: [], duration: 2, hand: .right, settings: settings))
        XCTAssertThrowsError(try analyze((0..<601).map { pose(Double($0) / 10, wristX: 0.5) }, duration: 60))
    }

    private func pose(_ time: Double, wristX: Double, shoulderX: Double = 0.3, confidence: Double = 0.9) -> CoachPoseFrame {
        CoachPoseFrame(timestamp: time, points: [
            .rightWrist: CoachKeypoint(x: wristX, y: 0.5, confidence: confidence),
            .rightShoulder: CoachKeypoint(x: shoulderX, y: 0.3, confidence: 0.9)
        ])
    }

    private func analyze(_ frames: [CoachPoseFrame], duration: Double = 2) throws -> CoachMotionReview {
        try CoachMotionAnalyzer.analyze(frames: frames, duration: duration, hand: .right)
    }
}
