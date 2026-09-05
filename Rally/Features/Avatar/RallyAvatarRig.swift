import SceneKit
import UIKit

/// The same skinned human and wardrobe are used by every preview and both court players.
/// Assets are authored in meters, Y up, +Z forward; bones retain world axes at bind pose.
final class RallyAvatarRig {
    enum Presentation { case studio, gameplay, opponent }

    let scene = SCNScene()
    let camera = SCNNode()
    let root = SCNNode()
    private let skeleton = SCNNode()
    private let wardrobe = SCNNode()
    private let hairRoot = SCNNode()
    private let racket = SCNNode()
    private let racketHead = SCNNode()
    private let assetLoader: (String) throws -> RallyHumanMesh
    private var athletePreset: RallyAthletePreset = .maleEuropean
    private var athleteModel: RallyAthleteModel { athletePreset.athleteModel }
    private var stature: Float = 1
    private var groundOffset: Float = 0.0177
    private let presentation: Presentation
    private var bones: [SCNNode] = []
    private var boneByName: [String: SCNNode] = [:]
    private var inverseBind: [NSValue] = []
    private var bindPosition: [String: SIMD3<Float>] = [:]
    private var appearance: RallyAvatarAppearance?
    private var skinMaterial = SCNMaterial()
    private var hairMaterial = SCNMaterial()
    private var racketMaterial = SCNMaterial()
    private var racketGripMaterial = SCNMaterial()
    private var headAccessories: [SCNNode] = []
    private var showsRacket = true
    private var footwork = RallyAvatarFootwork()
    private(set) var assetError: String?
    var yaw: Float = -0.20

    var racketHeadWorldPosition: SCNVector3 {
        racketHead.convertPosition(SCNVector3Zero, to: nil)
    }

    init(appearance: RallyAvatarAppearance, presentation: Presentation = .studio, assetLoader: @escaping (String) throws -> RallyHumanMesh = RallyHumanMesh.load) {
        self.assetLoader = assetLoader
        self.presentation = presentation
        scene.rootNode.addChildNode(root)
        root.name = "Rally athlete"
        root.addChildNode(skeleton)
        root.addChildNode(wardrobe)
        configureStudio()
        rebuildModel(appearance)
    }

    private func loadMesh(_ name: String) throws -> RallyHumanMesh {
        let identityAsset = name == "athlete" || name == "eyes" || name.hasPrefix("hair-")
        let prefix = identityAsset ? identityPrefix : (athleteModel == .female ? "female-" : "")
        return try assetLoader(prefix + name)
    }

    private var identityPrefix: String {
        switch athletePreset {
        case .maleEuropean: return ""
        case .maleAsian: return "male-asian-"
        case .maleBlack: return "male-black-"
        case .femaleEuropean: return "female-"
        case .femaleAsian: return "female-asian-"
        case .femaleBlack: return "female-black-"
        }
    }

    private var skinTextureName: String {
        switch athletePreset {
        case .maleEuropean: return "skin-diffuse"
        case .maleAsian: return "male-asian-skin-diffuse"
        case .maleBlack: return "skin-dark-diffuse"
        case .femaleEuropean: return "female-skin-diffuse"
        case .femaleAsian: return "female-asian-skin-diffuse"
        case .femaleBlack: return "female-skin-dark-diffuse"
        }
    }

    private func rebuildModel(_ look: RallyAvatarAppearance) {
        footwork.reset()
        // Keep the scene/camera stable when switching models, including rotation and zoom.
        root.isHidden = true
        root.childNodes.forEach { $0.removeFromParentNode() }
        skeleton.childNodes.forEach { $0.removeFromParentNode() }
        wardrobe.childNodes.forEach { $0.removeFromParentNode() }
        racket.removeFromParentNode()
        racket.childNodes.forEach { $0.removeFromParentNode() }
        racketHead.childNodes.forEach { $0.removeFromParentNode() }
        hairRoot.removeFromParentNode()
        hairRoot.childNodes.forEach { $0.removeFromParentNode() }
        headAccessories.removeAll()
        collarNode = nil
        skirtNode = nil
        bones.removeAll()
        boneByName.removeAll()
        bindPosition.removeAll()
        inverseBind.removeAll()
        appearance = nil
        athletePreset = look.athletePreset
        assetError = nil
        root.addChildNode(skeleton)
        root.addChildNode(wardrobe)
        do {
            let human = try loadMesh("athlete")
            // Head identity must not change garment cut lines or hand reach.
            stature = athleteModel == .female ? 1.73 / 1.78 : 1
            if let shoes = try? loadMesh("shoes"), let sole = stride(from: 1, to: shoes.positions.count, by: 3).map({ shoes.positions[$0] }).min() {
                groundOffset = -sole
            } else {
                groundOffset = 0.0177 * stature
            }
            createSkeleton(human)
            skinMaterial = Self.material(color: .white, roughness: 0.60)
            if let image = Self.image(skinTextureName) { skinMaterial.diffuse.contents = image }
            skinMaterial.specular.contents = UIColor(white: 0.24, alpha: 1)
            // Clothing is mandatory on every surface, including the first rendered frame.
            let body = skin(human, material: skinMaterial)
            body.name = "Human skin"
            root.addChildNode(body)
            createEyes()
            createRacket()
            apply(look)
            setRacketVisible(showsRacket)
            animate(time: 0)
        } catch {
            assetError = "Player model could not be loaded"
            root.isHidden = true
            NSLog("Rally 3D asset error: %@", String(describing: error))
        }
    }

