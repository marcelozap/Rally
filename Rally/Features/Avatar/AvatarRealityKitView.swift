import RealityKit
import SwiftUI
import UIKit

/// Premium shop avatar: RealityKit on a non‑AR `ARView` — image‑based lighting,
/// PBR materials, optional bundled **`AvatarHero.usdz`**, same emote set as before.
struct AvatarRealityKitView: UIViewRepresentable {

    var spec: AvatarVisualSpec
    var emote: AvatarShopEmote

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.backgroundColor = .clear
        arView.environment.background = .color(.clear)

        context.coordinator.arView = arView

        let worldAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
        arView.scene.addAnchor(worldAnchor)
        context.coordinator.worldAnchor = worldAnchor

        context.coordinator.attachLighting(to: worldAnchor)
        context.coordinator.buildProceduralFigure(under: worldAnchor)

        context.coordinator.apply(spec: spec)
        context.coordinator.emote = emote
        context.coordinator.lastEmote = emote

        context.coordinator.tryLoadBundledHero()
        context.coordinator.startDisplayLink()

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.apply(spec: spec)
        if context.coordinator.lastEmote != emote {
            context.coordinator.emote = emote
            context.coordinator.lastEmote = emote
            context.coordinator.animationAnchor = CACurrentMediaTime()
        }
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.stopDisplayLink()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {

        weak var arView: ARView?
        var worldAnchor: AnchorEntity?

        private static let placeholderSpec = AvatarVisualSpec(
            skin: .lightGray,
            hair: .darkGray,
            showsHair: true,
            top: .white,
            topAccent: .clear,
            bottom: .black,
            bottomAccent: .clear,
            shoes: .white,
            shoesAccent: .cyan,
            racket: .lightGray,
            racketAccent: .cyan,
            bodyScale: 1
        )

        private var staging = Entity()
        private var avatarRoot = Entity()
        private var hip = Entity()

        private var proceduralRoot = Entity()
        private var racketParent = Entity()
        private var heroUSDZ: Entity?
        private var stagePlate: ModelEntity?
        private var stageShadow: ModelEntity?

        private var torso: ModelEntity?
        private var shorts: ModelEntity?
        private var head: ModelEntity?
        private var hair: ModelEntity?
        private var leftArm: ModelEntity?
        private var rightArm: ModelEntity?
        private var leftLeg: ModelEntity?
        private var rightLeg: ModelEntity?
        private var racketHead: ModelEntity?
        private var racketHandle: ModelEntity?
        private var racketStrings: [ModelEntity] = []

        private var baseRightArmQ = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
        private var baseLeftArmQ = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
        private var baseRacketQ = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))

        private var displayLink: CADisplayLink?
        fileprivate var animationAnchor: CFTimeInterval = 0

        var spec: AvatarVisualSpec = Coordinator.placeholderSpec
        var emote: AvatarShopEmote = .idle
        var lastEmote: AvatarShopEmote = .idle

        // MARK: Lighting

        func attachLighting(to anchor: AnchorEntity) {
            var key = DirectionalLightComponent(color: UIColor.white, intensity: 6200)
            let keyEntity = Entity()
            keyEntity.components.set(key)
            keyEntity.look(at: SIMD3<Float>(0, -1.2, -2.8), from: SIMD3<Float>(2.5, 5, 6), relativeTo: nil)
            anchor.addChild(keyEntity)

            var rim = DirectionalLightComponent(color: UIColor.white, intensity: 2400)
            let rimEntity = Entity()
            rimEntity.components.set(rim)
            rimEntity.look(at: SIMD3<Float>(0, 0.6, 0), from: SIMD3<Float>(-5, 3.5, 4), relativeTo: nil)
            anchor.addChild(rimEntity)

            var ambient = DirectionalLightComponent(color: UIColor.white, intensity: 900)
            let fill = Entity()
            fill.components.set(ambient)
            fill.look(at: SIMD3<Float>(0, 0, 0), from: SIMD3<Float>(0, 8, 2), relativeTo: nil)
            anchor.addChild(fill)
        }

        // MARK: Build

        func buildProceduralFigure(under anchor: AnchorEntity) {
            staging.name = "staging"
            staging.position = SIMD3<Float>(0, -0.42, -1.05)
            anchor.addChild(staging)

            stageShadow = Self.boxEntity(
                size: SIMD3<Float>(1.0, 0.01, 0.56),
                cornerRadius: 0.08,
                position: SIMD3<Float>(0, -0.6, 0.03),
                roughness: 1.0,
                metallic: 0
            )
            stagePlate = Self.boxEntity(
                size: SIMD3<Float>(1.18, 0.025, 0.72),
                cornerRadius: 0.08,
                position: SIMD3<Float>(0, -0.57, 0.02),
                roughness: 0.42,
                metallic: 0.18
            )
            if let stageShadow, let stagePlate {
                staging.addChild(stageShadow)
                staging.addChild(stagePlate)
            }

            avatarRoot.name = "avatarRoot"
            staging.addChild(avatarRoot)

            hip.name = "hip"
            hip.position = SIMD3<Float>(0, 0.82, 0)
            avatarRoot.addChild(hip)

            proceduralRoot.name = "procedural"
            hip.addChild(proceduralRoot)

            torso = Self.boxEntity(
                size: SIMD3<Float>(0.48, 0.46, 0.2),
                cornerRadius: 0.06,
                position: SIMD3<Float>(0, 0.06, 0)
            )
            proceduralRoot.addChild(torso!)

            shorts = Self.boxEntity(
                size: SIMD3<Float>(0.5, 0.18, 0.2),
                cornerRadius: 0.05,
                position: SIMD3<Float>(0, -0.22, 0)
            )
            proceduralRoot.addChild(shorts!)

            head = Self.sphereEntity(radius: 0.13, position: SIMD3<Float>(0, 0.42, 0))
            proceduralRoot.addChild(head!)

            hair = Self.sphereEntity(radius: 0.138, position: SIMD3<Float>(0, 0.46, -0.02))
            hair!.scale = SIMD3<Float>(1.05, 0.55, 1.05)
            proceduralRoot.addChild(hair!)

            leftArm = Self.cylinderEntity(height: 0.34, radius: 0.045, position: SIMD3<Float>(-0.34, 0.08, 0))
            leftArm!.orientation = QE.mul(QE.euler(0, 0, 0.35), QE.euler(0, 0, Float.pi / 2))
            proceduralRoot.addChild(leftArm!)

            rightArm = Self.cylinderEntity(height: 0.34, radius: 0.045, position: SIMD3<Float>(0.34, 0.08, 0))
            rightArm!.orientation = QE.mul(QE.euler(0, 0, -0.35), QE.euler(0, 0, Float.pi / 2))
            proceduralRoot.addChild(rightArm!)

            baseRightArmQ = rightArm!.orientation
            baseLeftArmQ = leftArm!.orientation

            leftLeg = Self.cylinderEntity(height: 0.42, radius: 0.055, position: SIMD3<Float>(-0.13, -0.38, 0))
            proceduralRoot.addChild(leftLeg!)

            rightLeg = Self.cylinderEntity(height: 0.42, radius: 0.055, position: SIMD3<Float>(0.13, -0.38, 0))
            proceduralRoot.addChild(rightLeg!)

            racketParent.name = "racket"
            racketParent.position = SIMD3<Float>(0.52, 0.02, 0.1)
            racketParent.orientation = QE.euler(0.35, 0, -0.45)
            proceduralRoot.addChild(racketParent)
            baseRacketQ = racketParent.orientation

            racketHead = Self.boxEntity(
                size: SIMD3<Float>(0.26, 0.34, 0.03),
                cornerRadius: 0.02,
                position: SIMD3<Float>(0, 0.05, 0),
                roughness: 0.34,
                metallic: 0.54
            )
            racketHandle = Self.boxEntity(
                size: SIMD3<Float>(0.05, 0.36, 0.05),
                cornerRadius: 0.015,
                position: SIMD3<Float>(0, -0.32, 0),
                roughness: 0.38,
                metallic: 0.62
            )
            racketParent.addChild(racketHead!)
            racketParent.addChild(racketHandle!)

            racketStrings.removeAll()
            for x in stride(from: Float(-0.08), through: 0.08, by: 0.04) {
                let string = Self.boxEntity(
                    size: SIMD3<Float>(0.004, 0.24, 0.004),
                    cornerRadius: 0.001,
                    position: SIMD3<Float>(x, 0.05, 0),
                    roughness: 0.28,
                    metallic: 0.2
                )
                racketParent.addChild(string)
                racketStrings.append(string)
            }
            for y in stride(from: Float(-0.04), through: 0.14, by: 0.045) {
                let string = Self.boxEntity(
                    size: SIMD3<Float>(0.16, 0.004, 0.004),
                    cornerRadius: 0.001,
                    position: SIMD3<Float>(0, y, 0),
                    roughness: 0.28,
                    metallic: 0.2
                )
                racketParent.addChild(string)
                racketStrings.append(string)
            }
        }

        func tryLoadBundledHero() {
            guard let url = Bundle.main.url(forResource: "AvatarHero", withExtension: "usdz") else { return }
            Task { @MainActor in
                do {
                    let hero = try Entity.load(contentsOf: url)
                    hero.position = SIMD3<Float>(0, -0.58, 0)
                    staging.addChild(hero)
                    self.heroUSDZ = hero
                    self.proceduralRoot.isEnabled = false
                } catch {
                    self.heroUSDZ = nil
                    self.proceduralRoot.isEnabled = true
                }
            }
        }

        // MARK: Apply

        func apply(spec: AvatarVisualSpec) {
            self.spec = spec
            guard proceduralRoot.isEnabled else { return }

            let topFinal = spec.topAccent == .clear ? spec.top : spec.top.multiplied(by: spec.topAccent)
            let bottomFinal = spec.bottomAccent == .clear ? spec.bottom : spec.bottom.multiplied(by: spec.bottomAccent)
            let shoeFinal = spec.shoesAccent == .clear ? spec.shoes : spec.shoes.multiplied(by: spec.shoesAccent)

            torso?.model?.materials = [Self.mat(topFinal)]
            shorts?.model?.materials = [Self.mat(bottomFinal)]
            head?.model?.materials = [Self.mat(spec.skin, roughness: 0.56)]
            hair?.model?.materials = [Self.mat(spec.hair, roughness: 0.74)]
            hair?.isEnabled = spec.showsHair

            leftArm?.model?.materials = [Self.mat(spec.skin)]
            rightArm?.model?.materials = [Self.mat(spec.skin)]
            leftLeg?.model?.materials = [Self.mat(shoeFinal, roughness: 0.46, metallic: 0.14)]
            rightLeg?.model?.materials = [Self.mat(shoeFinal, roughness: 0.46, metallic: 0.14)]

            let rkHead = spec.racketAccent == .clear ? spec.racket : spec.racket.multiplied(by: spec.racketAccent)
            racketHead?.model?.materials = [Self.mat(rkHead, roughness: 0.32, metallic: 0.58)]
            racketHandle?.model?.materials = [Self.mat(spec.racketAccent, roughness: 0.4, metallic: 0.62)]
            racketStrings.forEach { $0.model?.materials = [Self.mat(UIColor.white.withAlphaComponent(0.85), roughness: 0.22, metallic: 0.18)] }

            let plateTint = spec.racketAccent == .clear
                ? UIColor(white: 0.16, alpha: 1)
                : spec.racketAccent.multiplied(by: UIColor(red: 0.52, green: 0.52, blue: 0.52, alpha: 1))
            stagePlate?.model?.materials = [Self.mat(plateTint.withAlphaComponent(0.98), roughness: 0.38, metallic: 0.12)]
            stageShadow?.model?.materials = [Self.mat(UIColor.black.withAlphaComponent(0.34), roughness: 1.0, metallic: 0)]

            let s = Float(spec.bodyScale)
            hip.scale = SIMD3<Float>(repeating: s)
        }

        private static func mat(
            _ ui: UIColor,
            roughness: Float = 0.64,
            metallic: Float = 0.06
        ) -> RealityKit.Material {
            SimpleMaterial(
                color: ui,
                roughness: .float(roughness),
                isMetallic: metallic > 0.5
            )
        }

        private static func boxEntity(
            size: SIMD3<Float>,
            cornerRadius: Float,
            position: SIMD3<Float>,
            roughness: Float = 0.64,
            metallic: Float = 0.06
        ) -> ModelEntity {
            let mesh = MeshResource.generateBox(size: size, cornerRadius: cornerRadius)
            let e = ModelEntity(mesh: mesh, materials: [mat(.white, roughness: roughness, metallic: metallic)])
            e.position = position
            return e
        }

        private static func sphereEntity(radius: Float, position: SIMD3<Float>) -> ModelEntity {
            let mesh = MeshResource.generateSphere(radius: radius)
            let e = ModelEntity(mesh: mesh, materials: [mat(.white)])
            e.position = position
            return e
        }

        private static func cylinderEntity(height: Float, radius: Float, position: SIMD3<Float>) -> ModelEntity {
            let mesh = MeshResource.generateBox(
                size: SIMD3<Float>(radius * 2, height, radius * 2),
                cornerRadius: min(radius * 0.7, height * 0.2)
            )
            let e = ModelEntity(mesh: mesh, materials: [mat(.white)])
            e.position = position
            return e
        }

        // MARK: Loop

        func startDisplayLink() {
            stopDisplayLink()
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
            animationAnchor = CACurrentMediaTime()
        }

        func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func step(_ link: CADisplayLink) {
            let t = Float(CACurrentMediaTime() - animationAnchor)

            switch emote {
            case .idle:
                staging.orientation = simd_quatf(angle: sin(t * 1.25) * 0.055, axis: SIMD3<Float>(0, 1, 0))
                staging.position = SIMD3<Float>(sin(t * 0.95) * 0.018, -0.42 + sin(t * 2.05) * 0.016, -1.05)
                hip.orientation = QE.mul(
                    simd_quatf(angle: 0.07, axis: SIMD3<Float>(1, 0, 0)),
                    QE.mul(
                        simd_quatf(angle: sin(t * 1.08) * 0.05, axis: SIMD3<Float>(0, 1, 0)),
                        simd_quatf(angle: sin(t * 1.9) * 0.025, axis: SIMD3<Float>(0, 0, 1))
                    )
                )
                rightArm?.orientation = simd_mul(baseRightArmQ, QE.euler(0.04, 0.02, -0.06 + sin(t * 1.8) * 0.05))
                leftArm?.orientation = simd_mul(baseLeftArmQ, QE.euler(-0.02, -0.01, 0.03 + sin(t * 1.55) * 0.04))
                racketParent.orientation = simd_mul(baseRacketQ, QE.euler(0.02 + sin(t * 1.5) * 0.03, sin(t * 0.85) * 0.04, -0.01))
                rightLeg?.orientation = QE.euler(0.04 + sin(t * 1.2) * 0.02, 0, -0.05)
                leftLeg?.orientation = QE.euler(-0.02 + sin(t * 1.1 + 0.7) * 0.015, 0, 0.05)

            case .wave:
                staging.orientation = simd_quatf(angle: sin(t * 1.15) * 0.045, axis: SIMD3<Float>(0, 1, 0))
                staging.position = SIMD3<Float>(0, -0.42 + sin(t * 2.0) * 0.014, -1.05)
                hip.orientation = QE.mul(
                    simd_quatf(angle: 0.05, axis: SIMD3<Float>(1, 0, 0)),
                    simd_quatf(angle: sin(t * 1.05) * 0.05, axis: SIMD3<Float>(0, 1, 0))
                )
                let waveAngle = sin(t * 7.2) * 0.58
                rightArm?.orientation = simd_mul(baseRightArmQ, simd_quatf(angle: waveAngle, axis: SIMD3<Float>(0, 0, 1)))
                leftArm?.orientation = simd_mul(baseLeftArmQ, QE.euler(-0.02, 0, 0.08))
                racketParent.orientation = simd_mul(baseRacketQ, QE.euler(0.02, sin(t * 1.4) * 0.06, -0.04))
                rightLeg?.orientation = QE.euler(0.03, 0, -0.05)
                leftLeg?.orientation = QE.euler(-0.02, 0, 0.05)

            case .celebrate:
                staging.position = SIMD3<Float>(0, -0.42 + abs(sin(t * 6.6)) * 0.075, -1.05)
                staging.orientation = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
                hip.orientation = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
                let cheer = sin(t * 5.5) * 0.88
                rightArm?.orientation = simd_mul(
                    baseRightArmQ,
                    simd_quatf(angle: cheer, axis: simd_normalize(SIMD3<Float>(1, 0, -0.38)))
                )
                leftArm?.orientation = simd_mul(
                    baseLeftArmQ,
                    simd_quatf(angle: cheer, axis: simd_normalize(SIMD3<Float>(1, 0, 0.38)))
                )
                racketParent.orientation = simd_mul(baseRacketQ, simd_quatf(angle: sin(t * 6.2) * 0.22, axis: SIMD3<Float>(0, 1, 0)))

            case .shopLook:
                staging.position = SIMD3<Float>(sin(t * 0.52) * 0.045, -0.42 + sin(t * 1.75) * 0.012, -1.05)
                let gaze = sin(t * 0.82) * 0.42
                staging.orientation = simd_quatf(angle: gaze, axis: SIMD3<Float>(0, 1, 0))
                hip.orientation = simd_mul(
                    simd_quatf(angle: 0.1, axis: SIMD3<Float>(1, 0, 0)),
                    simd_quatf(angle: 0.36 + sin(t * 0.5) * 0.1, axis: SIMD3<Float>(0, 1, 0))
                )
                rightArm?.orientation = simd_mul(baseRightArmQ, QE.euler(0.03, 0.08, -0.62 + sin(t * 1.05) * 0.04))
                leftArm?.orientation = simd_mul(baseLeftArmQ, QE.euler(-0.04, -0.04, 0.38 + sin(t * 0.92) * 0.03))
                racketParent.orientation = simd_mul(baseRacketQ, QE.euler(0.05, 0.26 + sin(t * 0.8) * 0.08, -0.03))
                rightLeg?.orientation = QE.euler(0.05, 0.01, -0.1)
                leftLeg?.orientation = QE.euler(-0.03, -0.01, 0.07)
            }

            if heroUSDZ != nil {
                heroUSDZ?.orientation = simd_quatf(angle: sin(t * 0.42) * 0.09, axis: SIMD3<Float>(0, 1, 0))
            }
        }
    }
}

// MARK: - Quaternion euler order ZYX

private enum QE {
    static func euler(_ x: Float, _ y: Float, _ z: Float) -> simd_quatf {
        let qx = simd_quatf(angle: x, axis: SIMD3<Float>(1, 0, 0))
        let qy = simd_quatf(angle: y, axis: SIMD3<Float>(0, 1, 0))
        let qz = simd_quatf(angle: z, axis: SIMD3<Float>(0, 0, 1))
        return simd_normalize(qz * qy * qx)
    }

    static func mul(_ a: simd_quatf, _ b: simd_quatf) -> simd_quatf {
        simd_normalize(a * b)
    }
}
