#if DEBUG
import SwiftUI

/// In-game DEBUG-only sheet that lets a designer mutate `Tunables.live`
/// while the game is running. Surfaces the small curated set of feel
/// knobs touched by the v1 feel pass (frame-stops, shake, input commit
/// threshold, anticipation pulse lead, ball travel).
///
/// Triggered from `GameSessionView` by a 3-finger long-press anywhere on
/// the play surface — the gesture is intentionally awkward so a player
/// can't activate it accidentally.
struct TunablesOverlay: View {
    @Environment(\.dismiss) private var dismiss

    /// Local mirror of `Tunables.live` so the SwiftUI bindings drive a
    /// `@State` that we then push back into the global on every change.
    /// Avoids tying a singleton's lifecycle to SwiftUI observation.
    @State private var v: LiveTunables = Tunables.live

    var body: some View {
        NavigationStack {
            Form {
                Section("Frame-stop (ms)") {
                    slider("Perfect", value: $v.frameStopPerfectMs, range: 0...30, step: 1)
                    slider("Great",   value: $v.frameStopGreatMs,   range: 0...20, step: 1)
                    slider("Death",   value: $v.frameStopDeathMs,   range: 60...500, step: 10)
                }
                Section("Screen shake (points)") {
                    cgSlider("Perfect hit", value: $v.shakeAmplitudePerfect, range: 0...20, step: 0.5)
                    cgSlider("Death",       value: $v.shakeAmplitudeDeath,   range: 0...40, step: 1)
                }
                Section("Input") {
                    cgSlider("Commit distance", value: $v.swingMinDistance, range: 8...120, step: 2)
                }
                Section("Anticipation") {
                    slider("Strike pulse lead (ms)", value: $v.strikePulseLeadMs, range: 30...300, step: 10)
                }
                Section("Pacing") {
                    slider("Ball travel (s)", value: $v.ballTravelSeconds, range: 0.6...2.2, step: 0.05)
                }
                Section {
                    Button("Reset to defaults", role: .destructive) {
                        v = LiveTunables()
                        Tunables.live = v
                    }
                }
            }
            .navigationTitle("Live Tunables")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: v.frameStopPerfectMs) { _, _ in push() }
            .onChange(of: v.frameStopGreatMs)   { _, _ in push() }
            .onChange(of: v.frameStopDeathMs)   { _, _ in push() }
            .onChange(of: v.shakeAmplitudePerfect) { _, _ in push() }
            .onChange(of: v.shakeAmplitudeDeath)   { _, _ in push() }
            .onChange(of: v.swingMinDistance)      { _, _ in push() }
            .onChange(of: v.strikePulseLeadMs)     { _, _ in push() }
            .onChange(of: v.ballTravelSeconds)     { _, _ in push() }
        }
    }

    private func push() {
        Tunables.live = v
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func cgSlider(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat) -> some View {
        let doubleBinding = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = CGFloat($0) }
        )
        return slider(label, value: doubleBinding, range: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
    }
}
#endif
