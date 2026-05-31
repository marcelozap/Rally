#if DEBUG
import SwiftUI

/// In-game DEBUG-only sheet that lets a designer mutate `Tunables.live`
/// while the game is running. Surfaces the small curated set of feel
/// knobs touched by the v1 feel pass (frame-stops, shake, input commit
/// threshold, anticipation pulse lead, ball travel).
///
/// Triggered from `GameSessionView` by a 3-finger long-press anywhere on
/// the play surface -- the gesture is intentionally awkward so a player
/// can't activate it accidentally.
struct TunablesOverlay: View {
    @Environment(\.dismiss) private var dismiss

    /// Local mirror of `Tunables.live` so the SwiftUI bindings drive a
    /// `@State` that we then push back into the global on every change.
    /// Avoids tying a singleton's lifecycle to SwiftUI observation.
    @State private var v: LiveTunables = Tunables.live

    var body: some View {
        NavigationStack {
            ZStack {
                RallyUIKit.screenBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: RallyUIKit.Spacing.lg) {
                        heroPanel

                        tunableSection("Frame-stop", subtitle: "Shape the impact pause for contact highs and misses.") {
                            slider("Perfect", value: $v.frameStopPerfectMs, range: 0...30, step: 1)
                            slider("Great",   value: $v.frameStopGreatMs,   range: 0...20, step: 1)
                            slider("Death",   value: $v.frameStopDeathMs,   range: 60...500, step: 10)
                        }

                        tunableSection("Screen shake", subtitle: "Control how much the camera reacts to premium hits and collapses.") {
                            cgSlider("Perfect hit", value: $v.shakeAmplitudePerfect, range: 0...20, step: 0.5)
                            cgSlider("Death",       value: $v.shakeAmplitudeDeath,   range: 0...40, step: 1)
                        }

                        tunableSection("Input", subtitle: "Tune the distance needed before a swing locks in.") {
                            cgSlider("Commit distance", value: $v.swingMinDistance, range: 8...120, step: 2)
                        }

                        tunableSection("Anticipation", subtitle: "Lead the strike-line pulse earlier or later before contact.") {
                            slider("Strike pulse lead (ms)", value: $v.strikePulseLeadMs, range: 30...300, step: 10)
                        }

                        tunableSection("Pacing", subtitle: "Set the default travel time for live rally balls.") {
                            slider("Ball travel (s)", value: $v.ballTravelSeconds, range: 0.6...2.2, step: 0.05)
                        }

                        resetPanel
                    }
                    .padding(.horizontal, RallyUIKit.Spacing.md)
                    .padding(.vertical, RallyUIKit.Spacing.lg)
                    .padding(.bottom, RallyUIKit.Spacing.xl)
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
            .onChange(of: v.frameStopGreatMs) { _, _ in push() }
            .onChange(of: v.frameStopDeathMs) { _, _ in push() }
            .onChange(of: v.shakeAmplitudePerfect) { _, _ in push() }
            .onChange(of: v.shakeAmplitudeDeath) { _, _ in push() }
            .onChange(of: v.swingMinDistance) { _, _ in push() }
            .onChange(of: v.strikePulseLeadMs) { _, _ in push() }
            .onChange(of: v.ballTravelSeconds) { _, _ in push() }
        }
    }

    private func push() {
        Tunables.live = v
    }

    private var heroPanel: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                HStack {
                    RallyUIKit.EditorialEyebrow(text: "Debug", tint: RallyUIKit.Palette.cyan)
                    Spacer()
                    capsule("Live match")
                }

                Text("Live tunables")
                    .font(RallyUIKit.Typography.display(30))
                    .foregroundStyle(RallyUIKit.Palette.frost)

                Text("These controls write directly into `Tunables.live`, so every adjustment updates the match immediately.")
                    .font(RallyUIKit.Typography.body(.body))
                    .foregroundStyle(RallyUIKit.Palette.cloud)
            }
        }
    }

    private var resetPanel: some View {
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.gold.opacity(0.22)) {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
                HStack {
                    Text("Reset the feel pass")
                        .font(RallyUIKit.Typography.title(.headline))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.gold)
                }

                Text("Return every debug control to the current default Rally baseline.")
                    .font(RallyUIKit.Typography.body(.body))
                    .foregroundStyle(RallyUIKit.Palette.cloud)

                Button("Reset to defaults", role: .destructive) {
                    v = LiveTunables()
                    Tunables.live = v
                }
                .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.gold))
            }
        }
    }

    @ViewBuilder
    private func tunableSection<Content: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        RallyUIKit.SectionCard {
            VStack(alignment: .leading, spacing: RallyUIKit.Spacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(RallyUIKit.Typography.title(.headline))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Text(subtitle)
                        .font(RallyUIKit.Typography.body(.caption))
                        .foregroundStyle(RallyUIKit.Palette.cloud)
                }

                content()
            }
        }
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(RallyUIKit.Typography.body(.body, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(RallyUIKit.Palette.cyan)
            }
            Slider(value: value, in: range, step: step)
                .tint(RallyUIKit.Palette.cyan)
        }
        .padding(RallyUIKit.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md, style: .continuous)
                .stroke(RallyUIKit.Palette.cyan.opacity(0.12), lineWidth: 1)
        )
    }

    private func cgSlider(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat) -> some View {
        let doubleBinding = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = CGFloat($0) }
        )
        return slider(
            label,
            value: doubleBinding,
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(step)
        )
    }

    private func capsule(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(RallyUIKit.Palette.cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(RallyUIKit.Palette.cyan.opacity(0.12))
            )
    }
}
#endif
