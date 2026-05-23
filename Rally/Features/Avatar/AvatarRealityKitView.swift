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

        private var chest: ModelEntity?
        private var pelvis: ModelEntity?
        private var neck: ModelEntity?
        private var head: ModelEntity?
        private var hair: ModelEntity?
        private var leftUpperArm: ModelEntity?
        private var leftForearm: ModelEntity?
        private var rightUpperArm: ModelEntity?
        private var rightForearm: ModelEntity?
        private var leftThigh: ModelEntity?
        private var leftCalf: ModelEntity?
        private var leftShoe: ModelEntity?
        private var rightThigh: ModelEntity?
        private var rightCalf: ModelEntity?
        private var rightShoe: ModelEntity?
        private var shorts: ModelEntity?
        private var racketHead: ModelEntity?
        private var racketHandle: ModelEntity?
        private var racketThroat: ModelEntity?

        private var baseRightUpperArmQ = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
        private var baseLeftUpperArmQ = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
        private var baseRightForearmQ = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
        private var baseLeftForearmQ = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
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
            staging.position = SIMD3<Float>(0, -0.52, -1.08)
            anchor.addChild(staging)

            avatarRoot.name = "avatarRoot"
            staging.addChild(avatarRoot)

            hip.name = "hip"
            hip.position = SIMD3<Float>(0, 0.88, 0)
            avatarRoot.addChild(hip)

            proceduralRoot.name = "procedural"
            hip.addChild(proceduralRoot)

            // Athletic male proportions (~7.5 heads). Lean tennis-pro silhouette.
            pelvis = Self.capsuleEntity(
                height: 0.14, radius: 0.11,
                position: SIMD3<Float>(0, -0.06, 0),
                roughness: 0.58
            )
            proceduralRoot.addChild(pelvis!)

            shorts = Self.capsuleEntity(
                height: 0.18, radius: 0.125,
                position: SIMD3<Float>(0, -0.17, 0),
                roughness: 0.48, metallic: 0.04
            )
            proceduralRoot.addChild(shorts!)

            chest = Self.capsuleEntity(
                height: 0.36, radius: 0.115,
                position: SIMD3<Float>(0, 0.12, 0),
                roughness: 0.44, metallic: 0.02
            )
            chest!.scale = SIMD3<Float>(1.08, 1.0, 0.72)
            proceduralRoot.addChild(chest!)

            neck = Self.cylinderEntity(height: 0.07, radius: 0.038, position: SIMD3<Float>(0, 0.34, 0))
            proceduralRoot.addChild(neck!)

            head = Self.sphereEntity(radius: 0.095, position: SIMD3<Float>(0, 0.44, 0))
            head!.scale = SIMD3<Float>(0.92, 1.06, 0.88)
            proceduralRoot.addChild(head!)

            // Short crop — generic pro look.
            hair = Self.capsuleEntity(
                height: 0.06, radius: 0.098,
                position: SIMD3<Float>(0, 0.485, -0.012),
                roughness: 0.78
            )
            hair!.scale = SIMD3<Float>(1.02, 0.55, 0.96)
            proceduralRoot.addChild(hair!)

            leftUpperArm = Self.cylinderEntity(height: 0.17, radius: 0.034, position: SIMD3<Float>(-0.19, 0.18, 0))
            leftUpperArm!.orientation = QE.mul(QE.euler(0, 0, 0.22), QE.euler(0, 0, Float.pi / 2))
            proceduralRoot.addChild(leftUpperArm!)

            leftForearm = Self.cylinderEntity(height: 0.16, radius: 0.028, position: SIMD3<Float>(-0.33, 0.06, 0.02))
            leftForearm!.orientation = QE.mul(QE.euler(0.12, 0, 0.38), QE.euler(0, 0, Float.pi / 2))
            proceduralRoot.addChild(leftForearm!)

            rightUpperArm = Self.cylinderEntity(height: 0.17, radius: 0.034, position: SIMD3<Float>(0.19, 0.18, 0))
            rightUpperArm!.orientation = QE.mul(QE.euler(0, 0, -0.22), QE.euler(0, 0, Float.pi / 2))
            proceduralRoot.addChild(rightUpperArm!)

            rightForearm = Self.cylinderEntity(height: 0.16, radius: 0.028, position: SIMD3<Float>(0.33, 0.06, 0.02))
            rightForearm!.orientation = QE.mul(QE.euler(0.12, 0, -0.38), QE.euler(0, 0, Float.pi / 2))
            proceduralRoot.addChild(rightForearm!)

            baseRightUpperArmQ = rightUpperArm!.orientation
            baseLeftUpperArmQ = leftUpperArm!.orientation
            baseRightForearmQ = rightForearm!.orientation
            baseLeftForearmQ = leftForearm!.orientation

            leftThigh = Self.cylinderEntity(height: 0.22, radius: 0.048, position: SIMD3<Float>(-0.08, -0.36, 0))
            proceduralRoot.addChild(leftThigh!)

            leftCalf = Self.cylinderEntity(height: 0.21, radius: 0.038, position: SIMD3<Float>(-0.08, -0.58, 0.01))
            proceduralRoot.addChild(leftCalf!)

            leftShoe = Self.boxEntity(
                size: SIMD3<Float>(0.09, 0.05, 0.18),
                cornerRadius: 0.018,
                position: SIMD3<Float>(-0.08, -0.72, 0.04),
                roughness: 0.38, metallic: 0.18
            )
            proceduralRoot.addChild(leftShoe!)

            rightThigh = Self.cylinderEntity(height: 0.22, radius: 0.048, position: SIMD3<Float>(0.08, -0.36, 0))
            proceduralRoot.addChild(rightThigh!)

            rightCalf = Self.cylinderEntity(height: 0.21, radius: 0.038, position: SIMD3<Float>(0.08, -0.58, 0.01))
            proceduralRoot.addChild(rightCalf!)

            rightShoe = Self.boxEntity(
                size: SIMD3<Float>(0.09, 0.05, 0.18),
                cornerRadius: 0.018,
                position: SIMD3<Float>(0.08, -0.72, 0.04),
                roughness: 0.38, metallic: 0.18
            )
            proceduralRoot.addChild(rightShoe!)

            racketParent.name = "racket"
            racketParent.position = SIMD3<Float>(0.38, 0.04, 0.08)
            racketParent.orientation = QE.euler(0.28, 0.15, -0.52)
            proceduralRoot.addChild(racketParent)
            baseRacketQ = racketParent.orientation

            racketHead = Self.boxEntity(
                size: SIMD3<Float>(0.22, 0.28, 0.022),
                cornerRadius: 0.045,
                position: SIMD3<Float>(0, 0.06, 0),
                roughness: 0.28, metallic: 0.62
            )
            racketThroat = Self.boxEntity(
                size: SIMD3<Float>(0.04, 0.12, 0.03),
                cornerRadius: 0.01,
                position: SIMD3<Float>(0, -0.18, 0),
                roughness: 0.34, metallic: 0.54
            )
            racketHandle = Self.cylinderEntity(
                height: 0.28, radius: 0.016,
                position: SIMD3<Float>(0, -0.38, 0),
                roughness: 0.42, metallic: 0.48
            )
            racketParent.addChild(racketHead!)
            racketParent.addChild(racketThroat!)
            racketParent.addChild(racketHandle!)
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

            chest?.model?.materials = [Self.mat(topFinal, roughness: 0.44, metallic: 0.02)]
            pelvis?.model?.materials = [Self.mat(spec.skin, roughness: 0.56)]
            shorts?.model?.materials = [Self.mat(bottomFinal, roughness: 0.48)]
            neck?.model?.materials = [Self.mat(spec.skin, roughness: 0.54)]
            head?.model?.materials = [Self.mat(spec.skin, roughness: 0.52)]
            hair?.model?.materials = [Self.mat(spec.hair, roughness: 0.76)]
            hair?.isEnabled = spec.showsHair

            let skinMat = Self.mat(spec.skin, roughness: 0.54)
            leftUpperArm?.model?.materials = [skinMat]
            rightUpperArm?.model?.materials = [skinMat]
            leftForearm?.model?.materials = [skinMat]
            rightForearm?.model?.materials = [skinMat]

            let legSkin = Self.mat(spec.skin, roughness: 0.56)
            leftThigh?.model?.materials = [legSkin]
            rightThigh?.model?.materials = [legSkin]
            leftCalf?.model?.materials = [legSkin]
            rightCalf?.model?.materials = [legSkin]

            leftShoe?.model?.materials = [Self.mat(shoeFinal, roughness: 0.36, metallic: 0.16)]
            rightShoe?.model?.materials = [Self.mat(shoeFinal, roughness: 0.36, metallic: 0.16)]

            let rkHead = spec.racketAccent == .clear ? spec.racket : spec.racket.multiplied(by: spec.racketAccent)
            racketHead?.model?.materials = [Self.mat(rkHead, roughness: 0.26, metallic: 0.64)]
            racketThroat?.model?.materials = [Self.mat(rkHead, roughness: 0.32, metallic: 0.58)]
            racketHandle?.model?.materials = [Self.mat(spec.racketAccent, roughness: 0.4, metallic: 0.55)]

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

        private static func capsuleEntity(
            height: Float,
            radius: Float,
            position: SIMD3<Float>,
            roughness: Float = 0.64,
            metallic: Float = 0.06
        ) -> ModelEntity {
            let mesh = MeshResource.generateBox(
                size: SIMD3(radius * 2, height, radius * 2),
                cornerRadius: radius
            )
            let e = ModelEntity(mesh: mesh, materials: [mat(.white, roughness: roughness, metallic: metallic)])
            e.position = position
            return e
        }

        private static func cylinderEntity(
            height: Float,
            radius: Float,
            position: SIMD3<Float>,
            roughness: Float = 0.64,
            metallic: Float = 0.06
        ) -> ModelEntity {
            let mesh = MeshResource.generateBox(
                size: SIMD3(radius * 2, height, radius * 2),
                cornerRadius: radius * 0.35
            )
            let e = ModelEntity(mesh: mesh, materials: [mat(.white, roughness: roughness, metallic: metallic)])
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
            let baseY: Float = -0.52
            let baseZ: Float = -1.08

            func resetArms() {
                rightUpperArm?.orientation = baseRightUpperArmQ
                leftUpperArm?.orientation = baseLeftUpperArmQ
                rightForearm?.orientation = baseRightForearmQ
                leftForearm?.orientation = baseLeftForearmQ
                racketParent.orientation = baseRacketQ
            }

            switch emote {
            case .idle:
                staging.orientation = simd_quatf(angle: sin(t * 1.25) * 0.055, axis: SIMD3<Float>(0, 1, 0))
                staging.position = SIMD3<Float>(sin(t * 0.95) * 0.018, baseY + sin(t * 2.05) * 0.016, baseZ)
                hip.orientation = simd_quatf(angle: sin(t * 1.08) * 0.05, axis: SIMD3<Float>(0, 1, 0))
                resetArms()

            case .wave:
                staging.orientation = simd_quatf(angle: sin(t * 1.15) * 0.045, axis: SIMD3<Float>(0, 1, 0))
                staging.position = SIMD3<Float>(0, baseY + sin(t * 2.0) * 0.014, baseZ)
                hip.orientation = simd_quatf(angle: sin(t * 1.05) * 0.05, axis: SIMD3<Float>(0, 1, 0))
                let waveAngle = sin(t * 7.2) * 0.58
                rightUpperArm?.orientation = simd_mul(baseRightUpperArmQ, simd_quatf(angle: waveAngle, axis: SIMD3<Float>(0, 0, 1)))
                rightForearm?.orientation = simd_mul(baseRightForearmQ, simd_quatf(angle: waveAngle * 0.45, axis: SIMD3<Float>(0, 0, 1)))
                leftUpperArm?.orientation = baseLeftUpperArmQ
                leftForearm?.orientation = baseLeftForearmQ
                racketParent.orientation = baseRacketQ

            case .celebrate:
                staging.position = SIMD3<Float>(0, baseY + abs(sin(t * 6.6)) * 0.075, baseZ)
                staging.orientation = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
                hip.orientation = simd_quatf(real: 1, imag: SIMD3<Float>(0, 0, 0))
                let cheer = sin(t * 5.5) * 0.88
                rightUpperArm?.orientation = simd_mul(
                    baseRightUpperArmQ,
                    simd_quatf(angle: cheer, axis: simd_normalize(SIMD3<Float>(1, 0, -0.38)))
                )
                leftUpperArm?.orientation = simd_mul(
                    baseLeftUpperArmQ,
                    simd_quatf(angle: cheer, axis: simd_normalize(SIMD3<Float>(1, 0, 0.38)))
                )
                rightForearm?.orientation = baseRightForearmQ
                leftForearm?.orientation = baseLeftForearmQ
                racketParent.orientation = simd_mul(baseRacketQ, simd_quatf(angle: sin(t * 6.2) * 0.22, axis: SIMD3<Float>(0, 1, 0)))

            case .shopLook:
                staging.position = SIMD3<Float>(sin(t * 0.52) * 0.045, baseY + sin(t * 1.75) * 0.012, baseZ)
                let gaze = sin(t * 0.82) * 0.42
                staging.orientation = simd_quatf(angle: gaze, axis: SIMD3<Float>(0, 1, 0))
                hip.orientation = simd_mul(
                    simd_quatf(angle: 0.09, axis: SIMD3<Float>(1, 0, 0)),
                    simd_quatf(angle: 0.36 + sin(t * 0.5) * 0.1, axis: SIMD3<Float>(0, 1, 0))
                )
                rightUpperArm?.orientation = simd_mul(baseRightUpperArmQ, simd_quatf(angle: -0.62, axis: SIMD3<Float>(0, 0, 1)))
                leftUpperArm?.orientation = simd_mul(baseLeftUpperArmQ, simd_quatf(angle: 0.38, axis: SIMD3<Float>(0, 0, 1)))
                rightForearm?.orientation = baseRightForearmQ
                leftForearm?.orientation = baseLeftForearmQ
                racketParent.orientation = simd_mul(baseRacketQ, simd_quatf(angle: 0.26, axis: SIMD3<Float>(0, 1, 0)))
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
