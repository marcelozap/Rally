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
        private let allowsBundledHero = false

        weak var arView: ARView?
        var worldAnchor: AnchorEntity?

        private static let placeholderSpec = AvatarVisualSpec(
            skin: .lightGray,
            hair: .darkGray,
            showsHair: true,
            hairProfile: .short,
            top: .white,
            topAccent: .clear,
            bottom: .black,
            bottomAccent: .clear,
            shoes: .white,
            shoesAccent: .cyan,
            racket: .lightGray,
            racketAccent: .cyan,
            bodyScale: 1,
            bodyProfile: .athletic
        )

        private var staging = Entity()
        private var avatarRoot = Entity()
        private var hip = Entity()

        private var proceduralRoot = Entity()
        private var racketParent = Entity()
        private var heroUSDZ: Entity?
        private var stagePlate: ModelEntity?
        private var stageShadow: ModelEntity?
        private var stageAura: ModelEntity?
        private var haloDisc: ModelEntity?
        private var backLight: ModelEntity?

        private var torso: ModelEntity?
        private var shorts: ModelEntity?
        private var chestBand: ModelEntity?
        private var head: ModelEntity?
        private var leftEyeWhite: ModelEntity?
        private var rightEyeWhite: ModelEntity?
        private var leftIris: ModelEntity?
        private var rightIris: ModelEntity?
        private var leftBrow: ModelEntity?
        private var rightBrow: ModelEntity?
        private var nose: ModelEntity?
        private var mouth: ModelEntity?
        private var hair: ModelEntity?
        private var hairBack: ModelEntity?
        private var ponytail: ModelEntity?
        private var hairBun: ModelEntity?
        private var neck: ModelEntity?
        private var leftArm: ModelEntity?
        private var rightArm: ModelEntity?
        private var leftLeg: ModelEntity?
        private var rightLeg: ModelEntity?
        private var leftShoe: ModelEntity?
        private var rightShoe: ModelEntity?
        private var leftShoulder: ModelEntity?
        private var rightShoulder: ModelEntity?
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
            let key = DirectionalLightComponent(color: UIColor.white, intensity: 7800)
            let keyEntity = Entity()
            keyEntity.components.set(key)
            keyEntity.look(at: SIMD3<Float>(0, -1.2, -2.8), from: SIMD3<Float>(2.5, 5, 6), relativeTo: nil)
            anchor.addChild(keyEntity)

            let rim = DirectionalLightComponent(color: UIColor(red: 0.82, green: 0.94, blue: 1, alpha: 1), intensity: 3400)
            let rimEntity = Entity()
            rimEntity.components.set(rim)
            rimEntity.look(at: SIMD3<Float>(0, 0.6, 0), from: SIMD3<Float>(-5, 3.5, 4), relativeTo: nil)
            anchor.addChild(rimEntity)

            let ambient = DirectionalLightComponent(color: UIColor(red: 1, green: 0.96, blue: 0.92, alpha: 1), intensity: 1200)
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
            stageAura = Self.boxEntity(
                size: SIMD3<Float>(0.92, 0.008, 0.42),
                cornerRadius: 0.06,
                position: SIMD3<Float>(0, -0.56, 0.03),
                roughness: 0.22,
                metallic: 0
            )
            haloDisc = Self.discEntity(
                radius: 0.3,
                height: 0.006,
                position: SIMD3<Float>(0, -0.553, 0.055),
                roughness: 0.12,
                metallic: 0
            )
            backLight = Self.sphereEntity(radius: 0.28, position: SIMD3<Float>(0, 0.24, -0.26))
            backLight?.scale = SIMD3<Float>(1.0, 1.3, 0.18)
            if let stageShadow, let stagePlate, let stageAura, let haloDisc, let backLight {
                staging.addChild(stageShadow)
                staging.addChild(stagePlate)
                staging.addChild(stageAura)
                staging.addChild(haloDisc)
                staging.addChild(backLight)
            }

            avatarRoot.name = "avatarRoot"
            staging.addChild(avatarRoot)

            hip.name = "hip"
            hip.position = SIMD3<Float>(0, 0.82, 0)
            avatarRoot.addChild(hip)

            proceduralRoot.name = "procedural"
            hip.addChild(proceduralRoot)

            torso = Self.boxEntity(
                size: SIMD3<Float>(0.46, 0.60, 0.22),
                cornerRadius: 0.09,
                position: SIMD3<Float>(0, 0.07, 0.01)
            )
            proceduralRoot.addChild(torso!)

            chestBand = Self.boxEntity(
                size: SIMD3<Float>(0.20, 0.028, 0.23),
                cornerRadius: 0.012,
                position: SIMD3<Float>(0, 0.205, 0.015),
                roughness: 0.22,
                metallic: 0.08
            )
            proceduralRoot.addChild(chestBand!)

            neck = Self.boxEntity(
                size: SIMD3<Float>(0.10, 0.085, 0.10),
                cornerRadius: 0.03,
                position: SIMD3<Float>(0, 0.355, 0.002)
            )
            proceduralRoot.addChild(neck!)

            shorts = Self.boxEntity(
                size: SIMD3<Float>(0.50, 0.20, 0.21),
                cornerRadius: 0.07,
                position: SIMD3<Float>(0, -0.255, 0.01)
            )
            proceduralRoot.addChild(shorts!)

            head = Self.boxEntity(
                size: SIMD3<Float>(0.25, 0.29, 0.23),
                cornerRadius: 0.10,
                position: SIMD3<Float>(0, 0.495, 0.015),
                roughness: 0.56,
                metallic: 0
            )
            head?.scale = SIMD3<Float>(0.90, 0.98, 0.94)
            proceduralRoot.addChild(head!)

            leftEyeWhite = Self.boxEntity(
                size: SIMD3<Float>(0.038, 0.020, 0.010),
                cornerRadius: 0.009,
                position: SIMD3<Float>(-0.038, 0.492, 0.126),
                roughness: 0.12,
                metallic: 0
            )
            rightEyeWhite = Self.boxEntity(
                size: SIMD3<Float>(0.038, 0.020, 0.010),
                cornerRadius: 0.009,
                position: SIMD3<Float>(0.038, 0.492, 0.126),
                roughness: 0.12,
                metallic: 0
            )
            leftIris = Self.sphereEntity(radius: 0.006, position: SIMD3<Float>(-0.038, 0.492, 0.132))
            rightIris = Self.sphereEntity(radius: 0.006, position: SIMD3<Float>(0.038, 0.492, 0.132))
            leftBrow = Self.boxEntity(
                size: SIMD3<Float>(0.034, 0.007, 0.01),
                cornerRadius: 0.004,
                position: SIMD3<Float>(-0.038, 0.518, 0.118),
                roughness: 0.7,
                metallic: 0
            )
            rightBrow = Self.boxEntity(
                size: SIMD3<Float>(0.034, 0.007, 0.01),
                cornerRadius: 0.004,
                position: SIMD3<Float>(0.038, 0.518, 0.118),
                roughness: 0.7,
                metallic: 0
            )
            nose = Self.boxEntity(
                size: SIMD3<Float>(0.012, 0.022, 0.010),
                cornerRadius: 0.007,
                position: SIMD3<Float>(0, 0.454, 0.126),
                roughness: 0.58,
                metallic: 0
            )
            mouth = Self.boxEntity(
                size: SIMD3<Float>(0.034, 0.006, 0.01),
                cornerRadius: 0.006,
                position: SIMD3<Float>(0, 0.425, 0.124),
                roughness: 0.46,
                metallic: 0
            )
            proceduralRoot.addChild(leftEyeWhite!)
            proceduralRoot.addChild(rightEyeWhite!)
            proceduralRoot.addChild(leftIris!)
            proceduralRoot.addChild(rightIris!)
            proceduralRoot.addChild(leftBrow!)
            proceduralRoot.addChild(rightBrow!)
            proceduralRoot.addChild(nose!)
            proceduralRoot.addChild(mouth!)

            hair = Self.boxEntity(
                size: SIMD3<Float>(0.25, 0.13, 0.22),
                cornerRadius: 0.08,
                position: SIMD3<Float>(0, 0.555, -0.005),
                roughness: 0.68,
                metallic: 0
            )
            hair!.scale = SIMD3<Float>(1.0, 1.0, 1.0)
            proceduralRoot.addChild(hair!)

            hairBack = Self.boxEntity(
                size: SIMD3<Float>(0.18, 0.16, 0.08),
                cornerRadius: 0.05,
                position: SIMD3<Float>(0, 0.415, -0.07),
                roughness: 0.7,
                metallic: 0
            )
            proceduralRoot.addChild(hairBack!)

            ponytail = Self.boxEntity(
                size: SIMD3<Float>(0.06, 0.22, 0.06),
                cornerRadius: 0.03,
                position: SIMD3<Float>(-0.12, 0.37, -0.07),
                roughness: 0.72,
                metallic: 0
            )
            proceduralRoot.addChild(ponytail!)

            hairBun = Self.sphereEntity(radius: 0.06, position: SIMD3<Float>(0, 0.57, -0.05))
            proceduralRoot.addChild(hairBun!)

            leftShoulder = Self.boxEntity(
                size: SIMD3<Float>(0.10, 0.08, 0.12),
                cornerRadius: 0.04,
                position: SIMD3<Float>(-0.25, 0.2, 0.01),
                roughness: 0.46,
                metallic: 0.06
            )
            rightShoulder = Self.boxEntity(
                size: SIMD3<Float>(0.10, 0.08, 0.12),
                cornerRadius: 0.04,
                position: SIMD3<Float>(0.25, 0.2, 0.01),
                roughness: 0.46,
                metallic: 0.06
            )
            proceduralRoot.addChild(leftShoulder!)
            proceduralRoot.addChild(rightShoulder!)

            leftArm = Self.cylinderEntity(height: 0.40, radius: 0.045, position: SIMD3<Float>(-0.35, 0.06, 0.01))
            leftArm!.orientation = QE.mul(QE.euler(0, 0, 0.35), QE.euler(0, 0, Float.pi / 2))
            proceduralRoot.addChild(leftArm!)

            rightArm = Self.cylinderEntity(height: 0.40, radius: 0.045, position: SIMD3<Float>(0.35, 0.06, 0.01))
            rightArm!.orientation = QE.mul(QE.euler(0, 0, -0.35), QE.euler(0, 0, Float.pi / 2))
            proceduralRoot.addChild(rightArm!)

            baseRightArmQ = rightArm!.orientation
            baseLeftArmQ = leftArm!.orientation

            leftLeg = Self.cylinderEntity(height: 0.50, radius: 0.055, position: SIMD3<Float>(-0.12, -0.43, 0.01))
            proceduralRoot.addChild(leftLeg!)

            rightLeg = Self.cylinderEntity(height: 0.50, radius: 0.055, position: SIMD3<Float>(0.12, -0.43, 0.01))
            proceduralRoot.addChild(rightLeg!)

            leftShoe = Self.boxEntity(
                size: SIMD3<Float>(0.16, 0.065, 0.26),
                cornerRadius: 0.03,
                position: SIMD3<Float>(-0.12, -0.71, 0.05),
                roughness: 0.3,
                metallic: 0.08
            )
            rightShoe = Self.boxEntity(
                size: SIMD3<Float>(0.16, 0.065, 0.26),
                cornerRadius: 0.03,
                position: SIMD3<Float>(0.12, -0.71, 0.05),
                roughness: 0.3,
                metallic: 0.08
            )
            proceduralRoot.addChild(leftShoe!)
            proceduralRoot.addChild(rightShoe!)

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
            guard allowsBundledHero else {
                heroUSDZ?.removeFromParent()
                heroUSDZ = nil
                proceduralRoot.isEnabled = true
                return
            }
            guard let url = Bundle.main.url(forResource: "AvatarHero", withExtension: "usdz") else { return }
            Task {
                do {
                    let hero: Entity
                    if #available(iOS 18.0, *) {
                        hero = try await Entity(contentsOf: url)
                    } else {
                        hero = try await Task.detached(priority: .userInitiated) {
                            try Entity.load(contentsOf: url)
                        }.value
                    }
                    await MainActor.run {
                        hero.position = SIMD3<Float>(0, -0.58, 0)
                        staging.addChild(hero)
                        self.heroUSDZ = hero
                        self.proceduralRoot.isEnabled = false
                    }
                } catch {
                    await MainActor.run {
                        self.heroUSDZ = nil
                        self.proceduralRoot.isEnabled = true
                    }
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
            let jerseyStripe = spec.topAccent == .clear ? spec.top.brightened(0.22) : spec.topAccent.brightened(0.08)
            let auraTint = spec.racketAccent == .clear
                ? (spec.topAccent == .clear ? spec.top.brightened(0.14) : spec.topAccent)
                : spec.racketAccent

            torso?.model?.materials = [Self.mat(topFinal, roughness: 0.48)]
            chestBand?.model?.materials = [Self.mat(jerseyStripe, roughness: 0.2, metallic: 0.08)]
            neck?.model?.materials = [Self.mat(spec.skin, roughness: 0.56)]
            shorts?.model?.materials = [Self.mat(bottomFinal, roughness: 0.52)]
            head?.model?.materials = [Self.mat(spec.skin, roughness: 0.56)]
            leftEyeWhite?.model?.materials = [Self.mat(UIColor.white.withAlphaComponent(0.98), roughness: 0.1, metallic: 0)]
            rightEyeWhite?.model?.materials = [Self.mat(UIColor.white.withAlphaComponent(0.98), roughness: 0.1, metallic: 0)]
            leftIris?.model?.materials = [Self.mat(UIColor(red: 0.22, green: 0.16, blue: 0.12, alpha: 1), roughness: 0.24, metallic: 0)]
            rightIris?.model?.materials = [Self.mat(UIColor(red: 0.22, green: 0.16, blue: 0.12, alpha: 1), roughness: 0.24, metallic: 0)]
            leftBrow?.model?.materials = [Self.mat(spec.hair.darkened(0.22), roughness: 0.72, metallic: 0)]
            rightBrow?.model?.materials = [Self.mat(spec.hair.darkened(0.22), roughness: 0.72, metallic: 0)]
            nose?.model?.materials = [Self.mat(spec.skin.multiplied(by: UIColor(white: 0.96, alpha: 1)), roughness: 0.58, metallic: 0)]
            mouth?.model?.materials = [Self.mat(spec.skin.multiplied(by: UIColor(red: 0.92, green: 0.72, blue: 0.74, alpha: 1)), roughness: 0.42, metallic: 0)]
            hair?.model?.materials = [Self.mat(spec.hair, roughness: 0.68)]
            hairBack?.model?.materials = [Self.mat(spec.hair, roughness: 0.72)]
            ponytail?.model?.materials = [Self.mat(spec.hair, roughness: 0.74)]
            hairBun?.model?.materials = [Self.mat(spec.hair, roughness: 0.72)]
            hair?.isEnabled = spec.showsHair
            hairBack?.isEnabled = spec.showsHair
            ponytail?.isEnabled = spec.showsHair
            hairBun?.isEnabled = spec.showsHair

            leftArm?.model?.materials = [Self.mat(spec.skin)]
            rightArm?.model?.materials = [Self.mat(spec.skin)]
            leftShoulder?.model?.materials = [Self.mat(topFinal, roughness: 0.42)]
            rightShoulder?.model?.materials = [Self.mat(topFinal, roughness: 0.42)]
            leftLeg?.model?.materials = [Self.mat(spec.skin, roughness: 0.56)]
            rightLeg?.model?.materials = [Self.mat(spec.skin, roughness: 0.56)]
            leftShoe?.model?.materials = [Self.mat(shoeFinal, roughness: 0.24, metallic: 0.18)]
            rightShoe?.model?.materials = [Self.mat(shoeFinal, roughness: 0.24, metallic: 0.18)]

            let rkHead = spec.racketAccent == .clear ? spec.racket : spec.racket.multiplied(by: spec.racketAccent)
            racketHead?.model?.materials = [Self.mat(rkHead, roughness: 0.32, metallic: 0.58)]
            racketHandle?.model?.materials = [Self.mat(spec.racketAccent == .clear ? spec.racket.darkened(0.18) : spec.racketAccent, roughness: 0.32, metallic: 0.64)]
            racketStrings.forEach { $0.model?.materials = [Self.mat(UIColor.white.withAlphaComponent(0.9), roughness: 0.18, metallic: 0.22)] }

            let plateTint = spec.racketAccent == .clear
                ? UIColor(white: 0.16, alpha: 1)
                : spec.racketAccent.multiplied(by: UIColor(red: 0.52, green: 0.52, blue: 0.52, alpha: 1))
            stagePlate?.model?.materials = [Self.mat(plateTint.withAlphaComponent(0.98), roughness: 0.28, metallic: 0.2)]
            stageShadow?.model?.materials = [Self.mat(UIColor.black.withAlphaComponent(0.34), roughness: 1.0, metallic: 0)]
            stageAura?.model?.materials = [Self.mat(auraTint.withAlphaComponent(0.28), roughness: 0.18, metallic: 0)]
            haloDisc?.model?.materials = [Self.mat(auraTint.withAlphaComponent(0.20), roughness: 0.08, metallic: 0)]
            backLight?.model?.materials = [Self.mat(auraTint.brightened(0.24).withAlphaComponent(0.16), roughness: 0.04, metallic: 0)]

            let s = Float(spec.bodyScale)
            hip.scale = SIMD3<Float>(repeating: s)

            switch spec.bodyProfile {
            case .slim:
                torso?.scale = SIMD3<Float>(0.88, 1.0, 0.84)
                chestBand?.scale = SIMD3<Float>(0.9, 1.0, 0.9)
                shorts?.scale = SIMD3<Float>(0.9, 0.95, 0.86)
                leftShoulder?.scale = SIMD3<Float>(0.86, 0.92, 0.86)
                rightShoulder?.scale = SIMD3<Float>(0.86, 0.92, 0.86)
                leftArm?.scale = SIMD3<Float>(0.88, 1.06, 0.88)
                rightArm?.scale = SIMD3<Float>(0.88, 1.06, 0.88)
                leftLeg?.scale = SIMD3<Float>(0.9, 1.08, 0.9)
                rightLeg?.scale = SIMD3<Float>(0.9, 1.08, 0.9)
                leftShoe?.scale = SIMD3<Float>(0.94, 1.0, 0.94)
                rightShoe?.scale = SIMD3<Float>(0.94, 1.0, 0.94)
                head?.scale = SIMD3<Float>(0.97, 1.03, 0.98)
                neck?.scale = SIMD3<Float>(0.94, 1.0, 0.94)
                leftEyeWhite?.scale = SIMD3<Float>(0.96, 1.0, 1.0)
                rightEyeWhite?.scale = SIMD3<Float>(0.96, 1.0, 1.0)
                leftShoulder?.position = SIMD3<Float>(-0.232, 0.18, 0.01)
                rightShoulder?.position = SIMD3<Float>(0.232, 0.18, 0.01)
            case .athletic:
                torso?.scale = SIMD3<Float>(1.0, 1.05, 0.92)
                chestBand?.scale = SIMD3<Float>(0.98, 1.0, 0.96)
                shorts?.scale = SIMD3<Float>(0.94, 0.96, 0.90)
                leftShoulder?.scale = SIMD3<Float>(1.18, 1.0, 1.02)
                rightShoulder?.scale = SIMD3<Float>(1.18, 1.0, 1.02)
                leftArm?.scale = SIMD3<Float>(0.90, 1.14, 0.90)
                rightArm?.scale = SIMD3<Float>(0.90, 1.14, 0.90)
                leftLeg?.scale = SIMD3<Float>(0.94, 1.16, 0.92)
                rightLeg?.scale = SIMD3<Float>(0.94, 1.16, 0.92)
                leftShoe?.scale = SIMD3<Float>(1.0, 1.0, 1.0)
                rightShoe?.scale = SIMD3<Float>(1.0, 1.0, 1.0)
                head?.scale = SIMD3<Float>(0.86, 0.94, 0.90)
                neck?.scale = SIMD3<Float>(0.88, 1.02, 0.88)
                leftEyeWhite?.scale = SIMD3<Float>(1.06, 1.0, 1.0)
                rightEyeWhite?.scale = SIMD3<Float>(1.06, 1.0, 1.0)
                leftShoulder?.position = SIMD3<Float>(-0.286, 0.205, 0.01)
                rightShoulder?.position = SIMD3<Float>(0.286, 0.205, 0.01)
            case .strong:
                torso?.scale = SIMD3<Float>(1.12, 1.03, 1.1)
                chestBand?.scale = SIMD3<Float>(1.06, 1.0, 1.08)
                shorts?.scale = SIMD3<Float>(1.1, 1.0, 1.08)
                leftShoulder?.scale = SIMD3<Float>(1.16, 1.08, 1.14)
                rightShoulder?.scale = SIMD3<Float>(1.16, 1.08, 1.14)
                leftArm?.scale = SIMD3<Float>(1.14, 1.0, 1.14)
                rightArm?.scale = SIMD3<Float>(1.14, 1.0, 1.14)
                leftLeg?.scale = SIMD3<Float>(1.1, 1.0, 1.1)
                rightLeg?.scale = SIMD3<Float>(1.1, 1.0, 1.1)
                leftShoe?.scale = SIMD3<Float>(1.06, 1.02, 1.08)
                rightShoe?.scale = SIMD3<Float>(1.06, 1.02, 1.08)
                head?.scale = SIMD3<Float>(1.0, 1.03, 1.02)
                neck?.scale = SIMD3<Float>(1.08, 1.02, 1.08)
                leftEyeWhite?.scale = SIMD3<Float>(1.04, 1.0, 1.0)
                rightEyeWhite?.scale = SIMD3<Float>(1.04, 1.0, 1.0)
                leftShoulder?.position = SIMD3<Float>(-0.262, 0.19, 0.01)
                rightShoulder?.position = SIMD3<Float>(0.262, 0.19, 0.01)
            }

            switch spec.hairProfile {
            case .bald:
                hair?.isEnabled = false
                hairBack?.isEnabled = false
                ponytail?.isEnabled = false
                hairBun?.isEnabled = false
            case .short:
                hair?.isEnabled = true
                hair?.scale = SIMD3<Float>(1.0, 0.34, 0.98)
                hair?.position = SIMD3<Float>(0, 0.505, -0.005)
                hairBack?.isEnabled = false
                ponytail?.isEnabled = false
                hairBun?.isEnabled = false
            case .medium:
                hair?.isEnabled = true
                hair?.scale = SIMD3<Float>(1.02, 0.48, 1.02)
                hair?.position = SIMD3<Float>(0, 0.49, -0.01)
                hairBack?.isEnabled = true
                hairBack?.scale = SIMD3<Float>(0.96, 0.96, 0.94)
                hairBack?.position = SIMD3<Float>(0, 0.385, -0.072)
                ponytail?.isEnabled = false
                hairBun?.isEnabled = false
            case .long:
                hair?.isEnabled = true
                hair?.scale = SIMD3<Float>(1.04, 0.54, 1.02)
                hair?.position = SIMD3<Float>(0, 0.49, -0.012)
                hairBack?.isEnabled = true
                hairBack?.scale = SIMD3<Float>(0.98, 1.24, 0.96)
                hairBack?.position = SIMD3<Float>(0, 0.35, -0.078)
                ponytail?.isEnabled = false
                hairBun?.isEnabled = false
            case .ponytail:
                hair?.isEnabled = true
                hair?.scale = SIMD3<Float>(1.0, 0.38, 0.98)
                hair?.position = SIMD3<Float>(0, 0.505, -0.005)
                hairBack?.isEnabled = false
                ponytail?.isEnabled = true
                ponytail?.scale = SIMD3<Float>(1.0, 1.0, 1.0)
                ponytail?.position = SIMD3<Float>(-0.11, 0.375, -0.06)
                ponytail?.orientation = QE.euler(0.18, 0.08, -0.12)
                hairBun?.isEnabled = false
            case .bun:
                hair?.isEnabled = true
                hair?.scale = SIMD3<Float>(0.98, 0.34, 0.98)
                hair?.position = SIMD3<Float>(0, 0.505, -0.005)
                hairBack?.isEnabled = false
                ponytail?.isEnabled = false
                hairBun?.isEnabled = true
                hairBun?.scale = SIMD3<Float>(0.9, 0.9, 0.9)
                hairBun?.position = SIMD3<Float>(0, 0.565, -0.04)
            }
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

        private static func discEntity(
            radius: Float,
            height: Float,
            position: SIMD3<Float>,
            roughness: Float = 0.24,
            metallic: Float = 0.02
        ) -> ModelEntity {
            let mesh = MeshResource.generateBox(
                size: SIMD3<Float>(radius * 2, height, radius * 2),
                cornerRadius: min(radius * 0.92, height * 0.46)
            )
            let e = ModelEntity(mesh: mesh, materials: [mat(.white, roughness: roughness, metallic: metallic)])
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
