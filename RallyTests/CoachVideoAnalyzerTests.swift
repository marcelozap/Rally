import XCTest
import AVFoundation
import CoreVideo
@testable import Rally

/// Apple-framework tests: run on the laptop's iOS Simulator/device test target.
/// These exercise resource limits and real AVFoundation/Vision execution; they
/// do not claim tennis accuracy from synthetic clips.
final class CoachVideoAnalyzerTests: XCTestCase {
    func testNetworkURLIsRejectedBeforeOpeningAnAsset() async {
        do {
            _ = try await CoachVideoAnalyzer().analyze(
                url: URL(string: "https://example.invalid/private-video.mov")!,
                sourceName: "Practice video",
                onProgress: { _ in XCTFail("No asset should be opened for a remote URL") }
            )
            XCTFail("Expected a local-file error")
        } catch {
            XCTAssertEqual(error as? CoachVideoAnalysisError, .localFileRequired)
        }
    }

    func testDurationLimitsRejectNonfiniteAndOutOfBoundsClips() throws {
        for value in [Double.nan, .infinity, -.infinity, 0, -1] {
            XCTAssertThrowsError(try CoachVideoAnalyzer.validateDuration(value)) {
                XCTAssertEqual($0 as? CoachVideoAnalysisError, .invalidDuration)
            }
        }
        XCTAssertThrowsError(try CoachVideoAnalyzer.validateDuration(1.999)) {
            XCTAssertEqual($0 as? CoachVideoAnalysisError, .videoTooShort)
        }
        XCTAssertThrowsError(try CoachVideoAnalyzer.validateDuration(60.001)) {
            XCTAssertEqual($0 as? CoachVideoAnalysisError, .videoTooLong)
        }
        try CoachVideoAnalyzer.validateDuration(2)
        try CoachVideoAnalyzer.validateDuration(60)
    }

    func testMissingEmptyAndDirectorySourcesAreRejected() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let empty = directory.appendingPathComponent("empty.mov")
        try Data().write(to: empty)
        for url in [directory, empty, directory.appendingPathComponent("missing.mov")] {
            XCTAssertThrowsError(try CoachVideoAnalyzer.validateLocalFile(url)) {
                XCTAssertEqual($0 as? CoachVideoAnalysisError, .unreadableFile)
            }
        }
    }

    func testByteLimitChecksLogicalSizeWithoutLoadingVideoIntoMemory() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("large.mov")
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: nil))
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: UInt64(CoachVideoAnalyzer.maximumFileSizeBytes))
        try CoachVideoAnalyzer.validateLocalFile(url)
        try handle.truncate(atOffset: UInt64(CoachVideoAnalyzer.maximumFileSizeBytes + 1))
        XCTAssertThrowsError(try CoachVideoAnalyzer.validateLocalFile(url)) {
            XCTAssertEqual($0 as? CoachVideoAnalysisError, .fileTooLarge)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testAlreadyCancelledAnalysisDoesNotStartFileAccess() async {
        let operation = Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await CoachVideoAnalyzer().analyze(
                url: URL(fileURLWithPath: "/does-not-exist/cancelled.mov"),
                sourceName: "Cancelled",
                onProgress: { _ in XCTFail("Cancelled analysis must not start") }
            )
        }
        do {
            _ = try await operation.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testUnreadableMediaDoesNotDeleteItsSource() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("not-a-video.mov")
        let original = Data("This is not a movie.".utf8)
        try original.write(to: url)
        do {
            _ = try await CoachVideoAnalyzer().analyze(url: url, sourceName: "Invalid", onProgress: { _ in })
            XCTFail("Expected an unsupported-video error")
        } catch {
            XCTAssertNotNil(error as? CoachVideoAnalysisError)
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testBlankRotatedVideoRunsWithoutInventingMovement() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("blank-portrait.mov")
        try await writeBlankMovie(to: url)
        let report = try await CoachVideoAnalyzer().analyze(
            url: url, sourceName: "Blank recording", onProgress: { _ in }
        )
        XCTAssertEqual(report.quality, .insufficient)
        XCTAssertEqual(report.trackedFrameCount, 0)
        XCTAssertEqual(report.sampledFrameCount, 20)
        XCTAssertTrue(report.metrics.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RallyCoachTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeBlankMovie(to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 96
        ])
        input.expectsMediaDataInRealTime = false
        input.transform = CGAffineTransform(rotationAngle: .pi / 2)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 64,
            kCVPixelBufferHeightKey as String: 96
        ])
        writer.add(input)
        guard writer.startWriting() else { throw fixtureError(writer.error) }
        writer.startSession(atSourceTime: .zero)
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, 64, 96, kCVPixelFormatType_32BGRA, nil, &pixelBuffer) == kCVReturnSuccess,
              let buffer = pixelBuffer else { throw fixtureError(nil) }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 0, CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        for index in 0..<20 {
            var attempts = 0
            while !input.isReadyForMoreMediaData {
                guard attempts < 1_000, writer.status == .writing else { throw fixtureError(writer.error) }
                try await Task.sleep(nanoseconds: 10_000_000)
                attempts += 1
            }
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 10)) else {
                throw fixtureError(writer.error)
            }
        }
        writer.endSession(atSourceTime: CMTime(value: 2, timescale: 1))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw fixtureError(writer.error) }
    }

    private func fixtureError(_ underlying: Error?) -> Error {
        underlying ?? NSError(domain: "CoachVideoAnalyzerTests.Fixture", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not create the synthetic blank-video test fixture."
        ])
    }
}
