import SwiftUI

enum RallyPlayMode: String, CaseIterable, Identifiable {
    case rallyChallenge, cleanEight, servePractice, targetPractice, copyCoach
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rallyChallenge: return "Rally Challenge"
        case .cleanEight: return RallyChallenge.cleanEight.title
        case .servePractice: return "Serve Practice"
        case .targetPractice: return "Target Practice"
        case .copyCoach: return "Copy the Coach"
        }
    }
    var cue: String {
        switch self {
        case .rallyChallenge: return "Serve, then keep it going for 20 seconds."
        case .cleanEight: return "Finish 20 seconds with an eight-shot streak."
        case .servePractice: return "Ten serves. Swipe up at the top of the toss."
        case .targetPractice: return "Ten shots. Angle your swipe toward the ring."
        case .copyCoach: return "Watch the example. Replay your attempt. Try again."
        }
    }
    var icon: String {
        switch self {
        case .rallyChallenge: return "tennisball.fill"
        case .cleanEight: return "8.circle.fill"
        case .servePractice: return "figure.tennis"
        case .targetPractice: return "scope"
        case .copyCoach: return "play.rectangle"
        }
    }
    var isTargetMode: Bool { self == .servePractice || self == .targetPractice }
    var challenge: RallyChallenge? { self == .cleanEight ? .cleanEight : nil }
}

struct RallyPlayHubView: View {
    var onExit: () -> Void
    @State private var selected: RallyPlayMode?
    @State private var challengeBest = 0
    @State private var challengeClears = 0
    var body: some View {
        Group {
            if let selected, selected != .copyCoach {
                GameSessionView(mode: selected, onExit: { self.selected = nil })
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ON COURT")
                                    .font(.system(size: 11, weight: .bold)).tracking(3)
                                    .foregroundStyle(RallyUIKit.Palette.cyan)
                                Text("Make your next\nshot count.")
                                    .font(RallyUIKit.Typography.display(38, weight: .medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("A quick rally or a little focused practice.")
                                    .font(.subheadline)
                                    .foregroundStyle(RallyUIKit.Palette.cloud)
                            }
                            .padding(.vertical, 14)
                            ForEach(RallyPlayMode.allCases) { mode in
                                if mode == .copyCoach {
                                    NavigationLink { CoachView() } label: { modeCard(mode) }
                                        .buttonStyle(.plain)
                                } else {
                                    Button { selected = mode } label: { modeCard(mode) }.buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(20)
                    }
                    .background(RallyUIKit.screenBackground)
                    .foregroundStyle(RallyUIKit.Palette.frost)
                    .navigationTitle("Play")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close", action: onExit) } }
                }
            }
        }
        .onAppear {
            refreshChallengeRecord()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-RallyAutoPlay") || ProcessInfo.processInfo.arguments.contains("-RallyStartGame") {
                selected = ProcessInfo.processInfo.arguments.contains("-RallyCleanEight") ? .cleanEight : .rallyChallenge
            }
            #endif
        }
        .onChange(of: selected) { _, value in
            if value == nil { refreshChallengeRecord() }
        }
    }
    private func refreshChallengeRecord() {
        let record = RallyChallengeStore().record(for: .cleanEight)
        challengeBest = record.bestStreak
        challengeClears = record.completions
    }
    private func modeCard(_ mode: RallyPlayMode) -> some View {
        let featured = mode == .rallyChallenge
        return HStack(spacing: 16) {
            Image(systemName: mode.icon)
                .font(.system(size: featured ? 30 : 22, weight: .medium))
                .foregroundStyle(featured ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.cyan)
                .frame(width: 58, height: 64)
                .background(RoundedRectangle(cornerRadius: 18)
                    .fill(featured ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.cyan.opacity(0.09)))
            VStack(alignment: .leading, spacing: 7) {
                Text(mode == .cleanEight ? "STREAK CHALLENGE" : featured ? "20 SECONDS · YOUR DOUBLE" : mode == .copyCoach ? "WATCH & REPEAT" : "10 ATTEMPTS")
                    .font(.system(size: 9, weight: .bold)).tracking(1.3)
                    .foregroundStyle(RallyUIKit.Palette.cyan)
                Text(mode.title)
                    .font(RallyUIKit.Typography.display(featured ? 25 : 22, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(mode.cue)
                    .font(.system(size: 13))
                    .foregroundStyle(RallyUIKit.Palette.cloud)
                    .fixedSize(horizontal: false, vertical: true)
                if mode == .cleanEight, challengeBest > 0 {
                    Text("Best streak \(challengeBest) · \(challengeClears) clears")
                        .font(.caption).foregroundStyle(RallyUIKit.Palette.cyan)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cyan)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: featured ? 148 : 124, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24)
            .fill(LinearGradient(colors: [RallyUIKit.Palette.slate.opacity(featured ? 1 : 0.65), RallyUIKit.Palette.ink],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 24)
            .stroke(featured ? RallyUIKit.Palette.cyan.opacity(0.35) : RallyUIKit.Palette.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("playMode.\(mode.rawValue)")
    }

}

struct RallyServeIntroduction: View {
    let appearance: RallyAvatarAppearance
    let leftHanded: Bool
    var onStart: () -> Void
    @State private var playing = false
    @State private var startedAt = Date()
    var body: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(spacing: 14) {
                Text("Prepare. Toss. Serve.").font(.title2.bold())
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing)) { context in
                    let progress = playing ? context.date.timeIntervalSince(startedAt).truncatingRemainder(dividingBy: 4) / 4 : 0
                    CoachDemonstrator(appearance: appearance, progress: Float(progress), leftHanded: leftHanded, serve: true)
                        .frame(height: 280)
                }
                Text("Game demonstration. Swipe up near the top of the toss; angle your swipe toward the ring.")
                    .font(.subheadline).multilineTextAlignment(.center)
                Button(playing ? "Stop example" : "Watch slow example") { startedAt = Date(); playing.toggle() }
                    .buttonStyle(.bordered)
                Button("Start serving", action: onStart).buttonStyle(.borderedProminent)
            }.foregroundStyle(RallyUIKit.Palette.frost)
        }
    }
}
