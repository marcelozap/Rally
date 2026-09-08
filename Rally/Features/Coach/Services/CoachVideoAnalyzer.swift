import Foundation
import AVFoundation
import Vision

enum CoachVideoAnalysisError: Error, LocalizedError, Equatable {
    case localFileRequired
    case fileTooLarge
    case unreadableFile
    case unsupportedVideo
    case invalidDuration
    case videoTooShort
    case videoTooLong
    case unreadableFrames
    case poseAnalysisFailed

    var errorDescription: String? {
        switch self {
        case .localFileRequired:
            return "Choose a video from your photo library. Rally Coach analyzes a local copy on your device."
        case .fileTooLarge:
            return "This video is larger than 250 MB. Trim or export a smaller clip and try again."
        case .unreadableFile:
            return "This video could not be opened. Choose it again or try another clip."
        case .unsupportedVideo:
            return "Rally Coach could not read this video format. Try a regular video recorded with your iPhone."
        case .invalidDuration:
            return "This video does not have a readable duration. Try another clip."
        case .videoTooShort:
            return "Choose a video at least 2 seconds long so Rally Coach can observe movement."
        case .videoTooLong:
            return "Trim this video to 60 seconds or less, then choose it again."
        case .unreadableFrames:
            return "Rally Coach could not read any frames in this video. Try exporting it again or choose another clip."
        case .poseAnalysisFailed:
            return "Movement analysis could not run on this video. Try again with another clip."
        }
    }
}

/// Extracts body poses locally; it does not upload video or use an external model.
///
/// The caller owns `url`: supply a readable, app-owned copy of a selected movie,
/// and keep it until this method returns (including after requesting cancellation).
/// The importer must balance any security-scoped access while creating that copy.
/// This analyzer never removes or modifies the source, and retains no images or
/// poses after returning the report. The caller removes its temporary copy in a
/// defer on success, failure, or cancellation. Limits are checked again here even
/// when the importer has already checked them.
struct CoachVideoAnalyzer: Sendable {
    static let minimumDuration: Double = 2
    static let maximumDuration: Double = 60
    static let maximumFileSizeBytes: Int64 = 250_000_000
    static let sampleRate: Double = 10
    private static let maximumImageDimension: CGFloat = 720

    /// Progress arrives on a worker executor; UI callers must hop to MainActor.
    /// A detached task keeps synchronous Vision work off the UI's executor.
    func analyze(
        url: URL,
        sourceName: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> CoachReport {
        try Task.checkCancellation()
        let cancellation = CoachVideoCancellation()
        let worker = Task.detached(priority: .userInitiated) {
            defer { cancellation.cancel() }
            return try await Self.makeReport(
                url: url,
                sourceName: sourceName,
                onProgress: onProgress,
                cancellation: cancellation
            )
        }
        return try await withTaskCancellationHandler {
            // Always await worker teardown, even if the caller was already
            // cancelled. The caller may delete its temporary file on return.
            do {
                let report = try await worker.value
                try Task.checkCancellation()
                return report
            } catch {
                try Task.checkCancellation()
                throw error
            }
        } onCancel: {
            worker.cancel()
            cancellation.cancel()
        }
    }

    private static func makeReport(
        url: URL,
        sourceName: String,
        onProgress: @escaping @Sendable (Double) -> Void,
        cancellation: CoachVideoCancellation
    ) async throws -> CoachReport {
        try Task.checkCancellation()
        try validateLocalFile(url)
        onProgress(0)

        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        cancellation.install(asset: asset)

        let duration: Double
        do {
            try Task.checkCancellation()
            let durationTime = try await asset.load(.duration)
            duration = durationTime.seconds
            try validateDuration(duration)
            let readable = try await asset.load(.isReadable)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            // Multiple video tracks (for example specialized spatial exports)
            // need an explicit composition; do not silently analyze one view.
            guard readable, videoTracks.count == 1 else {
                throw CoachVideoAnalysisError.unsupportedVideo
            }
        } catch {
            try Task.checkCancellation()
            if let failure = error as? CoachVideoAnalysisError { throw failure }
            throw CoachVideoAnalysisError.unsupportedVideo
        }

        try Task.checkCancellation()
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maximumImageDimension, height: maximumImageDimension)
        // Never accept arbitrarily distant keyframes. Actual timestamps are
        // still used below: requested times are not measured observations.
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        cancellation.install(generator: generator)

        let sampleCount = min(Int(maximumDuration * sampleRate), Int(ceil(duration * sampleRate)))
        var frames: [CoachPoseFrame] = []
        frames.reserveCapacity(sampleCount)
        var decodedFrameCount = 0
        var completedPoseRequestCount = 0

        for index in 0..<sampleCount {
            try Task.checkCancellation()
            let requestedSeconds = Double(index) / sampleRate
            var frame = CoachPoseFrame(timestamp: requestedSeconds, points: [:])
            do {
                // Only one image is retained at a time; the pose array contains
                // at most 600 small coordinate dictionaries, never pixel data.
                let generated = try await generator.image(
                    at: CMTime(seconds: requestedSeconds, preferredTimescale: 600)
                )
                try Task.checkCancellation()
                decodedFrameCount += 1
                let actualSeconds = generated.actualTime.seconds
                if actualSeconds.isFinite, actualSeconds >= 0, actualSeconds < duration {
                    frame = CoachPoseFrame(timestamp: actualSeconds, points: [:])
                    let request = VNDetectHumanBodyPoseRequest()
                    cancellation.install(request: request)
                    defer { cancellation.clearRequest() }
                    do {
                        let points = try autoreleasepool {
                            let handler = VNImageRequestHandler(cgImage: generated.image, options: [:])
                            try handler.perform([request])
                            try Task.checkCancellation()
                            return try keypoints(
                                observations: request.results ?? [],
                                width: generated.image.width,
                                height: generated.image.height
                            )
                        }
                        completedPoseRequestCount += 1
                        frame = CoachPoseFrame(timestamp: actualSeconds, points: points)
                    } catch {
                        try Task.checkCancellation()
                        // A failed request remains a gap. It cannot silently
                        // reuse the last detected pose or improve coverage.
                    }
                }
            } catch {
                try Task.checkCancellation()
                // Keep failed extraction slots so quality and continuity do
                // not improve merely because frames were unreadable.
            }
            frames.append(frame)
            onProgress(Double(index + 1) / Double(sampleCount))
        }

        try Task.checkCancellation()
        guard decodedFrameCount > 0 else { throw CoachVideoAnalysisError.unreadableFrames }
        guard completedPoseRequestCount > 0 else { throw CoachVideoAnalysisError.poseAnalysisFailed }
        return CoachAnalyzer.analyze(
            frames: frames,
            duration: duration,
            sampledFrameCount: sampleCount,
            sourceFilename: sourceName
        )
    }

