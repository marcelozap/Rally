import AVFoundation
import AVKit
import SceneKit
import SwiftUI

/// Worker-to-UI handoff without scheduling an unowned UI callback after analysis.
final class CoachFrameBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [CoachPoseFrame] = []
    func set(_ value: [CoachPoseFrame]) { lock.lock(); frames = value; lock.unlock() }
    func get() -> [CoachPoseFrame] { lock.lock(); defer { lock.unlock() }; return frames }
}

enum CoachOutline {
    static let links: [(CoachJoint, CoachJoint)] = [
        (.leftShoulder, .rightShoulder), (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist), (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist), (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip), (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    /// No interpolation, guessed missing joints, mirrored coordinates or stale poses.
    static func points(at time: Double, frames: [CoachPoseFrame]) -> [CoachJoint: CoachKeypoint] {
        guard time.isFinite,
              let frame = frames.min(by: { abs($0.timestamp - time) < abs($1.timestamp - time) }),
              frame.timestamp.isFinite, abs(frame.timestamp - time) <= 0.055 else { return [:] }
        let points = frame.points.filter {
            $0.value.confidence.isFinite && $0.value.confidence >= 0.6 &&
            $0.value.x.isFinite && $0.value.y.isFinite && $0.value.x >= 0 &&
            (0...1).contains($0.value.y)
        }
        guard [.leftShoulder, .rightShoulder, .leftHip, .rightHip].allSatisfy({ points[$0] != nil }) else { return [:] }
        return points
    }
}

/// Owns the temporary movie while this review is open, never in report history.
@MainActor
final class CoachLessonSession: ObservableObject {
    let video: CoachImportedVideo
    let player: AVPlayer
    let duration: Double
    let aspectRatio: Double
    @Published var frames: [CoachPoseFrame] = []
    @Published private(set) var time: Double = 0
    @Published private(set) var isPlaying = false
    @Published var slow = false
    @Published var loops = true
    @Published var loopStart: Double = 0
    private var observer: Any?
    private var seekGeneration = 0
    private var isSeeking = false
    private var closed = false

    var loopEnd: Double { min(duration, loopStart + 4) }
    var exampleProgress: Float { Float(min(1, max(0, (time - loopStart) / max(0.1, loopEnd - loopStart)))) }

    static func make(video: CoachImportedVideo) async throws -> CoachLessonSession {
        let asset = AVURLAsset(url: video.url)
        let duration = try await asset.load(.duration).seconds
        try CoachVideoAnalyzer.validateDuration(duration)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw CoachVideoAnalysisError.unsupportedVideo
        }
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let rect = CGRect(origin: .zero, size: size).applying(transform)
        guard abs(rect.width) > 0, abs(rect.height) > 0 else { throw CoachVideoAnalysisError.unsupportedVideo }
        try Task.checkCancellation()
        return CoachLessonSession(video: video, duration: duration, aspectRatio: abs(rect.width / rect.height))
    }

    private init(video: CoachImportedVideo, duration: Double, aspectRatio: Double) {
        self.video = video
        self.duration = duration
        self.aspectRatio = aspectRatio
        player = AVPlayer(url: video.url)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1.0 / 30, preferredTimescale: 600), queue: .main) { [weak self] value in
            Task { @MainActor [weak self] in self?.tick(value.seconds) }
        }
    }

    private func tick(_ seconds: Double) {
        guard !closed, !isSeeking, seconds.isFinite else { return }
        time = min(duration, max(0, seconds))
        guard isPlaying else { return }
        if loops && time >= loopEnd - 0.035 {
            seek(to: loopStart, resume: true)
        } else if time >= duration - 0.04 {
            pause()
        }
    }

    func togglePlayback() {
        if isPlaying { pause(); return }
        guard !closed else { return }
        if time >= (loops ? loopEnd : duration) - 0.05 {
            seek(to: loops ? loopStart : 0, resume: true)
        } else {
            isPlaying = true
            player.playImmediately(atRate: slow ? 0.5 : 1)
        }
    }

    func pause() {
        seekGeneration += 1
        isPlaying = false
        player.pause()
    }

    func setSpeed() {
        if isPlaying { player.rate = slow ? 0.5 : 1 }
    }

    func seek(to seconds: Double, resume: Bool = false) {
        guard !closed, seconds.isFinite else { return }
        seekGeneration += 1
        let generation = seekGeneration
        isSeeking = true
        player.pause()
        isPlaying = resume
        time = min(duration, max(0, seconds))
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor [weak self] in
                guard let self, !self.closed else { return }
                self.isSeeking = false
                guard finished, generation == self.seekGeneration, self.isPlaying else { return }
                self.player.playImmediately(atRate: self.slow ? 0.5 : 1)
            }
        }
    }

    func close() throws {
        guard !closed else { return }
        pause()
        closed = true
        if let observer { player.removeTimeObserver(observer); self.observer = nil }
        player.replaceCurrentItem(with: nil)
        frames = []
        try video.removeTemporaryFile()
    }

    deinit {
        if let observer { player.removeTimeObserver(observer) }
        // CoachImportedVideo's lifetime is the final cleanup backstop.
    }
}

