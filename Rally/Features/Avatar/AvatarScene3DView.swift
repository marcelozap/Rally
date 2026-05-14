import SwiftUI
import SceneKit
import UIKit

/// Visual bundle passed into SceneKit — all UIKit colors so we avoid
/// SwiftUI `Environment` resolution inside `UIViewRepresentable`.
struct AvatarVisualSpec: Equatable {
    var skin: UIColor
    var hair: UIColor
    var showsHair: Bool
    var top: UIColor
    var topAccent: UIColor
    var bottom: UIColor
    var bottomAccent: UIColor
    var shoes: UIColor
    var shoesAccent: UIColor
    var racket: UIColor
    var racketAccent: UIColor
    var bodyScale: CGFloat

    static func from(config: AvatarConfig, preview: (slot: ShopItem.Category, item: ShopItem)?) -> AvatarVisualSpec {
        func ui(hex: String, fallback: UIColor = .lightGray) -> UIColor {
            UIColor(hex: hex) ?? fallback
        }
        let skin = ui(hex: config.skinTone.hex, fallback: UIColor(red: 0.76, green: 0.56, blue: 0.42, alpha: 1))
        let hair = ui(hex: config.hairColorHex, fallback: UIColor(white: 0.2, alpha: 1))

        func item(_ cat: ShopItem.Category) -> ShopItem? {
            if let preview = preview, preview.slot == cat { return preview.item }
            switch cat {
            case .top:    return ShopCatalog.item(id: config.equippedTopID)
            case .bottom: return ShopCatalog.item(id: config.equippedBottomID)
            case .shoes:  return ShopCatalog.item(id: config.equippedShoesID)
            case .racket: return ShopCatalog.item(id: config.equippedRacketID)
            case .bag, .accessory: return nil
            }
        }

        let topIt = item(.top)
        let botIt = item(.bottom)
        let shoIt = item(.shoes)
        let rakIt = item(.racket)

        let scale: CGFloat = {
            switch config.bodyType {
            case .slim:     return 0.94
            case .athletic: return 1.0
            case .strong:   return 1.08
            }
        }()

        return AvatarVisualSpec(
            skin: skin,
            hair: hair,
            showsHair: config.hairStyle != .bald,
            top: topIt.map { ui(hex: $0.colorHex) } ?? .white,
            topAccent: topIt?.accentHex.flatMap { ui(hex: $0) } ?? .clear,
            bottom: botIt.map { ui(hex: $0.colorHex) } ?? UIColor(white: 0.1, alpha: 1),
            bottomAccent: botIt?.accentHex.flatMap { ui(hex: $0) } ?? .clear,
            shoes: shoIt.map { ui(hex: $0.colorHex) } ?? .white,
            shoesAccent: shoIt?.accentHex.flatMap { ui(hex: $0) } ?? UIColor(red: 0, green: 0.9, blue: 1, alpha: 1),
            racket: rakIt.map { ui(hex: $0.colorHex) } ?? UIColor(white: 0.75, alpha: 1),
            racketAccent: rakIt?.accentHex.flatMap { ui(hex: $0) } ?? UIColor(red: 0, green: 0.9, blue: 1, alpha: 1),
            bodyScale: scale
        )
    }
}

/// Shop-focused emotes — short loops that read well on a small stage while
/// browsing outfits.
enum AvatarShopEmote: String, CaseIterable, Identifiable {
    case idle
    case wave
    case celebrate
    case shopLook

    var id: String { rawValue }

    var label: String {
        switch self {
        case .idle:      return "Idle"
        case .wave:      return "Wave"
        case .celebrate: return "Celebrate"
        case .shopLook:  return "Browsing"
        }
    }

    var symbolName: String {
        switch self {
        case .idle:      return "figure.stand"
        case .wave:      return "hand.wave.fill"
        case .celebrate: return "hands.sparkles.fill"
        case .shopLook:  return "eye.fill"
        }
    }
}

