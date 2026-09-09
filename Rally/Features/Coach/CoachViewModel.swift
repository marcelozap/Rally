import Combine
import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class CoachViewModel: ObservableObject {
    enum Phase { case idle, importing, analyzing }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentReport: CoachReport?
    @Published private(set) var reports: [CoachReport] = []
    @Published private(set) var analysisError: String?
    @Published private(set) var historyError: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var isUpdatingHistory = false
    @Published private(set) var canRetry = false
    @Published var hittingHand: CoachHittingHand = .right
    @Published private(set) var lesson: CoachLessonSession?

    private let store: CoachReportStore
    let isMotionPreviewEnabled: Bool
    private var analysisTask: Task<Void, Never>?
    private var activeRun: UUID?
    private var lastSelection: PhotosPickerItem?

    init(store: CoachReportStore = CoachReportStore(), motionPreviewEnabled: Bool = CoachMotionFeature.isEnabled) {
        self.store = store
        self.isMotionPreviewEnabled = motionPreviewEnabled
    }

    var isBusy: Bool { phase != .idle }
    var isCurrentReportSaved: Bool {
        guard let currentReport else { return false }
        return reports.contains { $0.id == currentReport.id }
    }

    func analyze(_ item: PhotosPickerItem) {
        cancel()
        closeLesson()
        let runID = UUID()
        activeRun = runID
        lastSelection = item
        phase = .importing
        progress = 0
        analysisError = nil
        statusMessage = nil
        currentReport = nil
        canRetry = false

        let motionHand = isMotionPreviewEnabled ? hittingHand : nil

        analysisTask = Task { [weak self] in
            guard let self else { return }
            var imported: CoachImportedVideo?
            var review: CoachLessonSession?
            let observed = CoachFrameBuffer()
            do {
                let video = try await CoachVideoTransfer.load(from: item)
                imported = video
                try Task.checkCancellation()
                guard self.activeRun == runID else { throw CancellationError() }
                review = try await CoachLessonSession.make(video: video)
                self.phase = .analyzing
                let report = try await CoachVideoAnalyzer().analyze(
                    url: video.url,
                    sourceName: video.sourceName,
                    motionHand: motionHand,
                    onObservedFrames: { observed.set($0) },
                    onProgress: { [weak self] fraction in
                        Task { @MainActor [weak self] in
                            guard let self, self.activeRun == runID, self.phase == .analyzing else { return }
                            self.progress = min(1, max(self.progress, fraction.isFinite ? fraction : 0))
                        }
                    }
                )
                try Task.checkCancellation()
                guard self.activeRun == runID else { return }
                review?.frames = observed.get()
                self.lesson = review
                imported = nil
                self.currentReport = report
                self.progress = 1
                self.phase = .idle
                self.activeRun = nil
                self.analysisTask = nil
                self.canRetry = false
                self.lastSelection = nil
            } catch {
                var cleanupMessage: String?
                let canReviewManually = self.activeRun == runID && !(error is CancellationError)
                    && review != nil
                if canReviewManually {
                    self.lesson = review
                    imported = nil
                } else if let review {
                    do { try review.close() }
                    catch { cleanupMessage = error.localizedDescription }
                    imported = nil
                }
                if let imported {
                    do { try imported.removeTemporaryFile() }
                    catch { cleanupMessage = error.localizedDescription }
                }
                // A cancelled or superseded run may finish later, but may never
                // replace the new run's progress, result, or error message.
                guard self.activeRun == runID else {
                    // Keep maintenance failures visible without allowing an
                    // old task to replace the active analysis state or result.
                    if let cleanupMessage { self.historyError = cleanupMessage }
                    return
                }
                self.phase = .idle
                self.activeRun = nil
                self.analysisTask = nil
                self.canRetry = true
                if error is CancellationError {
                    self.statusMessage = cleanupMessage ?? "Analysis cancelled."
                } else {
                    self.analysisError = [error.localizedDescription, cleanupMessage]
                        .compactMap { $0 }.joined(separator: " ")
                }
            }
        }
    }

    func retry() {
        guard let lastSelection, !isBusy else { return }
        analyze(lastSelection)
    }

    func dismissAnalysisMessage() {
        analysisError = nil
        statusMessage = nil
    }

    func cancel() {
        lesson?.pause()
        guard isBusy else { return }
        activeRun = nil
        analysisTask?.cancel()
        analysisTask = nil
        phase = .idle
        progress = 0
        canRetry = lastSelection != nil
        statusMessage = "Analysis cancelled."
    }

    func loadHistory() async {
        guard !isUpdatingHistory else { return }
        isUpdatingHistory = true
        defer { isUpdatingHistory = false }
        do {
            // Also recover unfinished imports from a previous app process even
            // when history is unreadable. Disk cleanup runs off the UI executor.
            try await Task.detached(priority: .utility) {
                try CoachImportWorkspace.shared.prepare()
            }.value
            reports = try await store.load()
            historyError = nil
        } catch let error as CoachImportWorkspaceError {
            historyError = error.localizedDescription
        } catch {
            historyError = "Saved reports could not be loaded. Your existing history has been preserved. \(error.localizedDescription)"
        }
    }

    func show(_ report: CoachReport) {
        guard !isBusy else { return }
        closeLesson()
        currentReport = report
        statusMessage = nil
        analysisError = nil
        canRetry = false
    }

    func closeLesson() {
        guard let lesson else { return }
        do { try lesson.close() }
        catch { historyError = error.localizedDescription }
        self.lesson = nil
    }

    func saveCurrentReport() async {
        guard let report = currentReport, !isUpdatingHistory, !isCurrentReportSaved else { return }
        isUpdatingHistory = true
        defer { isUpdatingHistory = false }
        do {
            reports = try await store.save(report)
            historyError = nil
        } catch {
            historyError = "This report has not been saved. \(error.localizedDescription)"
        }
    }

    func delete(_ report: CoachReport) async {
        guard !isUpdatingHistory else { return }
        isUpdatingHistory = true
        defer { isUpdatingHistory = false }
        do {
            reports = try await store.delete(id: report.id)
            if currentReport?.id == report.id { currentReport = nil }
            historyError = nil
        } catch {
            historyError = "This report could not be deleted. \(error.localizedDescription)"
        }
    }
}