private struct CoachMovieSurface: UIViewRepresentable {
    let player: AVPlayer
    final class Surface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var movieLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
    func makeUIView(context: Context) -> Surface {
        let view = Surface()
        view.movieLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }
    func updateUIView(_ view: Surface, context: Context) { view.movieLayer.player = player }
    static func dismantleUIView(_ view: Surface, coordinator: ()) { view.movieLayer.player = nil }
}

/// Uses the actual Rally mesh, wardrobe and rig, not a separate drawing of a player.
struct CoachDemonstrator: UIViewRepresentable {
    var appearance: RallyAvatarAppearance
    var progress: Float
    var leftHanded: Bool
    var sideView: Bool = false
    var serve: Bool = false

    final class Surface: SCNView { var rig: RallyAvatarRig? }
    func makeUIView(context: Context) -> Surface {
        let view = Surface()
        let rig = RallyAvatarRig(appearance: appearance, presentation: .studio)
        view.rig = rig
        view.scene = rig.scene
        view.pointOfView = rig.camera
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.isPlaying = false
        return view
    }
    func updateUIView(_ view: Surface, context: Context) {
        guard let rig = view.rig else { return }
        rig.apply(appearance)
        rig.animateLesson(progress: progress, leftHanded: leftHanded, serve: serve,
                          viewingYaw: sideView ? .pi / 2 : 0)
        view.setNeedsDisplay()
    }
    static func dismantleUIView(_ view: Surface, coordinator: ()) { view.scene = nil; view.rig = nil }
}

@MainActor
struct CoachVisualLesson: View {
    @ObservedObject var model: CoachViewModel
    @State private var girl = false
    @State private var sideView = false
    @State private var examplePlaying = false
    @State private var exampleTime: Double = 0
    @State private var lastTick: Date?
    @State private var slowExample = false
    private let clock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    private var appearance: RallyAvatarAppearance {
        RallyAvatarAppearance(athletePreset: girl ? .femaleEuropean : .maleEuropean)
    }

    var body: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: 16) {
                RallyUIKit.EditorialEyebrow(text: "Watch. Try. Repeat.", tint: RallyUIKit.Palette.cyan)
                if let session = model.lesson {
                    CoachComparison(session: session, appearance: appearance, leftHanded: model.hittingHand == .left,
                                    sideView: sideView)
                } else {
                    Text("Try this")
                        .font(RallyUIKit.Typography.title(.title2))
                    CoachDemonstrator(appearance: appearance, progress: Float(exampleTime / 4),
                                      leftHanded: model.hittingHand == .left, sideView: sideView)
                        .frame(height: 320)
                        .background(RoundedRectangle(cornerRadius: 22).fill(
                            LinearGradient(colors: [RallyUIKit.Palette.slate, RallyUIKit.Palette.ink],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .overlay(alignment: .topLeading) {
                            Label("MOVEMENT STUDIO", systemImage: "figure.tennis")
                                .font(.system(size: 9, weight: .bold)).tracking(1.5)
                                .foregroundStyle(RallyUIKit.Palette.cloud).padding(16)
                        }
                        .accessibilityLabel("Practice example: soften your knees, then return to ready")
                    HStack {
                        Button(examplePlaying ? "Pause example" : "Play example") { examplePlaying.toggle(); lastTick = nil }
                        Button(slowExample ? "Speed: half" : "Speed: normal") { slowExample.toggle() }
                    }
                    .buttonStyle(.bordered)
                    Text("Choose your video below to watch the two movements together.")
                        .font(.subheadline)
                }
                Picker("Demonstrator", selection: $girl) {
                    Text("Male athlete").tag(false)
                    Text("Female athlete").tag(true)
                }
                .pickerStyle(.segmented)
                Picker("Example view", selection: $sideView) {
                    Text("Front").tag(false)
                    Text("Side").tag(true)
                }
                .pickerStyle(.segmented)
                Text("Practice example: soften your knees, then return to ready.")
                    .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text("The ring marks your hitting-side knee. Match the example view to your camera. This is a general exercise, not a correction detected in your clip. Neither view is mirrored.")
                    .font(.caption)
                    .foregroundStyle(RallyUIKit.Palette.cloud)
            }
            .foregroundStyle(RallyUIKit.Palette.frost)
        }
        .onReceive(clock) { date in
            defer { lastTick = date }
            guard model.lesson == nil, examplePlaying, let lastTick else { return }
            exampleTime = (exampleTime + min(0.1, date.timeIntervalSince(lastTick)) * (slowExample ? 0.5 : 1)).truncatingRemainder(dividingBy: 4)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            examplePlaying = false
            model.lesson?.pause()
        }
        .onDisappear { examplePlaying = false; model.lesson?.pause() }
    }
}

