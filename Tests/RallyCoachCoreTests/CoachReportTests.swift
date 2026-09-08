import Foundation
import XCTest
#if canImport(RallyCoachCore)
@testable import RallyCoachCore
#else
@testable import Rally
#endif

final class CoachReportTests: XCTestCase {
    func testInsufficientReportRoundTripsWithIdentityAndDate() throws {
        let report = CoachAnalyzer.analyze(frames: [], duration: 2, sampledFrameCount: 0, sourceFilename: "serve.mov")
        let encoded = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(CoachReport.self, from: encoded)
        XCTAssertEqual(decoded, report)
        XCTAssertEqual(decoded.id, report.id)
        XCTAssertEqual(decoded.createdAt, report.createdAt)
        try decoded.validate()
    }

    func testUnknownSchemaIsRejectedOnDecode() throws {
        XCTAssertThrowsError(try decodeMutating { $0["schemaVersion"] = 99 })
    }

    func testImpossibleCountsAndTimeAreRejectedOnDecode() throws {
        for mutation: (inout [String: Any]) -> Void in [
            { $0["trackedFrameCount"] = 1 },
            { $0["sampledFrameCount"] = -1 },
            { $0["duration"] = -1 },
            { $0["trackedDuration"] = 3 },
            { $0["longestTrackedSegmentDuration"] = 1 },
            { $0["quality"] = "sufficient" }
        ] {
            XCTAssertThrowsError(try decodeMutating(mutation))
        }
    }

    func testSavedSourcePathAndEmptyNotesAreRejectedOnDecode() throws {
        XCTAssertThrowsError(try decodeMutating { $0["sourceFilename"] = "/private/serve.mov" })
        XCTAssertThrowsError(try decodeMutating { $0["sourceFilename"] = "\n" })
        XCTAssertThrowsError(try decodeMutating { $0["notes"] = [] })
    }

    func testInsufficientReportCannotCarryPlausibleMeasurements() throws {
        XCTAssertThrowsError(try decodeMutating {
            $0["metrics"] = [["kind": "leftElbowBend", "lowerBound": 20, "upperBound": 80, "sampleCount": 12]]
        })
    }

    func testMeasuredReportAndNumericMetricsRoundTrip() throws {
        let report = measuredReport()
        try report.validate()
        let data = try JSONEncoder().encode(report)
        XCTAssertEqual(try JSONDecoder().decode(CoachReport.self, from: data), report)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let metrics = try XCTUnwrap(object["metrics"] as? [[String: Any]])
        XCTAssertNotNil(metrics.first?["lowerBound"])
        XCTAssertNil(metrics.first?["value"], "Formatted display values are derived from validated numeric data")
    }

    func testInvalidMetricRangesDuplicatesAndUnknownKindsAreRejected() throws {
        for mutation: (inout [[String: Any]]) -> Void in [
            { $0[0]["lowerBound"] = -1 },
            { $0[0]["upperBound"] = 181 },
            { $0[0]["lowerBound"] = 100; $0[0]["upperBound"] = 20 },
            { $0[0]["sampleCount"] = 100 },
            { $0[0]["kind"] = "forehandGrade" },
            { $0[1] = $0[0] },
            { $0.removeLast() }
        ] {
            let data = try JSONEncoder().encode(measuredReport())
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            var metrics = try XCTUnwrap(object["metrics"] as? [[String: Any]])
            mutation(&metrics)
            object["metrics"] = metrics
            let mutated = try JSONSerialization.data(withJSONObject: object)
            XCTAssertThrowsError(try JSONDecoder().decode(CoachReport.self, from: mutated))
        }
    }

    private func measuredReport() -> CoachReport {
        CoachReport(
            sourceFilename: "serve.mov", duration: 2, sampledFrameCount: 20, trackedFrameCount: 20,
            trackedDuration: 1.9, longestTrackedSegmentDuration: 1.9, quality: .sufficient,
            metrics: CoachMetricKind.allCases.map { kind in
                CoachMetric(kind: kind, lowerBound: 0, upperBound: kind == .lateralCenterTravel ? 0.2 : 90, sampleCount: 20)
            },
            notes: ["Estimates from sampled 2D poses."]
        )
    }

    private func decodeMutating(_ mutation: (inout [String: Any]) -> Void) throws -> CoachReport {
        let report = CoachAnalyzer.analyze(frames: [], duration: 2, sampledFrameCount: 0, sourceFilename: "serve.mov")
        let data = try JSONEncoder().encode(report)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        mutation(&object)
        return try JSONDecoder().decode(CoachReport.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
