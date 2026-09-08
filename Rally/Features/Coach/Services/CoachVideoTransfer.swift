import CoreTransferable
import Foundation
import PhotosUI
import UniformTypeIdentifiers

/// A uniquely owned temporary movie. Explicit cleanup is used after analysis;
/// deinit also handles a Photos completion arriving after its caller cancels.
final class CoachImportedVideo: Transferable, @unchecked Sendable {
    let url: URL
    let sourceName: String
    private let directory: URL

    private init(url: URL, sourceName: String, directory: URL) {
        self.url = url
        self.sourceName = sourceName
        self.directory = directory
    }

    static var transferRepresentation: some TransferRepresentation {
        // Request a generic movie and use .current on PhotosPicker to preserve
        // HEVC/HDR originals for AVFoundation instead of requesting transcoding.
        FileRepresentation(importedContentType: .movie) { received in
            try copyForAnalysis(from: received.file)
        }
    }

    func removeTemporaryFile() throws {
        try CoachImportWorkspace.shared.removeClipDirectory(directory)
    }

    deinit {
        // A second, best-effort attempt also covers abandoned transfer results.
        try? removeTemporaryFile()
    }

    private static func copyForAnalysis(from source: URL) throws -> CoachImportedVideo {
        try Task.checkCancellation()
        let manager = FileManager.default
        let attributes = try manager.attributesOfItem(atPath: source.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.int64Value > 0 else {
            throw CoachVideoImportError.unreadableVideo
        }
        guard size.int64Value <= CoachVideoAnalyzer.maximumFileSizeBytes else {
            throw CoachVideoImportError.fileTooLarge
        }
        let directory = try CoachImportWorkspace.shared.makeClipDirectory()
        let destination = directory.appendingPathComponent("practice")
            .appendingPathExtension(source.pathExtension.isEmpty ? "mov" : source.pathExtension)
        do {
            // Stream a bounded file instead of materializing a movie as Data.
            guard manager.createFile(atPath: destination.path, contents: nil) else {
                throw CoachVideoImportError.unreadableVideo
            }
            let input = try FileHandle(forReadingFrom: source)
            defer { try? input.close() }
            let output = try FileHandle(forWritingTo: destination)
            defer { try? output.close() }
            var copiedBytes: Int64 = 0
            while true {
                try Task.checkCancellation()
                guard let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty else { break }
                copiedBytes += Int64(chunk.count)
                guard copiedBytes <= CoachVideoAnalyzer.maximumFileSizeBytes else {
                    throw CoachVideoImportError.fileTooLarge
                }
                try output.write(contentsOf: chunk)
            }
            try output.synchronize()
            try Task.checkCancellation()
            guard copiedBytes > 0 else { throw CoachVideoImportError.unreadableVideo }
            return CoachImportedVideo(
                url: destination,
                sourceName: String(source.lastPathComponent.prefix(200)),
                directory: directory
            )
        } catch {
            // Cleanup failure takes precedence; it is queued and blocks future
            // imports until preparation can remove the abandoned copy.
            try CoachImportWorkspace.shared.removeClipDirectory(directory)
            throw error
        }
    }
}

enum CoachVideoImportError: LocalizedError {
    case unreadableVideo
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .unreadableVideo:
            return "This video could not be opened. Choose another clip, or retry after Photos finishes downloading it from iCloud."
        case .fileTooLarge:
            return "Choose a video smaller than 250 MB. You can trim a shorter practice clip in Photos."
        }
    }
}

enum CoachVideoTransfer {
    static func load(from item: PhotosPickerItem) async throws -> CoachImportedVideo {
        try CoachImportWorkspace.shared.prepare()
        let transfer = CoachTransferSession()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard transfer.install(continuation) else { return }
                let progress = item.loadTransferable(type: CoachImportedVideo.self) { result in
                    transfer.finish(result)
                }
                transfer.attach(progress)
            }
        } onCancel: {
            transfer.cancel()
        }
    }
}

/// Protects the continuation/Progress race when Photos downloads an iCloud item.
/// Cancelling resumes exactly once; a late imported movie is released and cleaned.
private final class CoachTransferSession: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CoachImportedVideo, Error>?
    private var progress: Progress?
    private var finished = false

    func install(_ continuation: CheckedContinuation<CoachImportedVideo, Error>) -> Bool {
        lock.lock()
        if finished {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func attach(_ progress: Progress) {
        lock.lock()
        let shouldCancel = finished
        if !finished { self.progress = progress }
        lock.unlock()
        if shouldCancel { progress.cancel() }
    }

    func finish(_ result: Result<CoachImportedVideo?, Error>) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let continuation = continuation
        self.continuation = nil
        progress = nil
        lock.unlock()
        switch result {
        case .success(let video?): continuation?.resume(returning: video)
        case .success(nil): continuation?.resume(throwing: CoachVideoImportError.unreadableVideo)
        case .failure(let error): continuation?.resume(throwing: error)
        }
    }

    func cancel() {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let continuation = continuation
        let progress = progress
        self.continuation = nil
        self.progress = nil
        lock.unlock()
        progress?.cancel()
        continuation?.resume(throwing: CancellationError())
    }
}