@MainActor
private struct CoachComparison: View {
    @ObservedObject var session: CoachLessonSession
    let appearance: RallyAvatarAppearance
    let leftHanded: Bool
    let sideView: Bool
    @State private var showOutline = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your movement").font(RallyUIKit.Typography.title(.title2))
            ZStack {
                CoachMovieSurface(player: session.player)
                if showOutline {
                    Canvas { context, size in
                        let points = CoachOutline.points(at: session.time, frames: session.frames)
                        let aspect = CGFloat(session.aspectRatio)
                        let scale: CGFloat = min(size.width / aspect, size.height)
                        let origin = CGPoint(x: (size.width - scale * aspect) / 2,
                                             y: (size.height - scale) / 2)
                        func location(_ point: CoachKeypoint) -> CGPoint {
                            CGPoint(x: origin.x + CGFloat(point.x) * scale, y: origin.y + CGFloat(point.y) * scale)
                        }
                        for (a, b) in CoachOutline.links {
                            guard let a = points[a], let b = points[b], a.x <= session.aspectRatio, b.x <= session.aspectRatio else { continue }
                            var path = Path(); path.move(to: location(a)); path.addLine(to: location(b))
                            context.stroke(path, with: .color(.black.opacity(0.8)), lineWidth: 5)
                            context.stroke(path, with: .color(.white), lineWidth: 2)
                        }
                        if let knee = points[leftHanded ? .leftKnee : .rightKnee], knee.x <= session.aspectRatio {
                            let p = location(knee)
                            context.stroke(Path(ellipseIn: CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22)),
                                           with: .color(.yellow), lineWidth: 4)
                            context.stroke(Path(ellipseIn: CGRect(x: p.x - 15, y: p.y - 15, width: 30, height: 30)),
                                           with: .color(.white), lineWidth: 1)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(height: session.aspectRatio < 1 ? 340 : 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityLabel("Your selected practice clip, with an optional sampled body outline")
            if CoachOutline.points(at: session.time, frames: session.frames).isEmpty {
                Label("Let's get a clearer video", systemImage: "viewfinder")
                    .foregroundStyle(RallyUIKit.Palette.gold)
                HStack(spacing: 12) {
                    Image(systemName: "figure.stand").font(.system(size: 44)).padding(12)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(style: StrokeStyle(lineWidth: 2, dash: [5])))
                    Text("One player. Head and shoes in the frame. Steady camera. You can still replay this clip.")
                        .font(.caption)
                }
            }
            Toggle("Show tracked outline", isOn: $showOutline).font(.subheadline)
            Text("Try this").font(RallyUIKit.Typography.title(.title2))
            CoachDemonstrator(appearance: appearance, progress: session.exampleProgress,
                              leftHanded: leftHanded, sideView: sideView)
                .frame(height: 260)
                .accessibilityLabel("Practice example, hitting-side knee highlighted with a ring")
            Text("Practice example / manually aligned")
                .font(.caption).foregroundStyle(RallyUIKit.Palette.cloud)
            HStack {
                Button(session.isPlaying ? "Pause both" : "Play both") { session.togglePlayback() }
                Button("Replay") { session.seek(to: session.loopStart, resume: true) }
            }
            .buttonStyle(.bordered).frame(minHeight: 44)
            Toggle("Slow motion", isOn: $session.slow).onChange(of: session.slow) { _, _ in session.setSpeed() }
            Toggle("Loop this section", isOn: $session.loops)
            Text("Video position: \(session.time.formatted(.number.precision(.fractionLength(1)))) sec")
                .font(.caption).monospacedDigit()
            Slider(value: Binding(get: { session.time }, set: { session.seek(to: $0) }), in: 0...session.duration)
                .accessibilityLabel("Video position in seconds")
            Button("Start comparison here") {
                session.loopStart = min(session.time, max(0, session.duration - 1))
                session.seek(to: session.loopStart)
            }
            .frame(minHeight: 44)
            Text("The example starts where you choose, not at an inferred ball contact. Video sound stays muted.")
                .font(.caption).foregroundStyle(RallyUIKit.Palette.cloud)
        }
    }
}
