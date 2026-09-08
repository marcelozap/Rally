import Foundation
import XCTest
#if canImport(RallyCoachCore)
@testable import RallyCoachCore
#else
@testable import Rally
#endif

final class CoachReportStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RallyCoachStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        if let directory, FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testSaveSurvivesNewStoreAndDeleteSurvivesRelaunch() async throws {
        let first = CoachReportStore(directory: directory)
        let report = makeReport()
        let initiallyEmpty = try await first.load()
        XCTAssertTrue(initiallyEmpty.isEmpty)
        try await first.save(report)

        let relaunched = CoachReportStore(directory: directory)
        let loaded = try await relaunched.load()
        XCTAssertEqual(loaded, [report])
        try await relaunched.delete(id: report.id)
        let afterDelete = try await CoachReportStore(directory: directory).load()
        XCTAssertTrue(afterDelete.isEmpty)
    }

    func testRepeatedSaveDoesNotDuplicateAndHistoryIsNewestFirst() async throws {
        let store = CoachReportStore(directory: directory)
        let older = makeReport(date: Date(timeIntervalSince1970: 1_000))
        let newer = makeReport(date: Date(timeIntervalSince1970: 2_000))
        try await store.save(newer)
        try await store.save(older)
        try await store.save(newer)
        let loaded = try await store.load()
        XCTAssertEqual(loaded.map(\.id), [newer.id, older.id])
    }

    func testConcurrentSavesDoNotLoseReports() async throws {
        let store = CoachReportStore(directory: directory)
        let reports = (0..<12).map { makeReport(date: Date(timeIntervalSince1970: Double($0))) }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for report in reports {
                group.addTask { _ = try await store.save(report) }
            }
            try await group.waitForAll()
        }
        let loaded = try await store.load()
        XCTAssertEqual(Set(loaded.map(\.id)), Set(reports.map(\.id)))
    }

    func testMalformedHistoryIsPreservedWhenLoadSaveAndDeleteFail() async throws {
        let fileURL = directory.appendingPathComponent("reports.json")
        let corrupt = Data("{ interrupted or incompatible history".utf8)
        try corrupt.write(to: fileURL)
        let store = CoachReportStore(directory: directory)
        await expectFailure { try await store.load() }
        await expectFailure { try await store.save(self.makeReport()) }
        await expectFailure { try await store.delete(id: UUID()) }
        XCTAssertEqual(try Data(contentsOf: fileURL), corrupt)
    }

    func testDuplicateSavedIdentityIsRejectedWithoutOverwritingHistory() async throws {
        let report = makeReport()
        let duplicateData = try JSONEncoder().encode([report, report])
        let fileURL = directory.appendingPathComponent("reports.json")
        try duplicateData.write(to: fileURL)
        let store = CoachReportStore(directory: directory)
        await expectFailure { try await store.load() }
        await expectFailure { try await store.save(self.makeReport()) }
        XCTAssertEqual(try Data(contentsOf: fileURL), duplicateData)
    }

    func testInvalidNewReportCannotReplaceHealthyHistory() async throws {
        let store = CoachReportStore(directory: directory)
        let report = makeReport()
        try await store.save(report)
        let before = try Data(contentsOf: directory.appendingPathComponent("reports.json"))
        let invalid = CoachReport(
            sourceFilename: "serve.mov", duration: -1, sampledFrameCount: 0, trackedFrameCount: 0,
            trackedDuration: 0, longestTrackedSegmentDuration: 0, quality: .insufficient,
            metrics: [], notes: ["Not enough tracking."]
        )
        await expectFailure { try await store.save(invalid) }
        let after = try Data(contentsOf: directory.appendingPathComponent("reports.json"))
        XCTAssertEqual(before, after)
        let loaded = try await store.load()
        XCTAssertEqual(loaded, [report])
    }

    func testStoragePathOccupiedByFileSurfacesReadAndWriteFailure() async throws {
        let blockedDirectory = directory.appendingPathComponent("blocked")
        let marker = Data("keep this unrelated file".utf8)
        try marker.write(to: blockedDirectory)
        let store = CoachReportStore(directory: blockedDirectory)
        await expectFailure { try await store.load() }
        await expectFailure { try await store.save(self.makeReport()) }
        XCTAssertEqual(try Data(contentsOf: blockedDirectory), marker)
    }

    func testOversizedHistoryFailsWithoutTruncation() async throws {
        let fileURL = directory.appendingPathComponent("reports.json")
        let oversized = Data(repeating: 32, count: 10_000_001)
        try oversized.write(to: fileURL)
        let store = CoachReportStore(directory: directory)
        await expectFailure { try await store.load() }
        await expectFailure { try await store.save(self.makeReport()) }
        let after = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        XCTAssertEqual((after[.size] as? NSNumber)?.intValue, oversized.count)
    }

    #if os(iOS) || os(macOS)
    func testSavedReportDirectoryIsExcludedFromBackup() async throws {
        try await CoachReportStore(directory: directory).save(makeReport())
        let resources = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(resources.isExcludedFromBackup, true)
    }
    #endif

    private func makeReport(date: Date = Date()) -> CoachReport {
        CoachReport(
            createdAt: date, sourceFilename: "serve.mov", duration: 2,
            sampledFrameCount: 20, trackedFrameCount: 0, trackedDuration: 0,
            longestTrackedSegmentDuration: 0, quality: .insufficient,
            metrics: [], notes: ["Keep the whole body in frame."]
        )
    }

    private func expectFailure<T>(
        file: StaticString = #filePath, line: UInt = #line,
        _ operation: () async throws -> T
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected this storage operation to fail", file: file, line: line)
        } catch {
            // Expected: callers receive an error instead of silent data loss.
        }
    }
}
