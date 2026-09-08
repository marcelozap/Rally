import Foundation

/// Device-local reports only. Raw video and pose frames never enter this store.
/// The actor serializes read/modify/write operations; a failed read cannot be
/// mistaken for an empty history and overwritten by the next save.
actor CoachReportStore {
    private let directory: URL?
    private let fileManager = FileManager.default

    init(directory: URL? = nil) {
        self.directory = directory
    }

    func load() throws -> [CoachReport] {
        let fileURL = try reportFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        guard let size = attributes[.size] as? NSNumber, size.int64Value <= 10_000_000 else {
            throw CoachReportStorageError.invalidHistory
        }
        let reports = try JSONDecoder().decode([CoachReport].self, from: Data(contentsOf: fileURL))
        guard Set(reports.map(\.id)).count == reports.count else {
            throw CoachReportStorageError.invalidHistory
        }
        for report in reports { try report.validate() }
        return reports.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func save(_ report: CoachReport) throws -> [CoachReport] {
        try report.validate()
        var reports = try load()
        reports.removeAll { $0.id == report.id }
        reports.append(report)
        reports.sort { $0.createdAt > $1.createdAt }
        try write(reports)
        return reports
    }

    @discardableResult
    func delete(id: UUID) throws -> [CoachReport] {
        var reports = try load()
        reports.removeAll { $0.id == id }
        try write(reports)
        return reports
    }

    private func write(_ reports: [CoachReport]) throws {
        let data = try JSONEncoder().encode(reports)
        guard data.count <= 10_000_000 else { throw CoachReportStorageError.historyFull }
        let fileURL = try reportFileURL()
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }

    private func reportFileURL() throws -> URL {
        let base: URL
        if let directory {
            base = directory
        } else {
            base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("RallyCoach", isDirectory: true)
        }
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        // Exclude the entire directory before writing. Atomic replacement then
        // remains excluded too; Coach history is never part of app cloud sync.
        #if os(iOS) || os(macOS)
        var directoryURL = base
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directoryURL.setResourceValues(values)
        #endif
        return base.appendingPathComponent("reports.json")
    }
}

enum CoachReportStorageError: LocalizedError {
    case invalidHistory
    case historyFull

    var errorDescription: String? {
        switch self {
        case .invalidHistory:
            return "Saved Coach reports could not be read. Your existing history has been preserved."
        case .historyFull:
            return "Coach history is full. Delete an older report before saving another."
        }
    }
}
