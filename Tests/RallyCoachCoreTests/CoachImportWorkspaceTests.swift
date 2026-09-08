import Foundation
import XCTest
#if canImport(RallyCoachCore)
@testable import RallyCoachCore
#else
@testable import Rally
#endif

final class CoachImportWorkspaceTests: XCTestCase {
    private var testDirectory: URL!
    private var root: URL { testDirectory.appendingPathComponent("CoachImports", isDirectory: true) }

    override func setUpWithError() throws {
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RallyCoachWorkspaceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        if let testDirectory { try FileManager.default.removeItem(at: testDirectory) }
        testDirectory = nil
    }

    func testNewProcessRemovesPreviousProcessVideoCopies() throws {
        let old = CoachImportWorkspace(directory: root)
        let abandoned = try old.makeClipDirectory()
        try Data(repeating: 1, count: 1_024).write(to: abandoned.appendingPathComponent("practice.mov"))
        let current = CoachImportWorkspace(directory: root)
        try current.prepare()
        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.deletingLastPathComponent().path))
        let active = try current.makeClipDirectory()
        XCTAssertTrue(FileManager.default.fileExists(atPath: active.path))
    }

    func testRepeatedPreparationNeverDeletesCurrentProcessClips() throws {
        let workspace = CoachImportWorkspace(directory: root)
        let first = try workspace.makeClipDirectory()
        let video = first.appendingPathComponent("practice.mov")
        try Data("active reader".utf8).write(to: video)
        try workspace.prepare()
        let second = try workspace.makeClipDirectory()
        try workspace.prepare()
        XCTAssertTrue(FileManager.default.fileExists(atPath: video.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
    }

    func testTemporaryStoragePurgeDuringProcessCanRecoverWithoutRelaunch() throws {
        let workspace = CoachImportWorkspace(directory: root)
        let first = try workspace.makeClipDirectory()
        let process = first.deletingLastPathComponent()
        try FileManager.default.removeItem(at: process)
        let second = try workspace.makeClipDirectory()
        XCTAssertEqual(second.deletingLastPathComponent(), process)
        try FileManager.default.removeItem(at: root)
        let third = try workspace.makeClipDirectory()
        XCTAssertTrue(FileManager.default.fileExists(atPath: third.path))
    }

    func testPrunePreservesUnownedNamesAndUnrelatedSiblingFiles() throws {
        let old = CoachImportWorkspace(directory: root)
        let abandoned = try old.makeClipDirectory()
        let foreignChild = abandoned.deletingLastPathComponent().appendingPathComponent("notes.txt")
        try Data("keep".utf8).write(to: foreignChild)
        let foreignProcess = root.appendingPathComponent("process-not-a-uuid", isDirectory: true)
        try FileManager.default.createDirectory(at: foreignProcess, withIntermediateDirectories: false)
        let sibling = testDirectory.appendingPathComponent("another-feature.mov")
        try Data("not owned by Coach".utf8).write(to: sibling)
        try CoachImportWorkspace(directory: root).prepare()
        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreignChild.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreignProcess.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sibling.path))
    }

    func testRemovingOneClipPreservesOtherActiveClipsAndIsIdempotent() throws {
        let workspace = CoachImportWorkspace(directory: root)
        let first = try workspace.makeClipDirectory()
        let second = try workspace.makeClipDirectory()
        try workspace.removeClipDirectory(first)
        try workspace.removeClipDirectory(first)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
    }

    func testRefusesRemovalOutsideCurrentProcess() throws {
        let workspace = CoachImportWorkspace(directory: root)
        _ = try workspace.makeClipDirectory()
        let outside = testDirectory.appendingPathComponent("clip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        XCTAssertThrowsError(try workspace.removeClipDirectory(outside))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testPreparationFailureIsVisibleAndRetryCanRecover() throws {
        try Data("occupied path".utf8).write(to: root)
        let workspace = CoachImportWorkspace(directory: root)
        XCTAssertThrowsError(try workspace.prepare())
        XCTAssertThrowsError(try workspace.makeClipDirectory())
        try FileManager.default.removeItem(at: root)
        let clip = try workspace.makeClipDirectory()
        XCTAssertTrue(FileManager.default.fileExists(atPath: clip.path))
    }

    func testFailedCleanupBlocksCopyUntilRetryRemovesAbandonedClip() throws {
        let workspace = CoachImportWorkspace(directory: root)
        let clip = try workspace.makeClipDirectory()
        try FileManager.default.removeItem(at: clip)
        // A substituted object must not be treated as an owned directory.
        try Data("unexpected file".utf8).write(to: clip)
        XCTAssertThrowsError(try workspace.removeClipDirectory(clip))
        XCTAssertThrowsError(try workspace.makeClipDirectory())
        try FileManager.default.removeItem(at: clip)
        try FileManager.default.createDirectory(at: clip, withIntermediateDirectories: false)
        try Data("abandoned video".utf8).write(to: clip.appendingPathComponent("practice.mov"))
        try workspace.prepare()
        XCTAssertFalse(FileManager.default.fileExists(atPath: clip.path))
        _ = try workspace.makeClipDirectory()
    }

    func testPreviousProcessSymbolicLinkIsSkippedAndTargetPreserved() throws {
        let workspace = CoachImportWorkspace(directory: root)
        try workspace.prepare()
        let outside = testDirectory.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        let sentinel = outside.appendingPathComponent("keep.mov")
        try Data("keep".utf8).write(to: sentinel)
        let link = root.appendingPathComponent("process-\(UUID().uuidString)", isDirectory: true)
        try makeSymbolicLink(at: link, destination: outside)
        try CoachImportWorkspace(directory: root).prepare()
        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
        XCTAssertTrue(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
    }

    func testSymbolicLinkInsideOldClipIsSkipped() throws {
        let old = CoachImportWorkspace(directory: root)
        let abandoned = try old.makeClipDirectory()
        let outside = testDirectory.appendingPathComponent("outside.mov")
        try Data("keep".utf8).write(to: outside)
        let link = abandoned.appendingPathComponent("practice.mov")
        try makeSymbolicLink(at: link, destination: outside)
        try CoachImportWorkspace(directory: root).prepare()
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
        XCTAssertTrue(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
    }

    private func makeSymbolicLink(at link: URL, destination: URL) throws {
        do {
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: destination)
        } catch {
            throw XCTSkip("This host cannot create a symbolic link: \(error.localizedDescription)")
        }
    }
}
