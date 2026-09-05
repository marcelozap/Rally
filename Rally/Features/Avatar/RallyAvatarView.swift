import SwiftUI
import SceneKit

/// A live, shared 3D fitting view. The coordinator retains the rig across appearance updates.
struct RallyAvatarView: View {
    let appearance: RallyAvatarAppearance
    let targetHeight: CGFloat
    var showsRacket: Bool = true
    var breathingPhase: Double = 0
    var allowsRotation: Bool = true
    var leftHanded: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RallyAvatarSceneView(appearance: appearance, showsRacket: showsRacket,
                             allowsRotation: allowsRotation, leftHanded: leftHanded, reduceMotion: reduceMotion)
            .frame(height: targetHeight)
            .accessibilityLabel("Your player wearing the selected outfit")
            .accessibilityHint(allowsRotation ? "Drag to rotate. Pinch to inspect clothing details." : "")
    }
}

private struct RallyAvatarSceneView: UIViewRepresentable {
    let appearance: RallyAvatarAppearance
    let showsRacket: Bool
    let allowsRotation: Bool
    let leftHanded: Bool
    let reduceMotion: Bool

    func makeUIView(context: Context) -> RallyFittingSceneView {
        let view = RallyFittingSceneView()
        view.rig = RallyAvatarRig(appearance: appearance, presentation: .studio)
        view.scene = view.rig?.scene
        view.pointOfView = view.rig?.camera
        view.backgroundColor = .clear
        view.isOpaque = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.addGestureRecognizer(UIPanGestureRecognizer(target: view, action: #selector(RallyFittingSceneView.rotate(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: view, action: #selector(RallyFittingSceneView.zoom(_:))))
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: RallyFittingSceneView, context: Context) {
        view.rig?.apply(appearance)
        view.rig?.setRacketVisible(showsRacket)
        view.leftHanded = leftHanded
        view.reduceMotion = reduceMotion
        view.gestureRecognizers?.forEach { $0.isEnabled = allowsRotation }
        view.drawFrame()
    }

    static func dismantleUIView(_ view: RallyFittingSceneView, coordinator: ()) {
        view.stopRendering()
        view.scene = nil
        view.rig = nil
    }
}

private final class RallyFittingSceneView: SCNView {
    var rig: RallyAvatarRig?
    var leftHanded = false
    var reduceMotion = false
    private var displayLink: CADisplayLink?
    private var yawAtGestureStart: Float = 0
    private var zoomAtGestureStart: Double = 1.05

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopRendering()
        } else if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(drawFrame))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    func stopRendering() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc func drawFrame() {
        rig?.animate(time: reduceMotion ? 0 : CACurrentMediaTime(), leftHanded: leftHanded)
        setNeedsDisplay()
    }

    @objc func rotate(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began { yawAtGestureStart = rig?.yaw ?? 0 }
        rig?.yaw = yawAtGestureStart + Float(gesture.translation(in: self).x) * 0.009
        drawFrame()
    }

    @objc func zoom(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began { zoomAtGestureStart = rig?.camera.camera?.orthographicScale ?? 1.05 }
        let scale = min(1.15, max(0.48, zoomAtGestureStart / Double(gesture.scale)))
        rig?.camera.camera?.orthographicScale = scale
        // Zoom towards chest/garments while keeping normal framing grounded at full height.
        rig?.camera.position.y = Float(0.93 + (1.05 - scale) * 0.62)
        drawFrame()
    }
}
