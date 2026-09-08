import XCTest
import AVFoundation
import CoreVideo
import SwiftUI
import UIKit
import Darwin
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

    func testCancellationDuringAnalysisAllowsAnotherClip() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("cancel-during-analysis.mov")
        try await writeBlankMovie(to: url)
        let started = expectation(description: "Analysis started on background worker")
        let worker = Task {
            try await CoachVideoAnalyzer().analyze(url: url, sourceName: "Cancellation fixture", motionHand: .right) {
                if $0 == 0 { started.fulfill() }
            }
        }
        await fulfillment(of: [started], timeout: 5)
        worker.cancel()
        do { _ = try await worker.value; XCTFail("Expected cancellation during analysis") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let next = try await CoachVideoAnalyzer().analyze(url: url, sourceName: "Next clip", motionHand: .left, onProgress: { _ in })
        XCTAssertEqual(next.motionReview?.hand, .left)
        XCTAssertTrue(next.motionReview?.samples.allSatisfy { $0.velocity == nil } == true)
    }

    /// External fixture is supplied through devicectl into this test-owned path.
    /// It is never bundled, uploaded, or substituted for a user's recording.
    func testRealTennisClipsWhenProvided() async throws {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RallyCoachValidation-20260908", isDirectory: true)
        let names = ["tennis-landscape.mov", "tennis-portrait.mov"]
        guard names.allSatisfy({ FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) }) else {
            throw XCTSkip("Supply the documented external tennis fixtures to the app's test-owned validation directory.")
        }
        for name in names {
            let url = directory.appendingPathComponent(name)
            defer { try? FileManager.default.removeItem(at: url) }
            let beforeMemory = residentBytes()
            let beforeThermal = ProcessInfo.processInfo.thermalState.rawValue
            let observations = CoachObservedFrames()
            let startedAt = ProcessInfo.processInfo.systemUptime
            let report = try await CoachVideoAnalyzer().analyze(
                url: url, sourceName: name, motionHand: .right,
                onObservedFrames: { observations.set($0) }, onProgress: { _ in }
            )
            let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
            let motion = try XCTUnwrap(report.motionReview)
            try report.validate()
            let note = "Coach real fixture \(name): duration=\(report.duration), seconds=\(elapsed), fullBodyCoverage=\(report.coverage), armVelocityCoverage=\(motion.coverage), rawPeak=\(String(describing: motion.rawPeak)), filteredPeak=\(String(describing: motion.filteredPeak)), thermalBefore=\(beforeThermal), thermalAfter=\(ProcessInfo.processInfo.thermalState.rawValue), residentBefore=\(beforeMemory), residentAfter=\(residentBytes())"
            print(note)
            for (cutoff, beta) in [(2.0, 4.0), (2.5, 12.0), (3.0, 12.0), (3.0, 20.0), (3.0, 30.0)] {
                var settings = CoachSmoothingSettings()
                settings.minimumCutoffHz = cutoff
                settings.speedCoefficient = beta
                let candidate = try CoachMotionAnalyzer.analyze(frames: observations.get(), duration: report.duration, hand: .right, settings: settings)
                let retention = (candidate.filteredPeak ?? 0) / max(candidate.rawPeak ?? 0, 0.000_001)
                print("Coach filter replay \(name): cutoff=\(cutoff), beta=\(beta), peakRetention=\(retention)")
            }
            let data = try JSONEncoder().encode(report)
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = name + "-report"
            attachment.lifetime = .keepAlways
            add(attachment)
            await attachScreen(
                ScrollView { CoachMotionTimelineView(review: motion).padding(16) }, name: name + "-motion-review", width: 375, height: 1100
            )
        }
    }

    @MainActor
    func testCoachEmptyScreenAtSmallWidthAndLargeType() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = CoachViewModel(store: CoachReportStore(directory: directory), motionPreviewEnabled: true)
        await model.loadHistory()
        XCTAssertTrue(model.reports.isEmpty)
        await attachScreen(NavigationStack { CoachView(model: model) }, name: "coach-empty-320", width: 320, height: 740)
        await attachScreen(
            NavigationStack { CoachView(model: model) }.environment(\.dynamicTypeSize, .accessibility3),
            name: "coach-empty-large-type-320", width: 320, height: 1100
        )
        let frames = (0..<20).map { index in
            CoachPoseFrame(timestamp: Double(index) / 10, points: (8...9).contains(index) ? [:] : [
                .rightShoulder: CoachKeypoint(x: 0.3, y: 0.3, confidence: 0.9),
                .rightWrist: CoachKeypoint(x: 0.5 + sin(Double(index) * 0.8) * 0.1, y: 0.5,
                                           confidence: (14...15).contains(index) ? 0.5 : 0.9)
            ])
        }
        let review = try CoachMotionAnalyzer.analyze(frames: frames, duration: 2, hand: .right)
        await attachScreen(ScrollView { CoachMotionTimelineView(review: review).padding(16) },
                           name: "coach-motion-synthetic-320", width: 320, height: 1100)
    }

    @MainActor
    private func attachScreen<Content: View>(_ content: Content, name: String, width: CGFloat, height: CGFloat) async {
        let previous = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)
        let controller = UIHostingController(rootView: ZStack {
            RallyUIKit.screenBackground
            content
        }.environment(\.colorScheme, .dark))
        let window: UIWindow
        if let scene = previous?.windowScene { window = UIWindow(windowScene: scene) }
        else { window = UIWindow(frame: .zero) }
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try? await Task.sleep(nanoseconds: 200_000_000)
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? UInt64(info.resident_size) : 0
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

private final class CoachObservedFrames: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [CoachPoseFrame] = []
    func set(_ value: [CoachPoseFrame]) { lock.lock(); defer { lock.unlock() }; frames = value }
    func get() -> [CoachPoseFrame] { lock.lock(); defer { lock.unlock() }; return frames }
}
