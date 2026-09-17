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
    private var bodyMesh: RallyHumanMesh?
    private var bodyNode: SCNNode?
    private var skinMaterial = SCNMaterial()
    private var hairMaterial = SCNMaterial()
    private var racketMaterial = SCNMaterial()
    private var racketGripMaterial = SCNMaterial()
    private var headAccessories: [SCNNode] = []
    private var showsRacket = true
    private var footwork = RallyAvatarFootwork()
    private(set) var assetError: String?
    var yaw: Float = -0.20
    private var lessonRing: SCNNode?

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
            bodyMesh = human
            // Head identity must not change garment cut lines or hand reach.
            stature = athleteModel == .female ? 1.73 / 1.78 : 1
            if let shoes = try? loadMesh("shoes"), let sole = stride(from: 1, to: shoes.positions.count, by: 3).map({ shoes.positions[$0] }).min() {
                groundOffset = -sole
            } else {
                groundOffset = 0.0177 * stature
            }
            createSkeleton(human)
            skinMaterial = Self.material(color: .white, roughness: 0.72)
            if let image = Self.image(skinTextureName) { skinMaterial.diffuse.contents = image }
            skinMaterial.specular.contents = UIColor(white: 0.16, alpha: 1)
            skinMaterial.diffuse.maxAnisotropy = 4
            // Clothing is mandatory on every surface, including the first rendered frame.
            // Socks and shoes are mandatory. Occlude the covered feet instead of
            // letting toes and ankle skin punch through the fitted footwear.
            let visibleBody = human.selected { _, y, _ in y >= 0.18 * stature }
            let body = skin(visibleBody, material: skinMaterial)
            body.name = "Human skin"
            root.addChildNode(body)
            bodyNode = body
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
        lessonRing?.isHidden = true
        guard !bones.isEmpty else { return }
        let breath = Float(sin(time * 1.65))
        let studio = presentation == .studio
        let progress = min(1, max(0, swingProgress ?? 0))
        let swing = swingProgress == nil ? Float(0) : sin(progress * .pi)
        let follow = swingProgress == nil ? Float(0) : sin(max(0, progress - 0.35) / 0.65 * .pi)
        let hand: Float = leftHanded ? -1 : 1
        let turn: Float = (backhand ? -1 : 1) * hand
        let twoHandedStroke = backhand && swingProgress != nil
        let bodyMotion = swingProgress != nil
            ? Self.groundstrokeBodyMotion(progress: progress, backhand: backhand, leftHanded: leftHanded)
            : BodyMotion()
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
        let weightShift = studio ? Float(sin(time * 0.94)) * 0.025 : lateral * 0.018 + pelvisTravel.x + bodyMotion.pelvisOffset.x * stature
        let readyDrop: Float = studio ? 0.046 + Float(cos(time * 1.88)) * 0.005 : 0.028 + gait.pelvisDrop
        if let hip = boneByName["root"], let neutral = bindPosition["root"] {
            hip.simdPosition = neutral + SIMD3<Float>(weightShift,
                -readyDrop - swing * 0.014 + breath * 0.002 + bodyMotion.pelvisOffset.y * stature,
                pelvisTravel.z + bodyMotion.pelvisOffset.z * stature)
            hip.eulerAngles.y = bodyMotion.pelvisYaw
        }
        rotate("spine03", x: (studio ? 0.075 : 0.035) + bodyMotion.forwardLean,
               y: (twoHandedStroke ? 0 : turn * swing * 0.30) + bodyMotion.lowerSpineYaw, z: -weightShift * 0.7)
        rotate("spine01", x: breath * 0.006,
               y: (twoHandedStroke ? 0 : turn * (swing * 0.34 - follow * 0.28)) + bodyMotion.upperSpineYaw)
        rotate("neck01", y: (twoHandedStroke ? 0 : -turn * swing * 0.14) - bodyMotion.pelvisYaw
               - bodyMotion.lowerSpineYaw * 0.65 - bodyMotion.upperSpineYaw * 0.70)
        rotate("head", x: -0.025, y: studio ? 0.06 : 0)

        // MakeHuman's rest pose is a relaxed A-pose. Close shoulders, then flex elbows.
        for (suffix, side) in [("L", Float(1)), ("R", Float(-1))] {
            let dominant = leftHanded ? side > 0 : side < 0
            let active = dominant || backhand
            let shoulderClose: Float = studio ? 0.16 : 0.28
            if twoHandedStroke {
                let engaged = Self.backhandGripEngagement(progress: progress)
                // The shoulder girdle follows the reach rather than forcing
                // the whole cross-body rotation into the upper-arm socket.
                rotate("clavicle.\(suffix)", y: -side * engaged * (dominant ? 0.17 : 0.08))
                rotate("shoulder01.\(suffix)", y: -side * engaged * 0.07)
            }
            rotate("upperarm01.\(suffix)", x: active ? -0.16 - swing * 0.76 : -0.08,
                   y: active ? turn * swing * 0.32 : 0, z: -side * (shoulderClose + breath * 0.008))
            rotate("lowerarm01.\(suffix)", x: dominant ? -0.30 - swing * 0.55 : (backhand ? -0.55 - swing * 0.55 : -0.14),
                   z: active ? side * swing * 0.16 : 0)
            rotate("wrist.\(suffix)", y: dominant ? -turn * follow * 0.42 : 0)
            if !studio {
                rotate("upperleg01.\(suffix)", x: -0.028 - swing * 0.08, z: -side * 0.012)
                rotate("lowerleg01.\(suffix)", x: 0.04 + swing * 0.13)
            }
            // Begin with relaxed fingers; the grip pass wraps either hand
            // that is actually holding the handle.
            for finger in 2...5 {
                for joint in 1...3 {
                    rotate("finger\(finger)-\(joint).\(suffix)", x: -0.16)
                }
            }
        }
        let dominantSuffix = leftHanded ? "L" : "R"
        let supportSuffix = leftHanded ? "R" : "L"
        if studio && swingProgress == nil {
            solveArm(dominantSuffix, target: SIMD3<Float>(-0.26 * hand + weightShift * 0.6, 1.07 + breath * 0.004, 0.30))
            solveArm(supportSuffix, target: SIMD3<Float>(0.18 * hand + weightShift * 0.6, 1.09 + breath * 0.004, 0.25))
        } else {
            let dominantTarget = Self.strokeWristTarget(progress: progress, backhand: backhand, leftHanded: leftHanded)
            solveArm(dominantSuffix, target: dominantTarget,
                     bodyClearance: backhand && swingProgress != nil ? Self.backhandGripEngagement(progress: progress) : 0)
            solveArm(supportSuffix, target: Self.freeHandTarget(progress: progress, leftHanded: leftHanded))
        }
        let wrist = boneByName[dominantSuffix == "L" ? "wrist.L" : "wrist.R"]
        if racket.parent !== wrist {
            racket.removeFromParentNode()
            wrist?.addChildNode(racket)
        }
        let gameplayGrip = -0.22 * hand + (backhand ? 0.34 * hand * swing : 0)
        let gripAngle: Float = studio ? 0.16 * hand : gameplayGrip
        poseRacketGrip(side: dominantSuffix, hand: hand, gripAngle: gripAngle,
                       strokeOrientation: twoHandedStroke ? Self.backhandRacketOrientation(progress: progress, leftHanded: leftHanded) : nil)
        if backhand, swingProgress != nil, showsRacket {
            poseSupportingGrip(side: supportSuffix, hand: -hand, progress: progress,
                               freeTarget: Self.freeHandTarget(progress: progress, leftHanded: leftHanded))
        }
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
                let pivot = twoHandedStroke ? bodyMotion.pelvisYaw * (side == dominantSuffix ? 0.65 : 0.9) : 0
                foot.simdOrientation = simd_inverse(parent.simdWorldOrientation) * root.simdWorldOrientation
                    * simd_quatf(angle: pivot, axis: SIMD3<Float>(0, 1, 0))
            }
        }
    }

    struct BodyMotion: Equatable {
        var pelvisOffset = SIMD3<Float>.zero
        var pelvisYaw: Float = 0
        var lowerSpineYaw: Float = 0
        var upperSpineYaw: Float = 0
        var forwardLean: Float = 0
    }

    /// The backhand owns a complete unit turn and unwind. Forehand loading
    /// remains additive to its established contact pose.
    static func groundstrokeBodyMotion(progress: Float, backhand: Bool, leftHanded: Bool) -> BodyMotion {
        let p = min(1, max(0, progress.isFinite ? progress : 0))
        if backhand {
            let hand: Float = leftHanded ? -1 : 1
            let rotation = sampleStroke(backhandBodyTurns, progress: p, times: backhandTimes)
            var offset = sampleStroke(backhandBodyOffsets, progress: p, times: backhandTimes)
            offset.x *= hand
            return BodyMotion(pelvisOffset: offset, pelvisYaw: rotation.x * hand,
                              lowerSpineYaw: rotation.y * hand, upperSpineYaw: rotation.z * hand,
                              forwardLean: 0.03 * backhandGripEngagement(progress: p))
        }
        let direction: Float = (backhand ? -1 : 1) * (leftHanded ? -1 : 1)
        let load = phaseEnvelope(p, start: 0, peak: 0.22, end: 0.5)
        let finish = phaseEnvelope(p, start: 0.5, peak: 0.76, end: 1)
        return BodyMotion(
            pelvisOffset: SIMD3(direction * (-0.025 * load + 0.024 * finish),
                                -0.020 * load + 0.004 * finish,
                                -0.012 * load + 0.022 * finish),
            pelvisYaw: direction * (-0.08 * load + 0.10 * finish),
            lowerSpineYaw: direction * (-0.40 * load + 0.16 * finish),
            upperSpineYaw: direction * (-0.38 * load + 0.18 * finish),
            forwardLean: 0.025 * load + 0.035 * finish
        )
    }

    private static func smoothUnit(_ value: Float) -> Float {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    private static func phaseEnvelope(_ progress: Float, start: Float, peak: Float, end: Float) -> Float {
        guard progress > start, progress < end else { return 0 }
        return progress <= peak
            ? smoothUnit((progress - start) / (peak - start))
            : 1 - smoothUnit((progress - peak) / (end - peak))
    }

    // Hermite tangents carry the wrists through contact at p=0.5 and settle
    // them back into ready. Gameplay projects each actual racket head.
    private static let strokeTimes: [Float] = [0, 0.22, 0.5, 0.78, 1]
    private static let readyWrist = SIMD3<Float>(-0.27, 1.12, 0.28)
    private static let forehandWrists: [SIMD3<Float>] = [
        readyWrist, SIMD3(-0.48, 1.18, 0.035), SIMD3(-0.46, 1.21 + 0.15, 0.31),
        SIMD3(0.18, 1.45, 0.38), readyWrist
    ]
    // A two-handed stroke is authored around a sideways racket, not an
    // upright prop. The load, drop, contact, extension and wrap are separate.
    private static let backhandTimes: [Float] = [0, 0.20, 0.34, 0.5, 0.63, 0.80, 1]
    private static let backhandWrists: [SIMD3<Float>] = [
        readyWrist, SIMD3(0.27, 1.05, -0.01), SIMD3(0.30, 0.98, 0.15),
        SIMD3(0.12, 1.08, 0.39), SIMD3(-0.10, 1.24, 0.43),
        SIMD3(-0.30, 1.43, 0.12), readyWrist
    ]
    private static let backhandBodyTurns: [SIMD3<Float>] = [
        .zero, SIMD3(0.60, 0.42, 0.28), SIMD3(0.52, 0.38, 0.23),
        SIMD3(0.20, 0.15, 0.12), SIMD3(-0.08, -0.18, -0.24),
        SIMD3(-0.28, -0.25, -0.29), .zero
    ]
    private static let backhandBodyOffsets: [SIMD3<Float>] = [
        .zero, SIMD3(0.01, -0.04, -0.04), SIMD3(0.025, -0.05, -0.01),
        SIMD3(-0.01, -0.027, 0.03), SIMD3(-0.025, -0.008, 0.065),
        SIMD3(-0.025, 0, 0.03), .zero
    ]
    // Components are yaw, pitch, roll in root space. The string bed faces
    // the incoming ball at contact; the head drops then wraps behind the shoulder.
    private static let backhandRacketAngles: [SIMD3<Float>] = [
        SIMD3(0, -0.16, -0.22), SIMD3(1.05, 0, -1.15), SIMD3(0.32, 0, -1.94),
        SIMD3(-0.08, 0, -1.39), SIMD3(-0.28, 0, -0.35),
        SIMD3(-0.75, 0, 0.68), SIMD3(0, -0.16, -0.22)
    ]

    static func backhandRacketOrientation(progress: Float, leftHanded: Bool) -> simd_quatf {
        let angles = sampleStroke(backhandRacketAngles, progress: progress, times: backhandTimes)
        let hand: Float = leftHanded ? -1 : 1
        return simd_quatf(angle: angles.x * hand, axis: SIMD3<Float>(0, 1, 0))
            * simd_quatf(angle: angles.z * hand, axis: SIMD3<Float>(0, 0, 1))
            * simd_quatf(angle: angles.y, axis: SIMD3<Float>(1, 0, 0))
    }
    private static let freeHandWrists: [SIMD3<Float>] = [
        SIMD3(0.23, 1.10, 0.23), SIMD3(0.30, 1.18, 0.22), SIMD3(0.30, 1.10, 0.18),
        SIMD3(0.34, 1.23, 0.08), SIMD3(0.23, 1.10, 0.23)
    ]

    static func strokeWristTarget(progress: Float, backhand: Bool, leftHanded: Bool) -> SIMD3<Float> {
        var target = sampleStroke(backhand ? backhandWrists : forehandWrists, progress: progress,
                                  times: backhand ? backhandTimes : strokeTimes)
        if leftHanded { target.x = -target.x }
        return target
    }

    private static func freeHandTarget(progress: Float, leftHanded: Bool) -> SIMD3<Float> {
        var target = sampleStroke(freeHandWrists, progress: progress)
        if leftHanded { target.x = -target.x }
        return target
    }

    private static func sampleStroke(_ points: [SIMD3<Float>], progress: Float, times: [Float] = strokeTimes) -> SIMD3<Float> {
        let p = min(1, max(0, progress.isFinite ? progress : 0))
        let segment = min(times.count - 2, times.dropFirst().prefix { p > $0 }.count)
        let duration = times[segment + 1] - times[segment]
        let t = (p - times[segment]) / duration
        func tangent(_ index: Int) -> SIMD3<Float> {
            guard index > 0, index < points.count - 1 else { return .zero }
            return (points[index + 1] - points[index - 1]) / (times[index + 1] - times[index - 1])
        }
        let t2 = t * t
        let t3 = t2 * t
        return points[segment] * (2 * t3 - 3 * t2 + 1)
            + tangent(segment) * duration * (t3 - 2 * t2 + t)
            + points[segment + 1] * (-2 * t3 + 3 * t2)
            + tangent(segment + 1) * duration * (t3 - t2)
    }

    /// Slow instructional motion uses the same skeleton and grounded IK as play.
    /// It is a general example, not an ideal-angle or technique-scoring template.
    func animateLesson(progress: Float, leftHanded: Bool, serve: Bool = false, viewingYaw: Float? = nil) {
        let p = min(1, max(0, progress.isFinite ? progress : 0))
        animate(time: 0, leftHanded: leftHanded)
        if let viewingYaw { root.eulerAngles.y = viewingYaw }
        let hand: Float = leftHanded ? -1 : 1
        let dominant = leftHanded ? "L" : "R"
        let support = leftHanded ? "R" : "L"
        let bend = (1 - cos(p * 2 * .pi)) * 0.5
        let serveActivity = Self.smoothUnit(p / 0.12) * (1 - Self.smoothUnit((p - 0.90) / 0.10))
        let serveLoad = Self.phaseEnvelope(p, start: 0, peak: 0.44, end: 0.75)
        let serveFinish = Self.phaseEnvelope(p, start: 0.75, peak: 0.89, end: 1)
        if let hip = boneByName["root"], let neutral = bindPosition["root"] {
            if serve {
                let lessonDrop = (0.025 + bend * 0.045) * stature
                let drop = 0.028 + (lessonDrop - 0.028) * serveActivity
                hip.simdPosition = neutral + SIMD3<Float>(hand * (serveLoad * -0.016 + serveFinish * 0.018) * stature,
                                                         -drop, serveFinish * 0.022 * stature)
                hip.eulerAngles.y = hand * (-0.08 * serveLoad + 0.12 * serveFinish)
            } else {
                hip.simdPosition = neutral + SIMD3<Float>(0, -(0.025 + bend * 0.085) * stature, 0)
            }
        }
        rotate("spine03", x: 0.035 + bend * 0.055 * (serve ? serveActivity : 1) + (serve ? serveFinish * 0.055 : 0),
               y: serve ? -hand * sin(p * .pi) * 0.25 * serveActivity + hand * (-0.16 * serveLoad + 0.22 * serveFinish) : 0)
        if serve {
            rotate("spine01", y: hand * (-0.12 * serveLoad + 0.18 * serveFinish))
            rotate("neck01", y: hand * (0.14 * serveLoad - 0.18 * serveFinish))
            func blend(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
                a + (b - a) * Self.smoothUnit(t)
            }
            let ready = Self.strokeWristTarget(progress: 0, backhand: false, leftHanded: leftHanded)
            let trophy = SIMD3<Float>(-0.30 * hand, 1.48, -0.06)
            let reach = SIMD3<Float>(-0.16 * hand, 1.80, 0.12)
            let finish = SIMD3<Float>(0.12 * hand, 1.12, 0.36)
            let wrist: SIMD3<Float>
            if p < 0.5 { wrist = blend(ready, trophy, p / 0.5) }
            else if p < 0.75 { wrist = blend(trophy, reach, (p - 0.5) / 0.25) }
            else if p < 0.89 { wrist = blend(reach, finish, (p - 0.75) / 0.14) }
            else { wrist = blend(finish, ready, (p - 0.89) / 0.11) }
            solveArm(dominant, target: wrist)
            let toss = sin(min(1, p / 0.7) * .pi)
            let supportToss = SIMD3<Float>(0.24 * hand, 1.12 + toss * 0.55, 0.28)
            let supportReady = Self.freeHandTarget(progress: 0, leftHanded: leftHanded)
            let supportBlend = Self.smoothUnit(p / 0.12) * (1 - Self.smoothUnit((p - 0.85) / 0.15))
            solveArm(support, target: supportReady + (supportToss - supportReady) * supportBlend)
            poseRacketGrip(side: dominant, hand: hand, gripAngle: (-0.22 + 0.12 * serveActivity) * hand)
        }
        for side in ["L", "R"] {
            guard let ankle = bindPosition["foot.\(side)"] else { continue }
            let spread: Float = (side == "L" ? 1 : -1) * (serve ? 0.026 + 0.014 * serveActivity : 0.04)
            solveChain(upperName: "upperleg01.\(side)", lowerName: "lowerleg01.\(side)",
                       endName: "foot.\(side)", target: ankle + SIMD3<Float>(spread, 0, 0),
                       pole: SIMD3<Float>(spread, 0, 1))
            if let foot = boneByName["foot.\(side)"], let parent = foot.parent {
                foot.simdOrientation = simd_inverse(parent.simdWorldOrientation) * root.simdWorldOrientation
            }
        }
        if !serve, let knee = boneByName["lowerleg01.\(dominant)"] {
            if lessonRing == nil {
                let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.055, pipeRadius: 0.007))
                let material = SCNMaterial(); material.diffuse.contents = UIColor.systemYellow
                material.emission.contents = UIColor.systemYellow; ring.geometry?.materials = [material]
                ring.eulerAngles.x = .pi / 2
                lessonRing = ring
            }
            if let ring = lessonRing {
                if ring.parent !== root { root.addChildNode(ring) }
                ring.position = knee.convertPosition(SCNVector3(0, 0, 0.065), to: root)
                ring.isHidden = false
            }
        }
    }

    func tossHandWorldPosition(leftHanded: Bool) -> SCNVector3 {
        boneByName[leftHanded ? "wrist.R" : "wrist.L"]?.convertPosition(SCNVector3Zero, to: nil) ?? SCNVector3Zero
    }

    private struct HandGripFrame {
        let up: SIMD3<Float>
        let basis: simd_float3x3
        let center: SIMD3<Float>
    }

    /// The bind skeleton uses common world axes, not hand-local axes. Recover
    /// the palm's width/length basis before orienting the wrist or curling fingers.
    private func handGripFrame(side: String, hand: Float) -> HandGripFrame? {
        guard let wristBind = bindPosition["wrist.\(side)"],
              let index = bindPosition["finger2-1.\(side)"],
              let middle = bindPosition["finger3-1.\(side)"],
              let pinky = bindPosition["finger5-1.\(side)"] else { return nil }
        let restUp = simd_normalize(index - pinky)
        let palmLength = middle - wristBind
        let restForward = simd_normalize(palmLength - restUp * simd_dot(palmLength, restUp))
        let restNormal = simd_normalize(simd_cross(restUp, restForward))
        // Mirroring anatomy reverses which side of this right-handed basis is
        // the palm. Flex toward the palm on either hand.
        let palmNormal = restNormal * hand
        let restBasis = simd_float3x3(columns: (restNormal, restUp, restForward))
        let center = (index + pinky) * 0.5 - wristBind + palmNormal * (0.016 * stature)
        return HandGripFrame(up: restUp, basis: restBasis, center: center)
    }

    private func poseRacketGrip(side: String, hand: Float, gripAngle: Float, strokeOrientation: simd_quatf? = nil) {
        guard let wrist = boneByName["wrist.\(side)"], let parent = wrist.parent,
              let frame = handGripFrame(side: side, hand: hand) else { return }
        let racketInRoot = strokeOrientation ?? (simd_quatf(angle: gripAngle, axis: SIMD3<Float>(0, 0, 1))
            * simd_quatf(angle: -0.16, axis: SIMD3<Float>(1, 0, 0)))
        let up = racketInRoot.act(SIMD3<Float>(0, 1, 0))
        // Keep the palm frame attached to the racket. Projecting a fixed
        // world direction becomes singular as the shaft sweeps through it.
        let forward = racketInRoot.act(simd_normalize(SIMD3<Float>(-hand * 0.7, 0, 0.7)))
        let normal = simd_normalize(simd_cross(up, forward))
        let targetBasis = simd_float3x3(columns: (normal, up, forward))
        let wristInRoot = simd_quatf(targetBasis * simd_transpose(frame.basis))
        wrist.simdOrientation = simd_inverse(parent.simdWorldOrientation) * root.simdWorldOrientation * wristInRoot

        curlGripFingers(side: side, hand: hand, frame: frame, blend: 1)
        let racketWorld = root.simdWorldOrientation * racketInRoot
        racket.simdOrientation = simd_inverse(wrist.simdWorldOrientation) * racketWorld
        racket.simdPosition = frame.center - racket.simdOrientation.act(SIMD3<Float>(0, 0.06, 0))
    }

    private static let upperGripCenter = SIMD3<Float>(0, 0.14, 0)

    static func backhandGripEngagement(progress: Float) -> Float {
        let p = min(1, max(0, progress.isFinite ? progress : 0))
        return smoothUnit(p / 0.18) * smoothUnit((1 - p) / 0.18)
    }

    /// Attach the opposite palm to the actual upper grip after the dominant
    /// hand places the racket. Both arms share the same authored racket frame.
    private func poseSupportingGrip(side: String, hand: Float, progress: Float, freeTarget: SIMD3<Float>) {
        let blend = Self.backhandGripEngagement(progress: progress)
        guard blend > 0, let wrist = boneByName["wrist.\(side)"], let parent = wrist.parent,
              let shoulder = boneByName["upperarm01.\(side)"],
              let frame = handGripFrame(side: side, hand: hand) else { return }
        let rootInverse = simd_inverse(root.simdWorldOrientation)
        let freeOrientation = rootInverse * wrist.simdWorldOrientation
        let racketInRoot = rootInverse * racket.simdWorldOrientation
        let up = racketInRoot.act(SIMD3<Float>(0, 1, 0))
        let grip = root.simdConvertPosition(racket.simdConvertPosition(Self.upperGripCenter, to: nil), from: nil)
        let shoulderPosition = root.simdConvertPosition(shoulder.simdWorldPosition, from: nil)
        // Turn the upper palm toward the grip along the supporting arm's
        // approach, instead of leaving the wrist twisted in its relaxed pose.
        let approach = grip - shoulderPosition
        let projected = approach - up * simd_dot(approach, up)
        let forward = simd_length_squared(projected) > 0.000001
            ? simd_normalize(projected) : racketInRoot.act(SIMD3<Float>(0, 0, 1))
        let normal = simd_normalize(simd_cross(up, forward))
        let targetBasis = simd_float3x3(columns: (normal, up, forward))
        let gripOrientation = simd_quatf(targetBasis * simd_transpose(frame.basis))
        let gripWrist = grip - gripOrientation.act(frame.center)
        let wristTarget = freeTarget * stature + (gripWrist - freeTarget * stature) * blend
        solveArm(side, target: wristTarget / stature, bodyClearance: blend)
        wrist.simdOrientation = simd_inverse(parent.simdWorldOrientation) * root.simdWorldOrientation
            * simd_slerp(freeOrientation, gripOrientation, blend)
        curlGripFingers(side: side, hand: hand, frame: frame, blend: blend)
    }

    /// Actual palm/handle coordinates for attachment regression checks.
    func backhandGripPositions(leftHanded: Bool) -> (palm: SIMD3<Float>, handle: SIMD3<Float>)? {
        let side = leftHanded ? "R" : "L"
        guard let wrist = boneByName["wrist.\(side)"],
              let frame = handGripFrame(side: side, hand: leftHanded ? 1 : -1) else { return nil }
        return (wrist.simdConvertPosition(frame.center, to: nil),
                racket.simdConvertPosition(Self.upperGripCenter, to: nil))
    }

    private func curlGripFingers(side: String, hand: Float, frame: HandGripFrame, blend: Float) {
        for finger in 2...5 {
            for (joint, angle) in [(1, Float(1.20)), (2, Float(1.70)), (3, Float(0.90))] {
                guard let bone = boneByName["finger\(finger)-\(joint).\(side)"] else { continue }
                let closed = simd_quatf(angle: (showsRacket ? angle : 0.14) * hand, axis: frame.up)
                bone.simdOrientation = simd_slerp(bone.simdOrientation, closed, blend)
            }
        }
        if showsRacket,
           let thumb = boneByName["finger1-1.\(side)"],
           let wristBind = bindPosition["wrist.\(side)"],
           let thumbBind = bindPosition["finger1-1.\(side)"],
           let thumbMiddle = bindPosition["finger1-2.\(side)"] {
            let towardGrip = frame.center + frame.up * (0.028 * stature) - (thumbBind - wristBind)
            let closed = simd_quatf(from: simd_normalize(thumbMiddle - thumbBind), to: simd_normalize(towardGrip))
            thumb.simdOrientation = simd_slerp(thumb.simdOrientation, closed, blend)
            for (joint, angle) in [(2, Float(0.25)), (3, Float(0.55))] {
                guard let bone = boneByName["finger1-\(joint).\(side)"] else { continue }
                bone.simdOrientation = simd_slerp(bone.simdOrientation, simd_quatf(angle: angle * hand, axis: frame.up), blend)
            }
        }
    }

    /// Two-bone IK in the character's coordinates. Split twist bones keep their authored weights.
    private func solveArm(_ side: String, target: SIMD3<Float>, bodyClearance: Float = 0) {
        let upperName = "upperarm01.\(side)"
        let lowerName = "lowerarm01.\(side)"
        let wristName = "wrist.\(side)"
        let relaxedPole = SIMD3<Float>(side == "L" ? 0.4 : -0.4, -1, 0.15)
        // A cross-body stroke needs the elbow in front of the rib cage;
        // the relaxed downward pole can otherwise route an arm through it.
        let chestPole = SIMD3<Float>(side == "L" ? 0.14 : -0.14, -0.80, 0.70)
        let frontPole = boneByName["spine01"].map {
            root.simdConvertVector($0.simdConvertVector(chestPole, to: nil), from: nil)
        } ?? chestPole
        solveChain(upperName: upperName, lowerName: lowerName, endName: wristName,
                   target: target * stature, pole: relaxedPole + (frontPole - relaxedPole) * bodyClearance)
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
        let studio = presentation == .studio
        scene.background.contents = UIColor.clear
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1.05
        camera.camera?.zNear = 0.05
        camera.camera?.zFar = 20
        camera.camera?.wantsHDR = true
        camera.camera?.wantsExposureAdaptation = false
        // Preserve highlights on white tennis clothing instead of washing away its folds.
        camera.camera?.exposureOffset = -0.18
        camera.position = SCNVector3(0, 0.93, 4)
        if studio {
            camera.position.y = 1.14
            camera.look(at: SCNVector3(0, 0.93, 0))
            camera.camera?.screenSpaceAmbientOcclusionIntensity = 0.32
            camera.camera?.screenSpaceAmbientOcclusionRadius = 0.055
            camera.camera?.screenSpaceAmbientOcclusionBias = 0.012
            createStudioGrounding()
        }
        scene.rootNode.addChildNode(camera)
        // A broad front fill keeps every skin tone and both eyes readable on a phone.
        // The quieter side key and ivory rim retain athletic shape without a plastic sheen.
        addLight(.ambient, position: SCNVector3Zero, intensity: 340, color: UIColor(white: 0.96, alpha: 1))
        addLight(.directional, position: SCNVector3(-2.5, 3.4, 4), intensity: 760, color: UIColor(red: 1, green: 0.96, blue: 0.90, alpha: 1))
        addLight(.directional, position: SCNVector3(2.4, 1.8, 4), intensity: 510, color: UIColor(red: 0.94, green: 0.97, blue: 1, alpha: 1))
        addLight(.directional, position: SCNVector3(0.7, 2.8, -3), intensity: 640, color: UIColor(red: 1, green: 0.98, blue: 0.92, alpha: 1))
    }

    func setStudioZoom(_ scale: Double) {
        guard presentation == .studio else { return }
        let zoom = min(1.15, max(0.48, scale))
        camera.camera?.orthographicScale = zoom
        camera.position.y = Float(1.14 + (1.05 - zoom) * 0.62)
    }

    private func createStudioGrounding() {
        // One cached feathered texture grounds all fitting views. The court supplies
        // gameplay shadows, so this transparent studio floor never enters SK3DNode.
        let plane = SCNPlane(width: 1.24, height: 0.80)
        let shadow = SCNMaterial()
        shadow.lightingModel = .constant
        shadow.diffuse.contents = Self.contactShadow
        shadow.isDoubleSided = true
        shadow.writesToDepthBuffer = false
        plane.materials = [shadow]
        let node = SCNNode(geometry: plane)
        node.name = "Studio contact shadow"
        node.eulerAngles.x = -.pi / 2
        node.position = SCNVector3(0, 0.001, 0.02)
        node.renderingOrder = -1
        scene.rootNode.addChildNode(node)
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
        let material = Self.material(color: .white, roughness: 0.32)
        material.diffuse.contents = Self.image("eyes-diffuse") ?? UIColor(white: 0.86, alpha: 1)
        material.clearCoat.contents = 0.18
        material.clearCoatRoughness.contents = 0.22
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
            if authoredShirt != nil, !tank,
               let hem = shirt.highestLowerBoundary(below: 1.06 * stature) {
                // Trim across triangles, then retain a little overlap at the waist.
                // Pin the lower band to the pelvis so alternating leg weights do
                // not pull adjacent hem vertices into a sawtooth during a stroke.
                shirt = shirt.clipped(atY: hem + 0.0005, keepAbove: true)
                if !polo {
                    for i in stride(from: 1, to: shirt.positions.count, by: 3) {
                        let ease = max(0, min(1, (1.11 * stature - shirt.positions[i]) / (0.12 * stature)))
                        shirt.positions[i] -= 0.014 * stature * ease
                    }
                }
                shirt = shirt.weightedTowardBone("root", below: hem + 0.025 * stature, transition: 0.075 * stature)
            }
            for i in stride(from: 0, to: shirt.positions.count, by: 3) {
                let ease = max(0, min(1, (1.16 * stature - shirt.positions[i + 1]) / (0.20 * stature)))
                shirt.positions[i] *= 1 + 0.055 * ease
                shirt.positions[i + 2] += shirt.normals[i + 2] * 0.022 * ease
                if !tank {
                    let shoulderEase = Self.smoothUnit((shirt.positions[i + 1] / stature - 1.24) / 0.15)
                    for axis in 0..<3 {
                        shirt.positions[i + axis] += shirt.normals[i + axis] * 0.005 * stature * shoulderEase
                    }
                }
            }
        }
        // The authored tee includes an exact covered-body mask. Apply it on
        // wardrobe changes so flexing the shoulder cannot expose skin through
        // the cloth. Tanks/polos retain their own exposed shoulder boundaries.
        if let human = bodyMesh {
            var visible = human.selected { _, y, _ in y >= 0.18 * stature }
            if !tank, !polo, specificTop == nil, authoredShirt != nil,
               let sources = human.sourceVertexIndices,
               let hem = shirt.highestLowerBoundary(below: 1.06 * stature) {
                visible = visible.hidingTeeCoveredSkin(sourceVertexIndices: sources, aboveHem: hem)
            }
            let body = skin(visible, material: skinMaterial)
            body.name = "Human skin"
            if let bodyNode {
                bodyNode.geometry = body.geometry
                bodyNode.skinner = body.skinner
            } else {
                root.addChildNode(body)
                bodyNode = body
            }
        }
        let topMaterial = Self.fabric(look.topUIColor, knit: true)
        if let normal = Self.image(polo ? "polo-normal" : "shirt-normal"), !tank, specificTop == nil {
            topMaterial.normal.contents = normal
            topMaterial.normal.contentsTransform = SCNMatrix4Identity
            topMaterial.normal.intensity = 0.42
            if polo, let roughness = Self.image("polo-roughness") {
                topMaterial.roughness.contents = roughness
            }
        }
        let top = skin(shirt, material: topMaterial)
        top.name = tank ? "Tank" : (polo ? "Polo" : "Performance tee")
        wardrobe.addChildNode(top)

        let bottomReference = look.shorts.flatMap { catalog.reference(for: $0.id, slot: .shorts) }
        let specificBottom = bottomReference?.meshName(for: athleteModel).flatMap { try? assetLoader($0) }
        let authoredShorts = try? loadMesh("shorts")
        var shorts = specificBottom ?? authoredShorts ?? shell
            .clipped(atY: 0.70 * stature, keepAbove: true)
            .clipped(atY: 0.98 * stature, keepAbove: false)
        if specificBottom == nil, authoredShorts == nil {
            for vertex in stride(from: 0, to: shorts.positions.count, by: 3) {
                // Legs need room over moving thighs; the waistband must stay
                // under the top, especially on the fitted women's polo.
                let waist = max(0, min(1, (shorts.positions[vertex + 1] - 0.84 * stature) / (0.10 * stature)))
                let clearance: Float = 0.018 - 0.012 * waist
                for axis in 0..<3 { shorts.positions[vertex + axis] += shorts.normals[vertex + axis] * clearance }
            }
        }
        let bottom = skin(shorts, material: Self.fabric(look.shortsUIColor, knit: false))
        bottom.name = "Court shorts"
        wardrobe.addChildNode(bottom)
        let shoes = (try? loadMesh("shoes")) ?? shell.selected { _, y, _ in y < 0.095 * stature }.inflated(0.011)
        let shoeMaterial = Self.material(color: look.shoesUIColor, roughness: 0.79)
        shoeMaterial.specular.contents = UIColor(white: 0.12, alpha: 1)
        if let texture = Self.image("shoes-diffuse") {
            shoeMaterial.diffuse.contents = texture
            shoeMaterial.multiply.contents = look.shoesUIColor
        }
        // The authored upper and the rubber sole share one skinned mesh. Give
        // their existing triangles separate finishes so the heel does not read
        // as one dark block. No extra shoe body is stacked over the original.
        let soleFloor = stride(from: 1, to: shoes.positions.count, by: 3).map { shoes.positions[$0] }.min() ?? -0.018
        let soleCut = soleFloor + 0.028 * stature
        let upperMesh = shoes.clipped(atY: soleCut, keepAbove: true)
        let soleMesh = shoes.clipped(atY: soleCut, keepAbove: false)
        let shoe = skin(upperMesh.indices.isEmpty ? shoes : upperMesh, material: shoeMaterial)
        shoe.name = "Court shoes"
        if !upperMesh.indices.isEmpty, !soleMesh.indices.isEmpty {
            let rubber = Self.material(color: UIColor(red: 0.86, green: 0.87, blue: 0.83, alpha: 1), roughness: 0.96)
            let sole = skin(soleMesh, material: rubber)
            sole.name = "Court shoe soles"
            wardrobe.addChildNode(sole)
        }
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
        racketMaterial = Self.material(color: .gray, roughness: 0.38, metalness: 0.16)
        racketMaterial.clearCoat.contents = 0.28
        racketMaterial.clearCoatRoughness.contents = 0.32
        racketGripMaterial = Self.material(color: .darkGray, roughness: 0.92)
        let graphite = Self.material(color: UIColor(white: 0.075, alpha: 1), roughness: 0.76)
        // An extended overgrip leaves room for the supporting backhand hand.
        // The lower hand and racket head keep their established anchors.
        let grip = SCNCylinder(radius: 0.013, height: 0.205)
        let handle = SCNNode(geometry: grip)
        handle.position.y = 0.0775
        handle.geometry?.materials = [racketGripMaterial]
        racket.addChildNode(handle)
        let buttCap = SCNNode(geometry: SCNCylinder(radius: 0.016, height: 0.012))
        buttCap.position.y = -0.026
        buttCap.geometry?.materials = [graphite]
        racket.addChildNode(buttCap)
        for i in 0..<16 {
            let torus = SCNTorus(ringRadius: 0.0132, pipeRadius: 0.0007)
            torus.ringSegmentCount = 24
            torus.pipeSegmentCount = 4
            let ring = SCNNode(geometry: torus)
            ring.position.y = Float(i) * 0.012 - 0.01
            ring.geometry?.materials = [graphite]
            racket.addChildNode(ring)
        }
        for side: Float in [-1, 1] {
            let throat = Self.rod(from: SCNVector3(side * 0.007, 0.18, 0), to: SCNVector3(side * 0.08, 0.32, 0), radius: 0.006)
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
        let grommet = SCNNode(geometry: SCNTorus(ringRadius: 0.118, pipeRadius: 0.0025))
        grommet.eulerAngles.x = .pi / 2
        grommet.scale.z = 1.30
        grommet.geometry?.materials = [graphite]
        racketHead.addChildNode(grommet)
        let strings = Self.material(color: UIColor(red: 0.90, green: 0.89, blue: 0.83, alpha: 1), roughness: 0.80)
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
        let material = self.material(color: color, roughness: knit ? 0.94 : 0.86)
        material.specular.contents = UIColor(white: 0.10, alpha: 1)
        material.isDoubleSided = true
        // Microweave modulates normals in tangent space without painting fake brand marks.
        material.normal.contents = knit ? knitNormal : wovenNormal
        material.normal.wrapS = .repeat
        material.normal.wrapT = .repeat
        material.normal.contentsTransform = SCNMatrix4MakeScale(32, 32, 1)
        material.normal.intensity = 0.13
        material.normal.mipFilter = .linear
        return material
    }

    private static let contactShadow: UIImage = {
        let size = CGSize(width: 128, height: 128)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colors = [UIColor.black.withAlphaComponent(0.34).cgColor,
                          UIColor.black.withAlphaComponent(0.12).cgColor,
                          UIColor.clear.cgColor] as CFArray
            let locations: [CGFloat] = [0, 0.45, 1]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else { return }
            context.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 64, y: 64), startRadius: 0,
                                                 endCenter: CGPoint(x: 64, y: 64), endRadius: 64, options: [])
        }
    }()

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
    var sourceVertexIndices: [Int]?
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
              mesh.boneIndices == nil || mesh.boneIndices?.count == count * 4,
              mesh.sourceVertexIndices == nil || mesh.sourceVertexIndices?.count == count else {
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

    private struct Edge: Hashable {
        let low: Int
        let high: Int
        init(_ a: Int, _ b: Int) { low = min(a, b); high = max(a, b) }
    }

    /// UV seams duplicate vertices. Weld by position when finding a garment's
    /// actual open lower edge, otherwise texture seams look like cut fabric.
    func highestLowerBoundary(below limit: Float) -> Float? {
        var canonical: [SIMD3<Float>: Int] = [:]
        var vertexMap: [Int] = []
        for index in stride(from: 0, to: positions.count, by: 3) {
            let point = SIMD3<Float>(positions[index], positions[index + 1], positions[index + 2])
            if canonical[point] == nil { canonical[point] = index / 3 }
            vertexMap.append(canonical[point]!)
        }
        var edgeCounts: [Edge: Int] = [:]
        for triangle in stride(from: 0, to: indices.count, by: 3) {
            let a = vertexMap[Int(indices[triangle])]
            let b = vertexMap[Int(indices[triangle + 1])]
            let c = vertexMap[Int(indices[triangle + 2])]
            for edge in [Edge(a, b), Edge(b, c), Edge(c, a)] { edgeCounts[edge, default: 0] += 1 }
        }
        var result: Float?
        for (edge, count) in edgeCounts where count == 1 {
            let a = positions[edge.low * 3 + 1]
            let b = positions[edge.high * 3 + 1]
            if a < limit, b < limit { result = max(result ?? a, max(a, b)) }
        }
        return result
    }

    /// Clip intersecting triangles at a real seam plane. Interpolating UVs,
    /// normals and normalized skin weights retains the authored fit in motion.
    func clipped(atY height: Float, keepAbove: Bool) -> Self {
        var result = self
        result.positions = []; result.normals = []; result.uvs = []; result.indices = []
        let skinned = boneWeights != nil && boneIndices != nil
        result.boneWeights = skinned ? [] : nil
        result.boneIndices = skinned ? [] : nil
        result.sourceVertexIndices = sourceVertexIndices == nil ? nil : []
        var originalVertices: [Int: UInt32] = [:]
        var seamVertices: [Edge: UInt32] = [:]

        func appendVertex(_ a: Int, _ b: Int, _ t: Float) -> UInt32 {
            let index = UInt32(result.positions.count / 3)
            if let sources = sourceVertexIndices {
                result.sourceVertexIndices?.append(a == b || t <= 0 ? sources[a] : t >= 1 ? sources[b] : -1)
            }
            for axis in 0..<3 {
                let first = positions[a * 3 + axis]
                result.positions.append(first + (positions[b * 3 + axis] - first) * t)
            }
            let firstNormal = SIMD3<Float>(normals[a * 3], normals[a * 3 + 1], normals[a * 3 + 2])
            let lastNormal = SIMD3<Float>(normals[b * 3], normals[b * 3 + 1], normals[b * 3 + 2])
            let normal = simd_normalize(firstNormal + (lastNormal - firstNormal) * t)
            result.normals.append(contentsOf: [normal.x, normal.y, normal.z])
            for axis in 0..<2 {
                let first = uvs[a * 2 + axis]
                result.uvs.append(first + (uvs[b * 2 + axis] - first) * t)
            }
            if let weights = boneWeights, let joints = boneIndices {
                var blended: [Int: Float] = [:]
                for influence in 0..<4 {
                    blended[joints[a * 4 + influence], default: 0] += weights[a * 4 + influence] * (1 - t)
                    blended[joints[b * 4 + influence], default: 0] += weights[b * 4 + influence] * t
                }
                let strongest = blended.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(4)
                let total = max(0.000001, strongest.reduce(Float(0)) { $0 + $1.value })
                for joint in strongest {
                    result.boneIndices?.append(joint.key)
                    result.boneWeights?.append(joint.value / total)
                }
                for _ in strongest.count..<4 {
                    result.boneIndices?.append(0); result.boneWeights?.append(0)
                }
            }
            return index
        }
        func original(_ vertex: Int) -> UInt32 {
            if let cached = originalVertices[vertex] { return cached }
            let index = appendVertex(vertex, vertex, 0)
            originalVertices[vertex] = index
            return index
        }
        func intersection(_ a: Int, _ b: Int) -> UInt32 {
            let edge = Edge(a, b)
            if let cached = seamVertices[edge] { return cached }
            let t = (height - positions[a * 3 + 1]) / (positions[b * 3 + 1] - positions[a * 3 + 1])
            let index = appendVertex(a, b, t)
            result.positions[Int(index) * 3 + 1] = height
            seamVertices[edge] = index
            return index
        }
        func inside(_ vertex: Int) -> Bool {
            keepAbove ? positions[vertex * 3 + 1] >= height : positions[vertex * 3 + 1] <= height
        }
        for triangle in stride(from: 0, to: indices.count, by: 3) {
            let vertices = (0..<3).map { Int(indices[triangle + $0]) }
            var polygon: [UInt32] = []
            var previous = vertices[2]
            for current in vertices {
                if inside(current) != inside(previous) { polygon.append(intersection(previous, current)) }
                if inside(current) { polygon.append(original(current)) }
                previous = current
            }
            if polygon.count >= 3 {
                for index in 1..<(polygon.count - 1) {
                    result.indices.append(contentsOf: [polygon[0], polygon[index], polygon[index + 1]])
                }
            }
        }
        return result
    }

    func weightedTowardBone(_ name: String, below height: Float, transition: Float) -> Self {
        guard let joint = bones?.firstIndex(where: { $0.name == name }),
              let weights = boneWeights, let joints = boneIndices else { return self }
        var result = self
        for vertex in 0..<(positions.count / 3) {
            let strength = max(0, min(1, (height + transition - positions[vertex * 3 + 1]) / transition))
            guard strength > 0 else { continue }
            var blended: [Int: Float] = [joint: strength]
            for influence in 0..<4 {
                blended[joints[vertex * 4 + influence], default: 0] += weights[vertex * 4 + influence] * (1 - strength)
            }
            let strongest = Array(blended.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(4))
            let total = max(0.000001, strongest.reduce(Float(0)) { $0 + $1.value })
            for influence in 0..<4 {
                result.boneIndices?[vertex * 4 + influence] = influence < strongest.count ? strongest[influence].key : 0
                result.boneWeights?[vertex * 4 + influence] = influence < strongest.count ? strongest[influence].value / total : 0
            }
        }
        return result
    }

    func hemmed(lower: Float, upper: Float) -> Self {
        var result = self
        for i in stride(from: 1, to: positions.count, by: 3) {
            if positions[i] < lower + 0.035 { result.positions[i] = lower }
            if positions[i] > upper - 0.035 { result.positions[i] = upper }
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
