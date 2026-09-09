import SwiftUI

enum RallyPlayMode: String, CaseIterable, Identifiable {
    case rallyChallenge, servePractice, targetPractice, copyCoach
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rallyChallenge: return "Rally Challenge"
        case .servePractice: return "Serve Practice"
        case .targetPractice: return "Target Practice"
        case .copyCoach: return "Copy the Coach"
        }
    }
    var cue: String {
        switch self {
        case .rallyChallenge: return "Serve, then keep it going for 20 seconds."
        case .servePractice: return "Ten serves. Swipe up at the top of the toss."
        case .targetPractice: return "Ten shots. Angle your swipe toward the ring."
        case .copyCoach: return "Watch the example. Replay your attempt. Try again."
        }
    }
    var icon: String {
        switch self {
        case .rallyChallenge: return "tennisball.fill"
        case .servePractice: return "figure.tennis"
        case .targetPractice: return "scope"
        case .copyCoach: return "play.rectangle"
        }
    }
    var isTargetMode: Bool { self == .servePractice || self == .targetPractice }
}

struct RallyPlayHubView: View {
    var onExit: () -> Void
    @State private var selected: RallyPlayMode?
    var body: some View {
        Group {
            if let selected, selected != .copyCoach {
                GameSessionView(mode: selected, onExit: { self.selected = nil })
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Find your next rally.").font(RallyUIKit.Typography.title(.largeTitle))
                            Text("Fun tennis mini-games, swipe timing, your player and your style.")
                                .foregroundStyle(RallyUIKit.Palette.cloud)
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
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-RallyAutoPlay") || ProcessInfo.processInfo.arguments.contains("-RallyStartGame") {
                selected = .rallyChallenge
            }
            #endif
        }
    }
    private func modeCard(_ mode: RallyPlayMode) -> some View {
        RallyUIKit.SectionCard {
            HStack(spacing: 14) {
                Image(systemName: mode.icon).font(.title2).foregroundStyle(RallyUIKit.Palette.cyan)
                VStack(alignment: .leading, spacing: 6) {
                    Text(mode.title).font(.headline)
                    Text(mode.cue).font(.subheadline).foregroundStyle(RallyUIKit.Palette.cloud)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
            }
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        }
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