/// SceneKit-backed avatar — reads as a soft 3D figure under studio lighting,
/// with idle breathing and emote actions. Falls back gracefully on any
/// SceneKit failure (shouldn't happen on iOS 17).
struct AvatarScene3DView: UIViewRepresentable {

    var spec: AvatarVisualSpec
    var emote: AvatarShopEmote

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.isJitteringEnabled = true
        view.scene = context.coordinator.makeScene()
        context.coordinator.setupAvatar(in: view.scene!)
        context.coordinator.apply(spec: spec)
        context.coordinator.ensureAmbientMotion(for: emote)
        context.coordinator.play(emote: emote)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.apply(spec: spec)
        if context.coordinator.lastEmote != emote {
            context.coordinator.play(emote: emote)
        }
    }

    // MARK: - Coordinator

    final class Coordinator {
        private weak var scene: SCNScene?

        private var avatarRoot: SCNNode!
        private var hip: SCNNode!
        private var torsoNode: SCNNode!
        private var headNode: SCNNode!
        private var hairNode: SCNNode!
        private var leftArm: SCNNode!
        private var rightArm: SCNNode!
        private var leftLeg: SCNNode!
        private var rightLeg: SCNNode!
        private var racketNode: SCNNode!

        private var torsoGeom: SCNBox!
        private var headGeom: SCNSphere!
        private var hairGeom: SCNSphere!
        private var leftArmGeom: SCNCapsule!
        private var rightArmGeom: SCNCapsule!
        private var leftLegGeom: SCNCapsule!
        private var rightLegGeom: SCNCapsule!
        private var racketHeadGeom: SCNBox!
        private var racketHandleGeom: SCNBox!
        private var shortsNode: SCNNode!

        fileprivate var lastEmote: AvatarShopEmote = .idle

        func makeScene() -> SCNScene {
            let scene = SCNScene()
            self.scene = scene

            let camNode = SCNNode()
            camNode.camera = SCNCamera()
            if #available(iOS 18.0, *) {
                camNode.camera?.wantsHDR = true
            }
            camNode.position = SCNVector3(0, 1.05, 3.35)
            camNode.look(at: SCNVector3(0, 0.95, 0))
            scene.rootNode.addChildNode(camNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.color = UIColor(white: 0.35, alpha: 1)
            ambient.light?.intensity = 380
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.color = UIColor(red: 0.95, green: 0.98, blue: 1, alpha: 1)
            key.light?.intensity = 950
            key.light?.castsShadow = true
            key.light?.shadowMode = .deferred
            key.eulerAngles = SCNVector3(-0.55, 0.65, 0)
            key.position = SCNVector3(2, 4, 4)
            scene.rootNode.addChildNode(key)

            let rim = SCNNode()
            rim.light = SCNLight()
            rim.light?.type = .directional
            rim.light?.color = UIColor(red: 0.6, green: 0.85, blue: 1, alpha: 1)
            rim.light?.intensity = 280
            rim.eulerAngles = SCNVector3(0.15, -2.4, 0)
            rim.position = SCNVector3(-3, 2.5, 2)
            scene.rootNode.addChildNode(rim)

            let floor = SCNNode(geometry: {
                let g = SCNFloor()
                g.reflectivity = 0.15
                g.firstMaterial?.diffuse.contents = UIColor(white: 0.06, alpha: 1)
                g.firstMaterial?.metalness.contents = 0.35
                g.firstMaterial?.roughness.contents = 0.55
                return g
            }())
            floor.position = SCNVector3(0, 0, 0)
            scene.rootNode.addChildNode(floor)

            return scene
        }

        func setupAvatar(in scene: SCNScene) {
            avatarRoot = SCNNode()
            avatarRoot.position = SCNVector3(0, 0.02, 0)
            scene.rootNode.addChildNode(avatarRoot)

            hip = SCNNode()
            hip.position = SCNVector3(0, 0.82, 0)
            avatarRoot.addChildNode(hip)

            torsoGeom = SCNBox(width: 0.52, height: 0.44, length: 0.22, chamferRadius: 0.06)
            torsoGeom.firstMaterial = matteMaterial()
            torsoNode = SCNNode(geometry: torsoGeom)
            torsoNode.position = SCNVector3(0, 0.06, 0)
            hip.addChildNode(torsoNode)

            let shortsGeom = SCNBox(width: 0.54, height: 0.16, length: 0.23, chamferRadius: 0.05)
            shortsGeom.firstMaterial = matteMaterial()
            shortsNode = SCNNode(geometry: shortsGeom)
            shortsNode.position = SCNVector3(0, -0.22, 0)
            hip.addChildNode(shortsNode)

            headGeom = SCNSphere(radius: 0.13)
            headGeom.segmentCount = 28
            headGeom.firstMaterial = matteMaterial()
            headNode = SCNNode(geometry: headGeom)
            headNode.position = SCNVector3(0, 0.42, 0)
            hip.addChildNode(headNode)

            hairGeom = SCNSphere(radius: 0.138)
            hairGeom.segmentCount = 20
            hairGeom.firstMaterial = matteMaterial()
            hairNode = SCNNode(geometry: hairGeom)
            hairNode.position = SCNVector3(0, 0.46, -0.02)
            hairNode.scale = SCNVector3(1.05, 0.55, 1.05)
            hip.addChildNode(hairNode)

            leftArmGeom = SCNCapsule(capRadius: 0.045, height: 0.34)
            leftArmGeom.firstMaterial = matteMaterial()
            leftArm = SCNNode(geometry: leftArmGeom)
            leftArm.position = SCNVector3(-0.34, 0.08, 0)
            leftArm.eulerAngles = SCNVector3(0, 0, 0.35)
            hip.addChildNode(leftArm)

            rightArmGeom = SCNCapsule(capRadius: 0.045, height: 0.34)
            rightArmGeom.firstMaterial = matteMaterial()
            rightArm = SCNNode(geometry: rightArmGeom)
            rightArm.position = SCNVector3(0.34, 0.08, 0)
            rightArm.eulerAngles = SCNVector3(0, 0, -0.35)
            hip.addChildNode(rightArm)

            leftLegGeom = SCNCapsule(capRadius: 0.055, height: 0.42)
            leftLegGeom.firstMaterial = matteMaterial()
            leftLeg = SCNNode(geometry: leftLegGeom)
            leftLeg.position = SCNVector3(-0.13, -0.38, 0)
            hip.addChildNode(leftLeg)

            rightLegGeom = SCNCapsule(capRadius: 0.055, height: 0.42)
            rightLegGeom.firstMaterial = matteMaterial()
            rightLeg = SCNNode(geometry: rightLegGeom)
            rightLeg.position = SCNVector3(0.13, -0.38, 0)
            hip.addChildNode(rightLeg)

            racketHeadGeom = SCNBox(width: 0.26, height: 0.34, length: 0.03, chamferRadius: 0.02)
            racketHeadGeom.firstMaterial = glossyMaterial()
            racketHandleGeom = SCNBox(width: 0.05, height: 0.36, length: 0.05, chamferRadius: 0.015)
            racketHandleGeom.firstMaterial = glossyMaterial()

            let head = SCNNode(geometry: racketHeadGeom)
            let handle = SCNNode(geometry: racketHandleGeom)
            handle.position = SCNVector3(0, -0.32, 0)

            racketNode = SCNNode()
            racketNode.addChildNode(head)
            racketNode.addChildNode(handle)
            racketNode.position = SCNVector3(0.52, 0.02, 0.1)
            racketNode.eulerAngles = SCNVector3(0.35, 0, -0.45)
            hip.addChildNode(racketNode)
        }

        private func matteMaterial() -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor.white
            m.metalness.contents = 0.08
            m.roughness.contents = 0.72
            return m
        }

        private func glossyMaterial() -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor.white
            m.metalness.contents = 0.55
            m.roughness.contents = 0.28
            return m
        }

        func apply(spec: AvatarVisualSpec) {
            guard torsoGeom != nil else { return }

            let s = spec.bodyScale
            hip.scale = SCNVector3(s, s, s)

            headGeom.firstMaterial?.diffuse.contents = spec.skin
            leftArmGeom.firstMaterial?.diffuse.contents = spec.skin
            rightArmGeom.firstMaterial?.diffuse.contents = spec.skin
            leftLegGeom.firstMaterial?.diffuse.contents = spec.shoes
            rightLegGeom.firstMaterial?.diffuse.contents = spec.shoes
            leftLegGeom.firstMaterial?.multiply.contents = spec.shoesAccent == .clear ? UIColor.white : spec.shoesAccent.withAlphaComponent(0.85)
            rightLegGeom.firstMaterial?.multiply.contents = spec.shoesAccent == .clear ? UIColor.white : spec.shoesAccent.withAlphaComponent(0.85)

            hairGeom.firstMaterial?.diffuse.contents = spec.hair
            hairNode.isHidden = !spec.showsHair

            torsoGeom.firstMaterial?.diffuse.contents = spec.top
            if spec.topAccent != .clear {
                torsoGeom.firstMaterial?.multiply.contents = spec.topAccent
            } else {
                torsoGeom.firstMaterial?.multiply.contents = UIColor.white
            }

            if let shortsGeom = shortsNode.geometry as? SCNBox {
                shortsGeom.firstMaterial?.diffuse.contents = spec.bottom
                if spec.bottomAccent != .clear {
                    shortsGeom.firstMaterial?.multiply.contents = spec.bottomAccent
                } else {
                    shortsGeom.firstMaterial?.multiply.contents = UIColor.white
                }
            }

            racketHeadGeom.firstMaterial?.diffuse.contents = spec.racket
            racketHeadGeom.firstMaterial?.multiply.contents = spec.racketAccent == .clear ? UIColor.white : spec.racketAccent
            racketHandleGeom.firstMaterial?.diffuse.contents = spec.racketAccent
        }

        /// Always-on subtle motion + optional hip sway. Celebrate turns off
        /// bob/sway so the jump read isn't fighting other translations.
        func ensureAmbientMotion(for emote: AvatarShopEmote) {
            avatarRoot.removeAction(forKey: "idle")
            hip.removeAction(forKey: "idleSway")

            if emote != .celebrate {
                let bob = SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.012, z: 0, duration: 1.4),
                    SCNAction.moveBy(x: 0, y: -0.012, z: 0, duration: 1.4)
                ])
                bob.timingMode = .easeInEaseOut
                avatarRoot.runAction(.repeatForever(bob), forKey: "idle")
            }

            if emote == .idle || emote == .wave {
                let sway = SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: 0.06, z: 0, duration: 2.2, usesShortestUnitArc: true),
                    SCNAction.rotateTo(x: 0, y: -0.06, z: 0, duration: 2.2, usesShortestUnitArc: true)
                ])
                sway.timingMode = .easeInEaseOut
                hip.runAction(.repeatForever(sway), forKey: "idleSway")
            }
        }

        func play(emote: AvatarShopEmote) {
            lastEmote = emote

            avatarRoot.removeAction(forKey: "emote")
            hip.removeAction(forKey: "emotePitch")
            hip.removeAction(forKey: "emote")
            leftArm.removeAction(forKey: "emote")
            rightArm.removeAction(forKey: "emote")
            racketNode.removeAction(forKey: "emote")

            ensureAmbientMotion(for: emote)

            let baseRArm = SCNVector3(0, 0, -0.35)
            let baseLArm = SCNVector3(0, 0, 0.35)

            switch emote {
            case .idle:
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.35
                rightArm.eulerAngles = baseRArm
                leftArm.eulerAngles = baseLArm
                racketNode.eulerAngles = SCNVector3(0.35, 0, -0.45)
                hip.eulerAngles = SCNVector3(0, 0, 0)
                SCNTransaction.commit()

            case .wave:
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.25
                hip.eulerAngles = SCNVector3(0, 0, 0)
                leftArm.eulerAngles = baseLArm
                racketNode.eulerAngles = SCNVector3(0.35, 0, -0.45)
                SCNTransaction.commit()

                rightArm.eulerAngles = baseRArm
                let wave = SCNAction.sequence([
                    SCNAction.rotateTo(x: -0.9, y: 0, z: -1.1, duration: 0.22, usesShortestUnitArc: true),
                    SCNAction.rotateTo(x: -0.5, y: 0, z: -0.5, duration: 0.18, usesShortestUnitArc: true),
                    SCNAction.rotateTo(x: -0.9, y: 0, z: -1.1, duration: 0.22, usesShortestUnitArc: true),
                    SCNAction.rotateTo(x: -0.5, y: 0, z: -0.35, duration: 0.35, usesShortestUnitArc: true)
                ])
                wave.timingMode = .easeInEaseOut
                rightArm.runAction(.repeatForever(.sequence([wave, SCNAction.wait(duration: 2.0)])),
                                   forKey: "emote")

            case .celebrate:
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.3
                hip.eulerAngles = SCNVector3(0, 0, 0)
                racketNode.eulerAngles = SCNVector3(0.65, 0.2, -0.35)
                SCNTransaction.commit()

                let armWave = SCNAction.sequence([
                    SCNAction.rotateTo(x: -1.85, y: 0.18, z: -0.82, duration: 0.34, usesShortestUnitArc: true),
                    SCNAction.rotateTo(x: -2.05, y: 0.12, z: -0.95, duration: 0.16, usesShortestUnitArc: true),
                    SCNAction.rotateTo(x: baseRArm.x, y: baseRArm.y, z: baseRArm.z, duration: 0.42, usesShortestUnitArc: true),
                    SCNAction.wait(duration: 2.1)
                ])
                armWave.timingMode = .easeInEaseOut

                let armWaveL = SCNAction.sequence([
                    SCNAction.rotateTo(x: -1.85, y: -0.18, z: 0.82, duration: 0.34, usesShortestUnitArc: true),
                    SCNAction.rotateTo(x: -2.05, y: -0.12, z: 0.95, duration: 0.16, usesShortestUnitArc: true),
                    SCNAction.rotateTo(x: baseLArm.x, y: baseLArm.y, z: baseLArm.z, duration: 0.42, usesShortestUnitArc: true),
                    SCNAction.wait(duration: 2.1)
                ])
                armWaveL.timingMode = .easeInEaseOut

                rightArm.runAction(.repeatForever(armWave), forKey: "emote")
                leftArm.runAction(.repeatForever(armWaveL), forKey: "emote")

                let jump = SCNAction.repeatForever(.sequence([
                    SCNAction.moveBy(x: 0, y: 0.065, z: 0, duration: 0.20),
                    SCNAction.moveBy(x: 0, y: -0.065, z: 0, duration: 0.24),
                    SCNAction.wait(duration: 2.35)
                ]))
                jump.timingMode = .easeInEaseOut
                hip.runAction(jump, forKey: "emote")

            case .shopLook:
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                hip.eulerAngles = SCNVector3(0.08, 0.35, 0)
                rightArm.eulerAngles = SCNVector3(-0.45, 0.15, -0.95)
                racketNode.eulerAngles = SCNVector3(0.55, -0.25, -0.25)
                leftArm.eulerAngles = SCNVector3(0.15, 0.12, 0.55)
                SCNTransaction.commit()

                let glance = SCNAction.sequence([
                    SCNAction.rotateTo(x: 0.08, y: -0.25, z: 0, duration: 1.8, usesShortestUnitArc: true),
                    SCNAction.rotateTo(x: 0.08, y: 0.42, z: 0, duration: 2.0, usesShortestUnitArc: true)
                ])
                glance.timingMode = .easeInEaseOut
                hip.runAction(.repeatForever(glance), forKey: "emotePitch")
            }
        }
    }
}

// MARK: - UIColor hex

private extension UIColor {
    convenience init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