    func apply(_ newAppearance: RallyAvatarAppearance) {
        if newAppearance.athletePreset != athletePreset {
            rebuildModel(newAppearance)
            return
        }
        guard appearance != newAppearance, !bones.isEmpty else { return }
        let previous = appearance
        appearance = newAppearance
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        applySkinColor(newAppearance)
        // Two authored athletic models; old body-profile values are migration data only.
        root.scale = SCNVector3(1, 1, 1)
        racketMaterial.diffuse.contents = newAppearance.racketUIColor
        racketGripMaterial.diffuse.contents = newAppearance.racketAccentUIColor
        if previous?.hairStyle != newAppearance.hairStyle || previous?.hairColorHex != newAppearance.hairColorHex || previous?.hairColorOverrideHex != newAppearance.hairColorOverrideHex || previous?.headband != newAppearance.headband {
            createHair(newAppearance)
        }
        if previous?.top != newAppearance.top || previous?.shorts != newAppearance.shorts || previous?.shoes != newAppearance.shoes || previous?.socks != newAppearance.socks || previous == nil {
            createWardrobe(newAppearance)
        }
        SCNTransaction.commit()
    }

    private func applySkinColor(_ look: RallyAvatarAppearance) {
        skinMaterial.multiply.contents = UIColor.white
        skinMaterial.diffuse.intensity = 1
        skinMaterial.shaderModifiers = nil
        let texture = look.skinToneOverrideHex == nil ? skinTextureName : (athleteModel == .female ? "female-skin-diffuse" : "skin-diffuse")
        guard let image = Self.image(texture) else {
            skinMaterial.diffuse.contents = look.skinUIColor
            return
        }
        skinMaterial.diffuse.contents = image
        guard look.skinToneOverrideHex != nil else { return }
        // Recolor a shared light atlas in linear light, retaining its skin detail.
        // The selected face, body, bind pose and garment fit never change.
        let target = Self.linearRGB(look.skinUIColor)
        let base = Self.linearRGB(UIColor(hexString: AvatarSkinTone.light.hex) ?? .white)
        let ratio = target / simd_max(base, SIMD3<Float>(repeating: 0.001))
        skinMaterial.shaderModifiers = [.surface: """
        #pragma body
        _surface.diffuse.rgb = clamp(_surface.diffuse.rgb * float3(\(ratio.x), \(ratio.y), \(ratio.z)), 0.0, 1.0);
        """]
    }

