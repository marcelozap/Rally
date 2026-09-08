import Foundation

/// Crash recovery for Coach's temporary video copies. The production singleton
/// owns one process directory; preparation never prunes that process's clips.
/// Only recognized directories beneath the dedicated Coach parent are eligible.
final class CoachImportWorkspace: @unchecked Sendable {
    static let shared = CoachImportWorkspace()
    private let root: URL
    private let processName: String
    private let lock = NSLock()
    private let manager = FileManager.default
    private var prepared = false
    private var pendingCleanup: Set<URL> = []

    init(directory: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RallyCoachImports", isDirectory: true), processID: UUID = UUID()) {
        // Resolve the parent (e.g. Apple's /var alias), but do not resolve the
        // Coach directory itself: a substituted symbolic link must be rejected.
        root = directory.deletingLastPathComponent().resolvingSymlinksInPath()
            .appendingPathComponent(directory.lastPathComponent, isDirectory: true).standardizedFileURL
        processName = "process-\(processID.uuidString)"
    }

    func prepare() throws {
        lock.lock()
        defer { lock.unlock() }
        try prepareLocked()
    }

    func makeClipDirectory() throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        try prepareLocked()
        let process = root.appendingPathComponent(processName, isDirectory: true)
        try requireOwnedDirectory(process, parent: root)
        let clip = process.appendingPathComponent("clip-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: clip, withIntermediateDirectories: false)
        return clip
    }

    /// Called only after a clip's reader has stopped. Failed removals remain
    /// queued so subsequent preparation/import retries cleanup before copying.
    func removeClipDirectory(_ directory: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        do {
            try removeCurrentClipLocked(directory)
            pendingCleanup.remove(directory)
        } catch {
            pendingCleanup.insert(directory)
            throw CoachImportWorkspaceError.cleanupFailed
        }
    }

    private func prepareLocked() throws {
        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            try requireOwnedDirectory(root, parent: root.deletingLastPathComponent())
            for clip in Array(pendingCleanup) {
                try removeCurrentClipLocked(clip)
                pendingCleanup.remove(clip)
            }
            if !prepared {
                for previous in try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
                    guard previous.lastPathComponent != processName,
                          Self.isOwnedName(previous.lastPathComponent, prefix: "process-"),
                          isOwnedDirectory(previous, parent: root) else { continue }
                    for clip in try manager.contentsOfDirectory(at: previous, includingPropertiesForKeys: nil) {
                        guard Self.isOwnedName(clip.lastPathComponent, prefix: "clip-"),
                              isOwnedDirectory(clip, parent: previous),
                              try hasNoSymbolicLinks(clip) else { continue }
                        try manager.removeItem(at: clip)
                    }
                    if try manager.contentsOfDirectory(atPath: previous.path).isEmpty {
                        try manager.removeItem(at: previous)
                    }
                }
            }
            // iOS can purge temporary storage while this process survives.
            // Recreate a missing process folder without pruning active clips.
            let process = root.appendingPathComponent(processName, isDirectory: true)
            if !manager.fileExists(atPath: process.path) {
                try manager.createDirectory(at: process, withIntermediateDirectories: false)
            }
            try requireOwnedDirectory(process, parent: root)
            prepared = true
        } catch {
            throw CoachImportWorkspaceError.cleanupFailed
        }
    }

    private func removeCurrentClipLocked(_ directory: URL) throws {
        let process = root.appendingPathComponent(processName, isDirectory: true)
        guard Self.isOwnedName(directory.lastPathComponent, prefix: "clip-"),
              directory.standardizedFileURL.deletingLastPathComponent().path == process.path else {
            throw CoachImportWorkspaceError.cleanupFailed
        }
        guard manager.fileExists(atPath: directory.path) else { return }
        try requireOwnedDirectory(root, parent: root.deletingLastPathComponent())
        try requireOwnedDirectory(process, parent: root)
        try requireOwnedDirectory(directory, parent: process)
        guard try hasNoSymbolicLinks(directory) else { throw CoachImportWorkspaceError.cleanupFailed }
        try manager.removeItem(at: directory)
    }

    private func isOwnedDirectory(_ url: URL, parent: URL) -> Bool {
        (try? requireOwnedDirectory(url, parent: parent)) != nil
    }

    private func requireOwnedDirectory(_ url: URL, parent: URL) throws {
        // Foundation caches resource values on Apple platforms. A cleanup retry
        // must inspect the current filesystem after a blocked path is repaired.
        var inspectedURL = url
        inspectedURL.removeAllCachedResourceValues()
        let values = try inspectedURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true,
              url.standardizedFileURL.deletingLastPathComponent().path == parent.standardizedFileURL.path,
              url.resolvingSymlinksInPath().path == url.standardizedFileURL.path else {
            throw CoachImportWorkspaceError.cleanupFailed
        }
    }

    private func hasNoSymbolicLinks(_ directory: URL) throws -> Bool {
        for child in try manager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ) {
            let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { return false }
            if values.isDirectory == true, try !hasNoSymbolicLinks(child) { return false }
        }
        return true
    }

    private static func isOwnedName(_ name: String, prefix: String) -> Bool {
        guard name.hasPrefix(prefix) else { return false }
        let suffix = String(name.dropFirst(prefix.count))
        return suffix.count == 36 && UUID(uuidString: suffix) != nil
    }
}

enum CoachImportWorkspaceError: LocalizedError {
    case cleanupFailed

    var errorDescription: String? {
        "Rally could not clear its temporary practice clips. Free some storage if needed, then retry. New analysis is paused until cleanup succeeds."
    }
}
