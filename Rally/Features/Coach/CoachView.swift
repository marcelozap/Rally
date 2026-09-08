import PhotosUI
import SwiftUI

/// Pushed from Home or Training's existing NavigationStack.
@MainActor
struct CoachView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = CoachViewModel()
    @State private var selection: PhotosPickerItem?
    @State private var reportToDelete: CoachReport?

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    if model.isBusy { analysisProgress }
                    if let error = model.analysisError {
                        messageCard(title: "Couldn’t analyze this clip", message: error, isError: true)
                    } else if let message = model.statusMessage {
                        messageCard(title: "Analysis stopped", message: message, isError: false)
                    }
                    if let report = model.currentReport {
                        reportCard(report)
                            .id("coach-result")
                    }
                    filmingGuide
                    history
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .onChange(of: model.currentReport?.id) { _, id in
                if id != nil {
                    withAnimation { scroll.scrollTo("coach-result", anchor: .top) }
                }
            }
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle("Rally Coach")
        .navigationBarTitleDisplayMode(.inline)
        .tint(RallyUIKit.Palette.cyan)
        .task { await model.loadHistory() }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            model.analyze(item)
            // Allow choosing the same Photos item again after cancellation.
            selection = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.cancel() }
        }
        .onDisappear { model.cancel() }
        .alert("Delete saved report?", isPresented: Binding(
            get: { reportToDelete != nil },
            set: { if !$0 { reportToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { reportToDelete = nil }
            Button("Delete report", role: .destructive) {
                guard let report = reportToDelete else { return }
                reportToDelete = nil
                Task { await model.delete(report) }
            }
        } message: {
            Text("This removes the report from this iPhone.")
        }
    }

    private var introduction: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: 16) {
                RallyUIKit.EditorialEyebrow(text: "Practice review · Preview", tint: RallyUIKit.Palette.cyan)
                Text("See your practice\nin motion.")
                    .font(RallyUIKit.Typography.title(.largeTitle))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Choose a short clip for movement ranges and filming feedback.")
                    .font(RallyUIKit.Typography.body(.subheadline))
                    .foregroundStyle(RallyUIKit.Palette.cloud)
                PhotosPicker(
                    selection: $selection,
                    matching: .videos,
                    preferredItemEncoding: .current
                ) {
                    Label("Choose practice video", systemImage: "video.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(tint: RallyUIKit.Palette.cyan))
                .disabled(model.isBusy)
                .opacity(model.isBusy ? 0.55 : 1)
                Text("2–60 seconds · Up to 250 MB")
                    .font(RallyUIKit.Typography.label(.caption))
                    .foregroundStyle(RallyUIKit.Palette.cloud)
                Text("Analyzed on your iPhone. Only reports are saved.")
                    .font(RallyUIKit.Typography.body(.caption))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
            }
        }
    }

    private var analysisProgress: some View {
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.cyan.opacity(0.25)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.phase == .importing ? "Preparing video" : "Reading movement")
                        .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Spacer(minLength: 8)
                    Button("Cancel") { model.cancel() }
                        .font(RallyUIKit.Typography.label(.subheadline))
                        .frame(minHeight: 44)
                }
                if model.phase == .importing {
                    ProgressView()
                    Text("If the clip is in iCloud, Photos will download it first. Keep Rally open while it prepares.")
                        .font(RallyUIKit.Typography.body(.caption))
                        .foregroundStyle(RallyUIKit.Palette.cloud)
                } else {
                    ProgressView(value: model.progress)
                        .accessibilityLabel("Movement analysis")
                    Text("\(Int(model.progress * 100))% · Keep Rally open until the review is ready.")
                        .font(RallyUIKit.Typography.body(.caption))
                        .foregroundStyle(RallyUIKit.Palette.cloud)
                }
            }
        }
    }

    private func messageCard(title: String, message: String, isError: Bool) -> some View {
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.gold.opacity(0.28)) {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: isError ? "exclamationmark.circle" : "pause.circle")
                    .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.gold)
                Text(message)
                    .font(RallyUIKit.Typography.body(.subheadline))
                    .foregroundStyle(RallyUIKit.Palette.cloud)
                if model.canRetry {
                    Button("Try this clip again") { model.retry() }
                        .font(RallyUIKit.Typography.label(.subheadline))
                        .frame(minHeight: 44)
                }
            }
        }
    }

    private func reportCard(_ report: CoachReport) -> some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: 18) {
                RallyUIKit.EditorialEyebrow(text: "Your practice review", tint: RallyUIKit.Palette.cyan)
                Text(report.createdAt, format: .dateTime.month(.wide).day().hour().minute())
                    .font(RallyUIKit.Typography.title(.title2))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(report.sourceFilename)
                    .font(RallyUIKit.Typography.body(.caption))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                    .lineLimit(2)
                VStack(alignment: .leading, spacing: 6) {
                    Label(report.quality.title, systemImage: "viewfinder")
                        .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                        .foregroundStyle(report.quality == .sufficient ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold)
                    Text("Tracked in \(report.trackedFrameCount) of \(report.sampledFrameCount) sampled frames · \(report.duration.formatted(.number.precision(.fractionLength(1)))) sec clip")
                        .font(RallyUIKit.Typography.body(.caption))
                        .foregroundStyle(RallyUIKit.Palette.cloud)
                }
                ForEach(report.metrics) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(metric.title)
                            .font(RallyUIKit.Typography.label(.subheadline))
                            .foregroundStyle(RallyUIKit.Palette.cloud)
                        Text(metric.value)
                            .font(RallyUIKit.Typography.title(.title2))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text(metric.detail)
                            .font(RallyUIKit.Typography.body(.caption))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.045)))
                }
                ForEach(Array(report.notes.enumerated()), id: \.offset) { _, note in
                    Text(note)
                        .font(RallyUIKit.Typography.body(.subheadline))
                        .foregroundStyle(RallyUIKit.Palette.cloud)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    Task { await model.saveCurrentReport() }
                } label: {
                    Label(
                        model.isCurrentReportSaved ? "Saved on this iPhone" : "Save report",
                        systemImage: model.isCurrentReportSaved ? "checkmark.circle" : "bookmark"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(tint: RallyUIKit.Palette.cyan))
                .disabled(model.isCurrentReportSaved || model.isUpdatingHistory)
            }
        }
    }

    private var filmingGuide: some View {
        RallyUIKit.SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("For a clearer review", systemImage: "camera.viewfinder")
                    .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text("Film one player, head to toe, with a steady camera and good light. Keep the same camera angle when comparing clips.")
                    .font(RallyUIKit.Typography.body(.subheadline))
                    .foregroundStyle(RallyUIKit.Palette.cloud)
                Text("Movement ranges are estimates from the video image. They don’t measure ball speed, shot quality, or a tennis skill score.")
                    .font(RallyUIKit.Typography.body(.caption))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            RallyUIKit.EditorialEyebrow(text: "Saved on this iPhone", tint: RallyUIKit.Palette.cloud)
            if let error = model.historyError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error)
                        .font(RallyUIKit.Typography.body(.subheadline))
                        .foregroundStyle(RallyUIKit.Palette.gold)
                    Button("Reload saved reports") {
                        Task { await model.loadHistory() }
                    }
                    .frame(minHeight: 44)
                    .disabled(model.isUpdatingHistory)
                }
            }
            if model.isUpdatingHistory { ProgressView().accessibilityLabel("Updating saved reports") }
            if model.reports.isEmpty && model.historyError == nil && !model.isUpdatingHistory {
                Text("Save a review to return to it after practice. Your videos are not added to Coach history.")
                    .font(RallyUIKit.Typography.body(.subheadline))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
            }
            ForEach(model.reports) { report in
                RallyUIKit.SectionCard {
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            model.show(report)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(report.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                                    .foregroundStyle(RallyUIKit.Palette.frost)
                                Text(report.quality.title)
                                    .font(RallyUIKit.Typography.body(.caption))
                                    .foregroundStyle(RallyUIKit.Palette.cloud)
                                Text(report.sourceFilename)
                                    .font(RallyUIKit.Typography.body(.caption2))
                                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.7))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isBusy)
                        .accessibilityHint("Opens the saved movement review")
                        Button(role: .destructive) {
                            reportToDelete = report
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 44, height: 44)
                                .foregroundStyle(RallyUIKit.Palette.coral)
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isUpdatingHistory || model.isBusy)
                        .accessibilityLabel("Delete report from \(report.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
            }
        }
    }
}
