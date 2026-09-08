import SwiftUI

/// Kept off in ordinary builds until real-clip and device validation is complete.
enum CoachMotionFeature {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-RallyCoachMotionPreview")
        #else
        false
        #endif
    }
}

struct CoachMotionTimelineView: View {
    let review: CoachMotionReview
    @State private var selectedIndex = 0.0

    private var selected: CoachMotionSample? {
        guard !review.samples.isEmpty else { return nil }
        return review.samples[min(review.samples.count - 1, max(0, Int(selectedIndex)))]
    }
    private var scaleMaximum: Double { max(0.1, max(review.rawPeak ?? 0, review.filteredPeak ?? 0) * 1.1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Arm movement timeline")
                .font(RallyUIKit.Typography.title(.title2))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Text("\(review.hand.title) wrist relative to \(review.hand.rawValue) shoulder")
                .font(RallyUIKit.Typography.body(.subheadline))
            Text("Experimental review · 10 samples per second")
                .font(RallyUIKit.Typography.label(.caption))
                .foregroundStyle(RallyUIKit.Palette.gold)
            chart
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Arm movement timeline. Original and smoothed tracking, in frame heights per second. Shaded intervals have missing or limited tracking. Use the timestamp slider to inspect samples.")
            Text("Shaded intervals: missing or limited tracking. Gaps are not zero movement.")
                .font(RallyUIKit.Typography.body(.caption))
            if review.samples.count > 1 {
                Slider(value: $selectedIndex, in: 0...Double(review.samples.count - 1), step: 1)
                    .accessibilityLabel("Review timestamp")
                    .accessibilityValue(selected.map { String(format: "%.2f seconds, %@", $0.timestamp, $0.status.title) } ?? "Unavailable")
            }
            if let sample = selected {
                Text("\(sample.timestamp.formatted(.number.precision(.fractionLength(2)))) s · \(sample.status.title)")
                    .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                    .foregroundStyle(sample.status == .tracked ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold)
                Text("Smoothed: \(value(sample.velocity))\nOriginal: \(value(sample.rawVelocity))")
                    .font(RallyUIKit.Typography.body(.subheadline))
                    .monospacedDigit()
                Text("Acceleration: \(sample.acceleration.map { String(format: "%.2f frame heights/s²", $0.magnitude) } ?? "Unavailable until two continuous velocity samples exist")")
                    .font(RallyUIKit.Typography.body(.caption))
            }
            if !review.peaks.isEmpty {
                Text("Increased tracked arm movement")
                    .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                ForEach(review.peaks) { peak in
                    Button {
                        selectedIndex = Double(review.samples.firstIndex(where: { $0.timestamp == peak.timestamp }) ?? 0)
                    } label: {
                        Label("Review near \(peak.timestamp.formatted(.number.precision(.fractionLength(2)))) s", systemImage: "waveform.path")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
            }
            Text("Use these timestamps in your original video. Peaks describe increased tracked arm movement, not ball contact, racket speed, or technique quality. At 10 Hz, fast movement between frames can be missed; smoothing cannot recover it.")
                .font(RallyUIKit.Typography.body(.caption))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(RallyUIKit.Palette.cloud)
        .onChange(of: review) { _, _ in selectedIndex = 0 }
        .accessibilityIdentifier("coach.motionTimeline")
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Frame heights/s · top \(scaleMaximum.formatted(.number.precision(.fractionLength(2))))")
                .font(.caption2)
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    ForEach(0..<3) { index in
                        Path { path in
                            let y = geometry.size.height * CGFloat(index) / 2
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(RallyUIKit.Palette.cloud.opacity(0.15), lineWidth: 1)
                    }
                    ForEach(review.samples) { sample in
                        if sample.status != .tracked {
                            Rectangle()
                                .fill(RallyUIKit.Palette.gold.opacity(sample.velocity == nil ? 0.22 : 0.1))
                                .frame(width: max(1, (sample.timestamp - sample.intervalStart) / review.duration * geometry.size.width))
                                .offset(x: sample.intervalStart / review.duration * geometry.size.width)
                        }
                    }
                    motionPath(size: geometry.size, original: true)
                        .stroke(RallyUIKit.Palette.cloud.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    motionPath(size: geometry.size, original: false)
                        .stroke(RallyUIKit.Palette.cyan, lineWidth: 2)
                    if let selected {
                        Rectangle().fill(RallyUIKit.Palette.frost.opacity(0.6))
                            .frame(width: 1)
                            .offset(x: selected.timestamp / review.duration * geometry.size.width)
                    }
                }
                .clipped()
            }
            HStack {
                Text("0 s")
                Spacer()
                Text("\(review.duration.formatted(.number.precision(.fractionLength(2)))) s")
            }
            .font(.caption2.monospacedDigit())
            HStack(spacing: 14) {
                Label("Original", systemImage: "line.diagonal").foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.65))
                Label("Smoothed", systemImage: "line.diagonal").foregroundStyle(RallyUIKit.Palette.cyan)
            }
            .font(.caption)
        }
    }

    private func motionPath(size: CGSize, original: Bool) -> Path {
        Path { path in
            var previous: CoachMotionSample?
            for sample in review.samples {
                guard let vector = original ? sample.rawVelocity : sample.velocity else {
                    previous = nil
                    continue
                }
                let point = CGPoint(x: sample.timestamp / review.duration * size.width,
                                    y: (1 - vector.magnitude / scaleMaximum) * size.height)
                if previous?.segment == sample.segment { path.addLine(to: point) }
                else { path.move(to: point) }
                previous = sample
            }
        }
    }

    private func value(_ vector: CoachMotionVector?) -> String {
        vector.map { String(format: "%.2f frame heights/s", $0.magnitude) } ?? "Unavailable"
    }
}