    private static func linearRGB(_ color: UIColor) -> SIMD3<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ value: CGFloat) -> Float {
            let v = Float(value)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return SIMD3(linear(r), linear(g), linear(b))
    }

    func setRacketVisible(_ visible: Bool) {
        showsRacket = visible
        racket.isHidden = !visible
    }

    /// Articulated movement leaves the character's body proportions intact.
    func animate(time: TimeInterval, swingProgress: Float? = nil, backhand: Bool = false, lateral: Float = 0, leftHanded: Bool = false, courtPosition: Float? = nil) {
        guard !bones.isEmpty else { return }
        let breath = Float(sin(time * 1.65))
        let studio = presentation == .studio
        let progress = min(1, max(0, swingProgress ?? 0))
        let swing = swingProgress == nil ? Float(0) : sin(progress * .pi)
        let follow = swingProgress == nil ? Float(0) : sin(max(0, progress - 0.35) / 0.65 * .pi)
        let hand: Float = leftHanded ? -1 : 1
        let turn: Float = (backhand ? -1 : 1) * hand
        for bone in bones { bone.eulerAngles = SCNVector3Zero }
        root.eulerAngles.y = studio ? yaw + Float(sin(time * 0.72)) * 0.018 : (presentation == .gameplay ? Float.pi - 0.22 : -0.15)
        root.position.y = groundOffset
        let gait: RallyAvatarFootwork.Pose
        if !studio, let courtPosition,
           let left = bindPosition["foot.L"], let right = bindPosition["foot.R"] {
            let leftRest = root.simdWorldOrientation.act(left + SIMD3<Float>(0.026, 0, 0)).x
            let rightRest = root.simdWorldOrientation.act(right - SIMD3<Float>(0.026, 0, 0)).x
            gait = footwork.sample(time: time, courtPosition: courtPosition,
                                   leftRestX: leftRest, rightRestX: rightRest, scale: stature)
        } else {
            footwork.reset()
            gait = RallyAvatarFootwork.Pose()
        }
        // The SK3DNode is translated outside this SCNScene. Convert its court
        // movement back through the avatar's yaw, including the local Z term.
        let courtToRoot = simd_inverse(root.simdWorldOrientation)
        let pelvisTravel = courtToRoot.act(SIMD3<Float>(gait.pelvisOffset, 0, 0))
        let weightShift = studio ? Float(sin(time * 1.35)) * 0.035 : lateral * 0.018 + pelvisTravel.x
        let readyDrop: Float = studio ? 0.052 + Float(cos(time * 2.7)) * 0.010 : 0.028 + gait.pelvisDrop
        if let hip = boneByName["root"], let neutral = bindPosition["root"] {
            hip.simdPosition = neutral + SIMD3<Float>(weightShift, -readyDrop - swing * 0.014 + breath * 0.002, pelvisTravel.z)
        }
        rotate("spine03", x: studio ? 0.075 : 0.035, y: turn * swing * 0.30, z: -weightShift * 0.7)
        rotate("spine01", x: breath * 0.006, y: turn * (swing * 0.34 - follow * 0.28))
        rotate("neck01", y: -turn * swing * 0.14)
        rotate("head", x: -0.025, y: studio ? 0.06 : 0)

        // MakeHuman's rest pose is a relaxed A-pose. Close shoulders, then flex elbows.
        for (suffix, side) in [("L", Float(1)), ("R", Float(-1))] {
            let dominant = leftHanded ? side > 0 : side < 0
            let active = dominant || backhand
            let shoulderClose: Float = studio ? 0.16 : 0.28
            rotate("upperarm01.\(suffix)", x: active ? -0.16 - swing * 0.76 : -0.08,
                   y: active ? turn * swing * 0.32 : 0, z: -side * (shoulderClose + breath * 0.008))
            rotate("lowerarm01.\(suffix)", x: dominant ? -0.30 - swing * 0.55 : (backhand ? -0.55 - swing * 0.55 : -0.14),
                   z: active ? side * swing * 0.16 : 0)
            rotate("wrist.\(suffix)", y: dominant ? -turn * follow * 0.42 : 0)
            if !studio {
                rotate("upperleg01.\(suffix)", x: -0.028 - swing * 0.08, z: -side * 0.012)
                rotate("lowerleg01.\(suffix)", x: 0.04 + swing * 0.13)
            }
            // The supporting hand stays relaxed; the anatomical grip below
            // articulates the dominant fingers around the racket handle.
            for finger in 2...5 {
                for joint in 1...3 {
                    rotate("finger\(finger)-\(joint).\(suffix)", x: -0.16)
                }
            }
        }
        let dominantSuffix = leftHanded ? "L" : "R"
        let supportSuffix = leftHanded ? "R" : "L"
        if studio && swingProgress == nil {
            solveArm(dominantSuffix, target: SIMD3<Float>(-0.29 * hand + weightShift * 0.6, 1.15 + breath * 0.006, 0.32))
            solveArm(supportSuffix, target: SIMD3<Float>(0.18 * hand + weightShift * 0.6, 1.15 + breath * 0.005, 0.30))
        } else {
            let dominantX: Float = (backhand ? 0.26 : -0.46) * hand
            let wristY: Float = 1.21 + swing * 0.15
            let dominantTarget = SIMD3<Float>(dominantX, wristY, 0.31)
            solveArm(dominantSuffix, target: dominantTarget)
            let supportTarget = backhand && swingProgress != nil
                ? dominantTarget + SIMD3<Float>(0.055 * hand, 0.065, -0.015)
                : SIMD3<Float>(0.30 * hand, 1.10, 0.18)
            solveArm(supportSuffix, target: supportTarget)
        }
        let wrist = boneByName[dominantSuffix == "L" ? "wrist.L" : "wrist.R"]
        if racket.parent !== wrist {
            racket.removeFromParentNode()
            wrist?.addChildNode(racket)
        }
        let gripAngle: Float = studio ? 0.28 * hand : (backhand ? 0.12 * hand : -0.22 * hand)
        poseRacketGrip(side: dominantSuffix, hand: hand, gripAngle: gripAngle)
        for side in ["L", "R"] {
            guard let ankle = bindPosition["foot.\(side)"] else { continue }
            // Studio/nil callers retain the planted split stance. During court
            // travel the supporting shoe compensates for outer-root movement.
            let spread: Float = (side == "L" ? 1 : -1) * (studio ? 0.045 : 0.026)
            let footPose = side == "L" ? gait.left : gait.right
            let travel = courtToRoot.act(SIMD3<Float>(footPose.offset, 0, 0))
            solveChain(upperName: "upperleg01.\(side)", lowerName: "lowerleg01.\(side)",
                       endName: "foot.\(side)", target: ankle + SIMD3<Float>(spread, footPose.lift, 0) + travel,
                       pole: SIMD3<Float>(spread, 0, 1))
            if let foot = boneByName["foot.\(side)"], let parent = foot.parent {
                foot.simdOrientation = simd_inverse(parent.simdWorldOrientation) * root.simdWorldOrientation
            }
        }
    }

    /// The bind skeleton uses common world axes, not hand-local axes. Recover
    /// the palm's width/length basis before orienting the wrist or curling fingers.
    private func poseRacketGrip(side: String, hand: Float, gripAngle: Float) {
        guard let wrist = boneByName["wrist.\(side)"], let parent = wrist.parent,
              let wristBind = bindPosition["wrist.\(side)"],
              let index = bindPosition["finger2-1.\(side)"],
              let middle = bindPosition["finger3-1.\(side)"],
              let pinky = bindPosition["finger5-1.\(side)"] else { return }
        let restUp = simd_normalize(index - pinky)
        let palmLength = middle - wristBind
        let restForward = simd_normalize(palmLength - restUp * simd_dot(palmLength, restUp))
        let restNormal = simd_normalize(simd_cross(restUp, restForward))
        // Mirroring anatomy reverses which side of this right-handed basis is
        // the palm. Flex toward the palm on either hand.
        let palmNormal = restNormal * hand
        let restBasis = simd_float3x3(columns: (restNormal, restUp, restForward))

        let racketInRoot = simd_quatf(angle: gripAngle, axis: SIMD3<Float>(0, 0, 1))
            * simd_quatf(angle: -0.16, axis: SIMD3<Float>(1, 0, 0))
        let up = racketInRoot.act(SIMD3<Float>(0, 1, 0))
        let direction = simd_normalize(SIMD3<Float>(-hand * 0.7, 0, 0.7))
        let forward = simd_normalize(direction - up * simd_dot(direction, up))
        let normal = simd_normalize(simd_cross(up, forward))
        let targetBasis = simd_float3x3(columns: (normal, up, forward))
        let wristInRoot = simd_quatf(targetBasis * simd_transpose(restBasis))
        wrist.simdOrientation = simd_inverse(parent.simdWorldOrientation) * root.simdWorldOrientation * wristInRoot

        for finger in 2...5 {
            for (joint, angle) in [(1, Float(1.20)), (2, Float(1.70)), (3, Float(0.90))] {
                boneByName["finger\(finger)-\(joint).\(side)"]?.simdOrientation =
                    simd_quatf(angle: (showsRacket ? angle : 0.14) * hand, axis: restUp)
            }
        }
        // The cylinder sits against the distal palm. Its 0.06m local grip
        // center is aligned here, independent of wrist rotation and handedness.
        let gripCenter = (index + pinky) * 0.5 - wristBind + palmNormal * (0.016 * stature)
        if showsRacket,
           let thumb = boneByName["finger1-1.\(side)"],
           let thumbBind = bindPosition["finger1-1.\(side)"],
           let thumbMiddle = bindPosition["finger1-2.\(side)"] {
            let towardGrip = gripCenter + restUp * (0.028 * stature) - (thumbBind - wristBind)
            thumb.simdOrientation = simd_quatf(from: simd_normalize(thumbMiddle - thumbBind),
                                             to: simd_normalize(towardGrip))
            boneByName["finger1-2.\(side)"]?.simdOrientation = simd_quatf(angle: 0.25 * hand, axis: restUp)
            boneByName["finger1-3.\(side)"]?.simdOrientation = simd_quatf(angle: 0.55 * hand, axis: restUp)
        }
        let racketWorld = root.simdWorldOrientation * racketInRoot
        racket.simdOrientation = simd_inverse(wrist.simdWorldOrientation) * racketWorld
        racket.simdPosition = gripCenter - racket.simdOrientation.act(SIMD3<Float>(0, 0.06, 0))
    }

    /// Two-bone IK in the character's coordinates. Split twist bones keep their authored weights.
    private func solveArm(_ side: String, target: SIMD3<Float>) {
        let upperName = "upperarm01.\(side)"
        let lowerName = "lowerarm01.\(side)"
        let wristName = "wrist.\(side)"
        solveChain(upperName: upperName, lowerName: lowerName, endName: wristName,
                   target: target * stature, pole: SIMD3<Float>(side == "L" ? 0.4 : -0.4, -1, 0.15))
    }

    private func solveChain(upperName: String, lowerName: String, endName: String, target: SIMD3<Float>, pole: SIMD3<Float>) {
        guard let upper = boneByName[upperName], let lower = boneByName[lowerName],
              let bindShoulder = bindPosition[upperName], let bindElbow = bindPosition[lowerName],
              let bindWrist = bindPosition[endName], let upperParent = upper.parent else { return }
        let shoulder = root.simdConvertPosition(upper.simdWorldPosition, from: nil)
        let upperLength = simd_distance(bindShoulder, bindElbow)
        let lowerLength = simd_distance(bindElbow, bindWrist)
        let delta = target - shoulder
        let distance = min(upperLength + lowerLength - 0.003, max(0.04, simd_length(delta)))
        let direction = simd_normalize(delta)
        let perpendicular = simd_normalize(pole - direction * simd_dot(pole, direction))
        let cosine = min(0.999, max(-0.999, (upperLength * upperLength + distance * distance - lowerLength * lowerLength) / (2 * upperLength * distance)))
        let elbow = shoulder + direction * (cosine * upperLength) + perpendicular * (sqrt(1 - cosine * cosine) * upperLength)
        let worldShoulder = root.simdConvertPosition(shoulder, to: nil)
        let worldElbow = root.simdConvertPosition(elbow, to: nil)
        let parentDirection = upperParent.simdConvertVector(worldElbow - worldShoulder, from: nil)
        upper.simdOrientation = simd_quatf(from: simd_normalize(bindElbow - bindShoulder), to: simd_normalize(parentDirection))
        guard let lowerParent = lower.parent else { return }
        let reachableTarget = shoulder + direction * distance
        let worldTarget = root.simdConvertPosition(reachableTarget, to: nil)
        let lowerDirection = lowerParent.simdConvertVector(worldTarget - lower.simdWorldPosition, from: nil)
        lower.simdOrientation = simd_quatf(from: simd_normalize(bindWrist - bindElbow), to: simd_normalize(lowerDirection))
    }

    private func rotate(_ name: String, x: Float = 0, y: Float = 0, z: Float = 0) {
        boneByName[name]?.eulerAngles = SCNVector3(x, y, z)
    }

    private func configureStudio() {
        scene.background.contents = UIColor.clear
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1.05
        camera.camera?.zNear = 0.05
        camera.camera?.zFar = 20
        camera.camera?.wantsHDR = true
        camera.camera?.wantsExposureAdaptation = false
        camera.camera?.exposureOffset = 0.10
        camera.position = SCNVector3(0, 0.93, 4)
        scene.rootNode.addChildNode(camera)
        addLight(.ambient, position: SCNVector3Zero, intensity: 300, color: UIColor(white: 0.90, alpha: 1))
        addLight(.directional, position: SCNVector3(-2, 3.5, 4), intensity: 900, color: UIColor(red: 1, green: 0.95, blue: 0.89, alpha: 1))
        addLight(.directional, position: SCNVector3(3, 2, 1), intensity: 450, color: UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 1))
        addLight(.directional, position: SCNVector3(0, 3, -3), intensity: 700, color: .white)
    }

    private func addLight(_ type: SCNLight.LightType, position: SCNVector3, intensity: CGFloat, color: UIColor) {
        let node = SCNNode()
        node.light = SCNLight()
        node.light?.type = type
        node.light?.intensity = intensity
        node.light?.color = color
        node.position = position
        if type != .ambient { node.look(at: SCNVector3(0, 1.0, 0)) }
        scene.rootNode.addChildNode(node)
    }

    private func createSkeleton(_ mesh: RallyHumanMesh) {
        for definition in mesh.bones ?? [] {
            let node = SCNNode()
            node.name = definition.name
            let p = definition.position
            if definition.parent >= 0 {
                let parentPosition = mesh.bones![definition.parent].position
                node.position = SCNVector3(p[0] - parentPosition[0], p[1] - parentPosition[1], p[2] - parentPosition[2])
                bones[definition.parent].addChildNode(node)
            } else {
                node.position = SCNVector3(p[0], p[1], p[2])
                skeleton.addChildNode(node)
            }
            bones.append(node)
            boneByName[definition.name] = node
            bindPosition[definition.name] = SIMD3<Float>(p[0], p[1], p[2])
            inverseBind.append(NSValue(scnMatrix4: SCNMatrix4MakeTranslation(-p[0], -p[1], -p[2])))
        }
    }

    private func skin(_ mesh: RallyHumanMesh, material: SCNMaterial) -> SCNNode {
        let geometry = mesh.geometry()
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        if let weights = mesh.boneWeights, let indices = mesh.boneIndices, !bones.isEmpty {
            let ws = Self.source(weights, semantic: .boneWeights, components: 4)
            let packed = indices.map { UInt16($0) }
            let data = packed.withUnsafeBytes { Data($0) }
            let bs = SCNGeometrySource(data: data, semantic: .boneIndices, vectorCount: packed.count / 4,
                                       usesFloatComponents: false, componentsPerVector: 4, bytesPerComponent: 2, dataOffset: 0, dataStride: 8)
            node.skinner = SCNSkinner(baseGeometry: geometry, bones: bones, boneInverseBindTransforms: inverseBind, boneWeights: ws, boneIndices: bs)
            node.skinner?.skeleton = skeleton
        }
        return node
    }

    private func createEyes() {
        guard let mesh = try? loadMesh("eyes") else { return }
        let material = Self.material(color: .white, roughness: 0.24)
        material.diffuse.contents = Self.image("eyes-diffuse") ?? UIColor(white: 0.86, alpha: 1)
        let node = SCNNode(geometry: mesh.geometry())
        node.geometry?.materials = [material]
        attachAtBindPosition(node, to: "head")
    }

    private func attachAtBindPosition(_ node: SCNNode, to boneName: String) {
        guard let bone = boneByName[boneName], let index = bones.firstIndex(where: { $0 === bone }) else { return }
        let translation = inverseBind[index].scnMatrix4Value
        node.position = SCNVector3(translation.m41, translation.m42, translation.m43)
        bone.addChildNode(node)
    }

    private func createHair(_ look: RallyAvatarAppearance) {
        hairRoot.removeFromParentNode()
        hairRoot.childNodes.forEach { $0.removeFromParentNode() }
        headAccessories.forEach { $0.removeFromParentNode() }
        headAccessories.removeAll()
        let hairAsset = athleteModel == .female ? "hair-ponytail" : (athletePreset == .maleBlack ? "hair-afro" : "hair-short")
        if athletePreset == .maleBlack, let body = try? loadMesh("athlete") {
            // A matte scalp layer under the curl cards prevents their transparent
            // gaps from exposing bright scalp highlights at the crown.
            let scalpMesh = body.selected { _, y, z in
                y > (z > 0.055 ? 1.705 : 1.64) * stature
            }.inflated(0.001)
            let scalp = SCNNode(geometry: scalpMesh.geometry())
            let scalpMaterial = Self.material(color: look.hairUIColor, roughness: 1)
            scalpMaterial.lightingModel = .lambert
            scalp.geometry?.materials = [scalpMaterial]
            hairRoot.addChildNode(scalp)
        }
        if var mesh = try? loadMesh(hairAsset) {
            mesh = mesh.inflated(0.002)
            hairMaterial = Self.material(color: .white, roughness: 0.76)
            // Layered alpha hair cards need diffuse-only lighting; accumulated
            // dielectric highlights otherwise create white patches on dark hair.
            hairMaterial.lightingModel = .lambert
            hairMaterial.specular.contents = UIColor.black
            hairMaterial.diffuse.contents = Self.image(hairAsset == "hair-short" ? "hair-diffuse" : hairAsset + "-diffuse") ?? look.hairUIColor
            hairMaterial.multiply.contents = look.hairUIColor.rallyMixed(with: .white, ratio: 0.14)
            if look.hairColorOverrideHex != nil {
                let tint = Self.linearRGB(look.hairUIColor)
                hairMaterial.multiply.contents = UIColor.white
                // The original dark atlas carries strand detail; multiplying alone
                // cannot produce the lighter hair colors offered by the selector.
                hairMaterial.shaderModifiers = [.surface: """
                #pragma body
                float strand = clamp(dot(_surface.diffuse.rgb, float3(0.2126, 0.7152, 0.0722)) / 0.04, 0.45, 1.6);
                _surface.diffuse.rgb = clamp(float3(\(tint.x), \(tint.y), \(tint.z)) * strand, 0.0, 1.0);
                """]
            }
            hairMaterial.isDoubleSided = true
            hairMaterial.transparencyMode = .dualLayer
            if let alpha = Self.image("hair-alpha") {
                hairMaterial.transparent.contents = alpha
                hairMaterial.transparencyMode = .rgbZero
            }
            let hair = SCNNode(geometry: mesh.geometry())
            hair.geometry?.materials = [hairMaterial]
            hairRoot.addChildNode(hair)
            attachAtBindPosition(hairRoot, to: "head")

        }
        if look.headband != nil {
            let capSelected = look.headband?.id.lowercased().contains("cap") == true
            let band = SCNTorus(ringRadius: 0.085, pipeRadius: capSelected ? 0.018 : 0.008)
            band.ringSegmentCount = 48
            let node = SCNNode(geometry: band)
            node.geometry?.materials = [Self.material(color: look.headbandUIColor, roughness: 0.85)]
            node.scale = SCNVector3(0.87, 1.0, 1.02)
            node.position = SCNVector3(0, 1.704, 0.004)
            let group = SCNNode()
            group.addChildNode(node)
            if capSelected {
                let cap = SCNSphere(radius: 0.09)
                let crown = SCNNode(geometry: cap)
                crown.scale = SCNVector3(0.88, 0.60, 1.08)
                crown.position = SCNVector3(0, 1.727, -0.002)
                crown.geometry?.materials = node.geometry?.materials ?? []
                group.addChildNode(crown)
                let visor = SCNNode(geometry: SCNBox(width: 0.14, height: 0.006, length: 0.095, chamferRadius: 0.025))
                visor.position = SCNVector3(0, 1.713, 0.104)
                visor.geometry?.materials = node.geometry?.materials ?? []
                group.addChildNode(visor)
            }
            group.scale = SCNVector3(stature, stature, stature)
            attachAtBindPosition(group, to: "head")
            headAccessories.append(group)
        }
    }

    private func createWardrobe(_ look: RallyAvatarAppearance) {
        guard let shell = try? loadMesh("helper-tights") else {
            assetError = "Player clothing could not be loaded"
            root.isHidden = true
            return
        }
        wardrobe.childNodes.forEach { $0.removeFromParentNode() }
        collarNode?.removeFromParentNode()
        collarNode = nil
        skirtNode?.removeFromParentNode()
        skirtNode = nil
        root.isHidden = false
        assetError = nil
        let catalog = RallyGarmentCatalog.shared
        let topKind = catalog.garmentKind(for: look.top?.id, slot: .top)
        let tank = topKind == .tank
        let polo = topKind == .polo
        let topReference = look.top.flatMap { catalog.reference(for: $0.id, slot: .top) }
        let specificTop = topReference?.meshName(for: athleteModel).flatMap { try? assetLoader($0) }
        let authoredShirt = try? loadMesh(polo ? "polo" : "shirt")
        var shirt = specificTop ?? (tank ? nil : authoredShirt) ?? shell.selected { x, y, _ in
            y > 1.005 * stature && y < 1.495 * stature && (abs(x) < 0.21 * stature || (!tank && y > 1.27 * stature))
        }.inflated(0.013)
        // Let the shirt fall outside the waistband instead of intersecting the shorts.
        if specificTop == nil {
            for i in stride(from: 0, to: shirt.positions.count, by: 3) {
                let ease = max(0, min(1, (1.16 * stature - shirt.positions[i + 1]) / (0.20 * stature)))
                shirt.positions[i] *= 1 + 0.04 * ease
                shirt.positions[i + 2] += shirt.normals[i + 2] * 0.006 * ease
            }
        }
        let topMaterial = Self.fabric(look.topUIColor, knit: true)
        if let normal = Self.image(polo ? "polo-normal" : "shirt-normal"), !tank, specificTop == nil {
            topMaterial.normal.contents = normal
            topMaterial.normal.contentsTransform = SCNMatrix4Identity
            topMaterial.normal.intensity = 0.6
        }
        let top = skin(shirt, material: topMaterial)
        top.name = tank ? "Tank" : (polo ? "Polo" : "Performance tee")
        wardrobe.addChildNode(top)

        let bottomReference = look.shorts.flatMap { catalog.reference(for: $0.id, slot: .shorts) }
        let specificBottom = bottomReference?.meshName(for: athleteModel).flatMap { try? assetLoader($0) }
        let shorts = specificBottom ?? (try? loadMesh("shorts")) ?? shell.selected { _, y, _ in y > 0.70 * stature && y < 0.98 * stature }.hemmed(lower: 0.70 * stature, upper: 0.98 * stature).inflated(0.008)
        let bottom = skin(shorts, material: Self.fabric(look.shortsUIColor, knit: false))
        bottom.name = "Court shorts"
        wardrobe.addChildNode(bottom)
        let shoes = (try? loadMesh("shoes")) ?? shell.selected { _, y, _ in y < 0.095 * stature }.inflated(0.011)
        let shoeMaterial = Self.material(color: look.shoesUIColor, roughness: 0.58)
        if let texture = Self.image("shoes-diffuse") {
            shoeMaterial.diffuse.contents = texture
            shoeMaterial.multiply.contents = look.shoesUIColor
        }
        let shoe = skin(shoes, material: shoeMaterial)
        shoe.name = "Court shoes"
        wardrobe.addChildNode(shoe)
        let socks = (try? loadMesh("socks")) ?? shell.selected { _, y, _ in y >= 0.08 * stature && y < 0.205 * stature }.inflated(0.004)
        let sockColor = look.socks.flatMap { UIColor(hexString: $0.colorwayHex) } ?? UIColor(white: 0.93, alpha: 1)
        wardrobe.addChildNode(skin(socks, material: Self.fabric(sockColor, knit: true)))
        if catalog.garmentKind(for: look.shorts?.id, slot: .shorts) == .skort && specificBottom == nil { createSkort(look) }
        if polo && authoredShirt == nil && specificTop == nil { createCollar(look) }
    }

    private func createCollar(_ look: RallyAvatarAppearance) {
        let group = SCNNode()
        let material = Self.fabric(look.topUIColor.rallyMixed(with: .white, ratio: 0.06), knit: true)
        for side: Float in [-1, 1] {
            let shape = UIBezierPath()
            shape.move(to: CGPoint(x: 0, y: 0))
            shape.addLine(to: CGPoint(x: 0.045, y: -0.02))
            shape.addLine(to: CGPoint(x: 0.03, y: -0.07))
            shape.close()
            let geometry = SCNShape(path: shape, extrusionDepth: 0.003)
            let node = SCNNode(geometry: geometry)
            node.scale.x = side
            node.position = SCNVector3(side * 0.010, 1.476, 0.082)
            node.geometry?.materials = [material]
            group.addChildNode(node)
        }
        group.scale = SCNVector3(stature, stature, stature)
        attachAtBindPosition(group, to: "spine01")
        // Keep accessory lifetime under the wardrobe while its transform follows the skeleton.
        group.name = "Polo collar"
        collarNode?.removeFromParentNode()
        collarNode = group
    }
    private var collarNode: SCNNode?
    private var skirtNode: SCNNode?

    private func createSkort(_ look: RallyAvatarAppearance) {
        let geometry = SCNCone(topRadius: 0.15, bottomRadius: 0.22, height: 0.31)
        geometry.radialSegmentCount = 64
        let node = SCNNode(geometry: geometry)
        node.scale.z = 0.74
        node.position = SCNVector3(0, 0.88, 0.004)
        node.geometry?.materials = [Self.fabric(look.shortsUIColor, knit: false)]
        let group = SCNNode()
        group.addChildNode(node)
        group.scale = SCNVector3(stature, stature, stature)
        attachAtBindPosition(group, to: "root")
        skirtNode = group
    }

    private func createRacket() {
        racket.name = "Tennis racket"
        racketMaterial = Self.material(color: .gray, roughness: 0.31, metalness: 0.45)
        racketGripMaterial = Self.material(color: .darkGray, roughness: 0.92)
        let grip = SCNCylinder(radius: 0.013, height: 0.17)
        let handle = SCNNode(geometry: grip)
        handle.position.y = 0.06
        handle.geometry?.materials = [racketGripMaterial]
        racket.addChildNode(handle)
        for i in 0..<12 {
            let torus = SCNTorus(ringRadius: 0.0132, pipeRadius: 0.0007)
            torus.ringSegmentCount = 24
            torus.pipeSegmentCount = 4
            let ring = SCNNode(geometry: torus)
            ring.position.y = Float(i) * 0.012 - 0.01
            ring.geometry?.materials = [Self.material(color: UIColor(white: 0.12, alpha: 1), roughness: 0.9)]
            racket.addChildNode(ring)
        }
        for side: Float in [-1, 1] {
            let throat = Self.rod(from: SCNVector3(side * 0.007, 0.13, 0), to: SCNVector3(side * 0.08, 0.32, 0), radius: 0.006)
            throat.geometry?.materials = [racketMaterial]
            racket.addChildNode(throat)
        }
        racketHead.position.y = 0.415
        racket.addChildNode(racketHead)
        let hoop = SCNNode(geometry: SCNTorus(ringRadius: 0.125, pipeRadius: 0.008))
        hoop.eulerAngles.x = .pi / 2
        hoop.scale.z = 1.30
        hoop.geometry?.materials = [racketMaterial]
        racketHead.addChildNode(hoop)
        let strings = Self.material(color: UIColor(white: 0.83, alpha: 1), roughness: 0.84)
        for i in -7...7 {
            let x = Float(i) * 0.015
            let halfY = sqrt(max(0, 1 - x * x / (0.119 * 0.119))) * 0.156
            let vertical = Self.rod(from: SCNVector3(x, -halfY, 0), to: SCNVector3(x, halfY, 0), radius: 0.00065)
            vertical.geometry?.materials = [strings]
            racketHead.addChildNode(vertical)
            let y = Float(i) * 0.020
            let halfX = sqrt(max(0, 1 - y * y / (0.156 * 0.156))) * 0.119
            let horizontal = Self.rod(from: SCNVector3(-halfX, y, 0), to: SCNVector3(halfX, y, 0), radius: 0.00065)
            horizontal.geometry?.materials = [strings]
            racketHead.addChildNode(horizontal)
        }
    }

    private static func rod(from a: SCNVector3, to b: SCNVector3, radius: CGFloat) -> SCNNode {
        let delta = SIMD3<Float>(b.x - a.x, b.y - a.y, b.z - a.z)
        let length = simd_length(delta)
        let cylinder = SCNCylinder(radius: radius, height: CGFloat(length))
        cylinder.radialSegmentCount = 8
        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
        node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(delta))
        return node
    }

    private static func material(color: UIColor, roughness: CGFloat, metalness: CGFloat = 0) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = roughness
        material.metalness.contents = metalness
        return material
    }

    private static func fabric(_ color: UIColor, knit: Bool) -> SCNMaterial {
        let material = self.material(color: color, roughness: knit ? 0.90 : 0.78)
        material.isDoubleSided = true
        // Microweave modulates normals in tangent space without painting fake brand marks.
        material.normal.contents = knit ? knitNormal : wovenNormal
        material.normal.wrapS = .repeat
        material.normal.wrapT = .repeat
        material.normal.contentsTransform = SCNMatrix4MakeScale(32, 32, 1)
        material.normal.intensity = 0.18
        return material
    }

    private static let knitNormal = weaveTexture(knit: true)
    private static let wovenNormal = weaveTexture(knit: false)
    private static func weaveTexture(knit: Bool) -> UIImage {
        let size = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true; return format
        }())
        return renderer.image { context in
            for y in 0..<size {
                for x in 0..<size {
                    let u = Double(x) * .pi / (knit ? 4 : 2)
                    let v = Double(y) * .pi / (knit ? 5 : 2)
                    UIColor(red: 0.5 + sin(u + sin(v)) * 0.15, green: 0.5 + cos(v) * 0.15, blue: 0.98, alpha: 1).setFill()
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }

    private static var imageCache: [String: UIImage] = [:]
    static func image(_ name: String) -> UIImage? {
        if let image = imageCache[name] { return image }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Avatar3D"), let image = UIImage(contentsOfFile: url.path) else { return nil }
        imageCache[name] = image
        return image
    }

    static func source(_ values: [Float], semantic: SCNGeometrySource.Semantic, components: Int) -> SCNGeometrySource {
        let data = values.withUnsafeBytes { Data($0) }
        return SCNGeometrySource(data: data, semantic: semantic, vectorCount: values.count / components,
                                 usesFloatComponents: true, componentsPerVector: components, bytesPerComponent: 4, dataOffset: 0, dataStride: components * 4)
    }
}

struct RallyHumanMesh: Decodable {
    struct Bone: Decodable { let name: String; let parent: Int; let position: [Float] }
    var positions: [Float]
    var normals: [Float]
    var uvs: [Float]
    var indices: [UInt32]
    var bones: [Bone]?
    var boneIndices: [Int]?
    var boneWeights: [Float]?
    private static var cache: [String: RallyHumanMesh] = [:]

    static func load(_ name: String) throws -> RallyHumanMesh {
        if let mesh = cache[name] { return mesh }
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Avatar3D") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let mesh = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        let count = mesh.positions.count / 3
        guard count > 0, mesh.positions.count % 3 == 0, mesh.normals.count == count * 3,
              mesh.uvs.count == count * 2, mesh.indices.count % 3 == 0,
              mesh.indices.allSatisfy({ $0 < count }), mesh.positions.allSatisfy({ $0.isFinite }),
              mesh.boneWeights == nil || mesh.boneWeights?.count == count * 4,
              mesh.boneIndices == nil || mesh.boneIndices?.count == count * 4 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        cache[name] = mesh
        return mesh
    }

    func geometry() -> SCNGeometry {
        let sources = [RallyAvatarRig.source(positions, semantic: .vertex, components: 3),
                       RallyAvatarRig.source(normals, semantic: .normal, components: 3),
                       RallyAvatarRig.source(uvs, semantic: .texcoord, components: 2)]
        let data = indices.withUnsafeBytes { Data($0) }
        let element = SCNGeometryElement(data: data, primitiveType: .triangles, primitiveCount: indices.count / 3, bytesPerIndex: 4)
        return SCNGeometry(sources: sources, elements: [element])
    }

    func selected(where predicate: (Float, Float, Float) -> Bool) -> Self {
        var result = self
        result.indices = []
        for triangle in stride(from: 0, to: indices.count, by: 3) {
            let corners = indices[triangle..<(triangle + 3)].map { Int($0) * 3 }
            let x = corners.reduce(Float(0)) { $0 + positions[$1] } / 3
            let y = corners.reduce(Float(0)) { $0 + positions[$1 + 1] } / 3
            let z = corners.reduce(Float(0)) { $0 + positions[$1 + 2] } / 3
            if predicate(x, y, z) { result.indices.append(contentsOf: indices[triangle..<(triangle + 3)]) }
        }
        return result
    }

    func hemmed(lower: Float, upper: Float) -> Self {
        var result = self
        for i in stride(from: 1, to: positions.count, by: 3) {
            if abs(positions[i] - lower) < 0.035 { result.positions[i] = lower }
            if abs(positions[i] - upper) < 0.035 { result.positions[i] = upper }
        }
        return result
    }

    func inflated(_ amount: Float) -> Self {
        var result = self
        for i in positions.indices { result.positions[i] += normals[i] * amount }
        return result
    }
}

private extension UIColor {
    func rallyMixed(with other: UIColor, ratio: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r + (r2-r)*ratio, green: g + (g2-g)*ratio, blue: b + (b2-b)*ratio, alpha: a)
    }
    convenience init?(hexString: String) {
        let text = hexString.replacingOccurrences(of: "#", with: "")
        guard let number = UInt32(text, radix: 16), text.count == 6 else { return nil }
        self.init(red: CGFloat((number >> 16) & 255) / 255, green: CGFloat((number >> 8) & 255) / 255, blue: CGFloat(number & 255) / 255, alpha: 1)
    }
}