    static func validateLocalFile(_ url: URL) throws {
        guard url.isFileURL else { throw CoachVideoAnalysisError.localFileRequired }
        let values: URLResourceValues
        do {
            var inspectedURL = url
            inspectedURL.removeAllCachedResourceValues()
            values = try inspectedURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        } catch {
            throw CoachVideoAnalysisError.unreadableFile
        }
        guard values.isRegularFile == true,
              let byteCount = values.fileSize,
              byteCount > 0,
              FileManager.default.isReadableFile(atPath: url.path) else {
            throw CoachVideoAnalysisError.unreadableFile
        }
        guard Int64(byteCount) <= maximumFileSizeBytes else {
            throw CoachVideoAnalysisError.fileTooLarge
        }
    }

    static func validateDuration(_ duration: Double) throws {
        guard duration.isFinite, duration > 0 else { throw CoachVideoAnalysisError.invalidDuration }
        guard duration >= minimumDuration else { throw CoachVideoAnalysisError.videoTooShort }
        guard duration <= maximumDuration else { throw CoachVideoAnalysisError.videoTooLong }
    }

    private static func keypoints(
        observations: [VNHumanBodyPoseObservation],
        width: Int,
        height: Int
    ) throws -> [CoachJoint: CoachKeypoint] {
        // Refuse an ambiguous frame instead of switching between players.
        guard observations.count == 1, let observation = observations.first,
              width > 0, height > 0 else { return [:] }
        let recognized = try observation.recognizedPoints(.all)
        let joints: [(CoachJoint, VNHumanBodyPoseObservation.JointName)] = [
            (.nose, .nose),
            (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
            (.leftElbow, .leftElbow), (.rightElbow, .rightElbow),
            (.leftWrist, .leftWrist), (.rightWrist, .rightWrist),
            (.leftHip, .leftHip), (.rightHip, .rightHip),
            (.leftKnee, .leftKnee), (.rightKnee, .rightKnee),
            (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle)
        ]
        let aspectRatio = Double(width) / Double(height)
        var result: [CoachJoint: CoachKeypoint] = [:]
        for (joint, visionJoint) in joints {
            guard let point = recognized[visionJoint], point.confidence > 0 else { continue }
            let x = Double(point.location.x)
            let y = Double(point.location.y)
            guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else { continue }
            // The generated image is already upright. Vision has a lower-left
            // origin; core uses top-left with BOTH axes in image-height units.
            // Correcting aspect ratio prevents distorted joint-angle metrics.
            result[joint] = CoachKeypoint(
                x: x * aspectRatio,
                y: 1 - y,
                confidence: Double(point.confidence)
            )
        }
        return result
    }
}

/// Only cancellation crosses executors. AV/Vision objects otherwise belong to
/// the detached worker. Lock-protected registration closes the race where a
/// cancellation arrives before an asset, generator, or request is installed.
private final class CoachVideoCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var asset: AVURLAsset?
    private var generator: AVAssetImageGenerator?
    private var request: VNRequest?

    func install(asset: AVURLAsset) {
        lock.lock()
        self.asset = asset
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel { asset.cancelLoading() }
    }

    func install(generator: AVAssetImageGenerator) {
        lock.lock()
        self.generator = generator
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel { generator.cancelAllCGImageGeneration() }
    }

    func install(request: VNRequest) {
        lock.lock()
        self.request = request
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel { request.cancel() }
    }

    func clearRequest() {
        lock.lock()
        request = nil
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let currentAsset = asset
        let currentGenerator = generator
        let currentRequest = request
        asset = nil
        generator = nil
        request = nil
        lock.unlock()
        currentRequest?.cancel()
        currentGenerator?.cancelAllCGImageGeneration()
        currentAsset?.cancelLoading()
    }
}
