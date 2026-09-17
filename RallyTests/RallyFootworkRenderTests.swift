import XCTest
import SceneKit
import UIKit
import Metal
import ImageIO
import UniformTypeIdentifiers
@testable import Rally

/// Diagnostic renders of the production rig moving across a stationary floor.
/// The external carrier reproduces SpriteKit's translation; an in-place pose
/// alone cannot demonstrate that a shoe remains planted in court coordinates.
@MainActor
final class RallyFootworkRenderTests: XCTestCase {
    /// Production meshes and poses, framed for human review of the shorts hem,
    /// thigh silhouette and knee alignment. No appearance-quality thresholds.
    func testRenderThighHemAndKneeAlignmentForVisualReview() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let poses: [(name: String, presentation: RallyAvatarRig.Presentation)] = [
            ("studio-idle", .studio), ("gameplay-ready", .gameplay)
        ]
        let views: [(name: String, position: SCNVector3)] = [
            ("front", SCNVector3(0, 0.57, 3)),
            ("threequarter", SCNVector3(2.12, 0.57, 2.12)),
            ("back", SCNVector3(0, 0.57, -3))
        ]
        let poseTime = 0.6
        for preset in [RallyAthletePreset.maleAsian, .femaleAsian] {
            for pose in poses {
                try autoreleasepool {
                    let look = RallyAvatarAppearance(
                        athletePreset: preset,
                        top: RallyGearReference(id: "uniqlo.dry.polo.white", colorwayHex: "#F4F4F2"),
                        shorts: RallyGearReference(id: "default-shorts", colorwayHex: "#15171B")
                    )
                    let rig = RallyAvatarRig(appearance: look, presentation: pose.presentation)
                    XCTAssertNil(rig.assetError)
                    XCTAssertFalse(rig.root.isHidden)
                    for name in ["Human skin", "Court shorts", "Court shoes"] {
                        let node = try XCTUnwrap(rig.root.childNode(withName: name, recursively: true))
                        let geometry = try XCTUnwrap(node.geometry)
                        XCTAssertFalse(geometry.sources(for: .vertex).isEmpty)
                        XCTAssertFalse(geometry.elements.isEmpty)
                    }
                    rig.scene.background.contents = UIColor(red: 0.045, green: 0.075, blue: 0.063, alpha: 1)
                    rig.camera.camera?.orthographicScale = 0.64
                    if pose.presentation == .gameplay { rig.camera.camera?.wantsHDR = false }
                    rig.animate(time: poseTime, courtPosition: pose.presentation == .gameplay ? 0 : nil)
                    SCNTransaction.flush()

                    let name = "thigh-hem-\(preset.rawValue)-\(pose.name)"
                    let body = try XCTUnwrap(rig.root.childNode(withName: "Human skin", recursively: true))
                    let bones = try XCTUnwrap(body.skinner).bones
                    let required = ["root", "upperleg01.L", "upperleg01.R", "lowerleg01.L",
                                    "lowerleg01.R", "foot.L", "foot.R"]
                    for joint in required {
                        XCTAssertTrue(bones.contains { $0.name == joint }, "\(name) missing \(joint)")
                    }
                    var joints: [[String: Any]] = []
                    for bone in bones {
                        guard let joint = bone.name,
                              joint == "root" || joint.hasPrefix("pelvis") || joint.hasPrefix("upperleg")
                                || joint.hasPrefix("lowerleg") || joint.hasPrefix("foot") || joint.hasPrefix("toe") else { continue }
                        let world = bone.worldPosition
                        let character = rig.root.convertPosition(SCNVector3Zero, from: bone)
                        XCTAssertTrue([world.x, world.y, world.z, character.x, character.y, character.z].allSatisfy(\.isFinite))
                        joints.append([
                            "name": joint,
                            "parent": bone.parent?.name ?? "",
                            "world": [Double(world.x), Double(world.y), Double(world.z)],
                            "character": [Double(character.x), Double(character.y), Double(character.z)]
                        ])
                    }
                    let sample: [String: Any] = [
                        "preset": preset.rawValue, "pose": pose.name, "timeSeconds": poseTime,
                        "units": "meters", "characterAxes": "Y up, +Z forward, anatomical right at negative X",
                        "rootYawRadians": Double(rig.root.eulerAngles.y), "joints": joints
                    ]
                    let data = try JSONSerialization.data(withJSONObject: sample, options: [.prettyPrinted, .sortedKeys])
                    let coordinates = XCTAttachment(data: data, uniformTypeIdentifier: UTType.json.identifier)
                    coordinates.name = "\(name)-leg-joints"
                    coordinates.lifetime = .keepAlways
                    add(coordinates)

                    let renderer = SCNRenderer(device: device, options: nil)
                    renderer.scene = rig.scene
                    renderer.pointOfView = rig.camera
                    renderer.autoenablesDefaultLighting = false
                    XCTAssertTrue(renderer.prepare(rig.scene, shouldAbortBlock: nil))
                    for view in views {
                        // Orbit the camera, preserving the complete production
                        // pose and foot placement in both presentation modes.
                        rig.camera.position = rig.root.convertPosition(view.position, to: nil)
                        rig.camera.look(at: rig.root.convertPosition(SCNVector3(0, 0.57, 0), to: nil))
                        SCNTransaction.flush()
                        let image = renderer.snapshot(atTime: poseTime, with: CGSize(width: 768, height: 1024),
                                                      antialiasingMode: .multisampling4X)
                        _ = try XCTUnwrap(image.cgImage, "\(name) \(view.name) must render")
                        let attachment = XCTAttachment(image: image)
                        attachment.name = "\(name)-\(view.name)"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    }
                }
            }
        }
    }

    func testRenderTravelAndStopsForNearAndFarAthletes() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        for preset in [RallyAthletePreset.maleEuropean, .femaleEuropean] {
            for presentation in [RallyAvatarRig.Presentation.gameplay, .opponent] {
                try autoreleasepool {
                    try renderTravel(preset: preset, presentation: presentation, device: device)
                }
            }
        }
    }

    /// Close-up evidence for human review of the shipped model and equipment.
    /// This checks renderability; appearance quality is judged from attachments.
    func testRenderEquipmentAndCharacterDetailForVisualReview() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let frames: [(name: String, scale: Double, camera: SCNVector3, target: SCNVector3)] = [
            ("upper", 0.73, SCNVector3(-0.04, 1.38, 4), SCNVector3(-0.04, 1.28, 0)),
            ("shoes", 0.47, SCNVector3(0.55, 0.48, 3), SCNVector3(0, 0.23, 0.03)),
            ("full", 1.04, SCNVector3(0, 1.14, 4), SCNVector3(0, 0.91, 0))
        ]
        for preset in [RallyAthletePreset.maleEuropean, .femaleEuropean] {
            try autoreleasepool {
                let look = RallyAvatarAppearance(
                    athletePreset: preset,
                    top: RallyGearReference(id: "uniqlo.dry.polo.white", colorwayHex: "#F4F4F2"),
                    shorts: RallyGearReference(id: "default-shorts", colorwayHex: "#15171B")
                )
                let rig = RallyAvatarRig(appearance: look, presentation: .studio)
                XCTAssertNil(rig.assetError)
                XCTAssertFalse(rig.root.isHidden)
                for name in ["Human skin", "Polo", "Court shorts", "Court shoes"] {
                    let node = try XCTUnwrap(rig.root.childNode(withName: name, recursively: true))
                    let geometry = try XCTUnwrap(node.geometry)
                    XCTAssertFalse(geometry.sources(for: .vertex).isEmpty, "\(name) needs live mesh vertices")
                    XCTAssertFalse(geometry.elements.isEmpty, "\(name) needs renderable mesh elements")
                }
                let racket = try XCTUnwrap(rig.root.childNode(withName: "Tennis racket", recursively: true))
                XCTAssertFalse(racket.isHidden)
                XCTAssertFalse(racket.childNodes.isEmpty)
                rig.scene.background.contents = UIColor(red: 0.045, green: 0.075, blue: 0.063, alpha: 1)
                rig.yaw = -0.16
                rig.animate(time: 0.6)
                SCNTransaction.flush()

                let renderer = SCNRenderer(device: device, options: nil)
                renderer.scene = rig.scene
                renderer.pointOfView = rig.camera
                renderer.autoenablesDefaultLighting = false
                XCTAssertTrue(renderer.prepare(rig.scene, shouldAbortBlock: nil))
                let model = preset.athleteModel == .male ? "male" : "female"
                for frame in frames {
                    rig.camera.camera?.orthographicScale = frame.scale
                    rig.camera.position = frame.camera
                    rig.camera.look(at: frame.target)
                    SCNTransaction.flush()
                    let image = renderer.snapshot(atTime: 0.6, with: CGSize(width: 768, height: 1024),
                                                  antialiasingMode: .multisampling4X)
                    _ = try XCTUnwrap(image.cgImage, "\(model) \(frame.name) must produce a render")
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "equipment-\(model)-\(frame.name)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }

                // Match the production near player's back-facing rig and SDR
                // camera. Contact is 0.5; the live follow-through advances to 1.
                let gameplayRig = RallyAvatarRig(appearance: look, presentation: .gameplay)
                XCTAssertNil(gameplayRig.assetError)
                XCTAssertFalse(gameplayRig.root.isHidden)
                gameplayRig.scene.background.contents = UIColor(red: 0.045, green: 0.075, blue: 0.063, alpha: 1)
                gameplayRig.camera.camera?.wantsHDR = false
                let gameplayRenderer = SCNRenderer(device: device, options: nil)
                gameplayRenderer.scene = gameplayRig.scene
                gameplayRenderer.pointOfView = gameplayRig.camera
                gameplayRenderer.autoenablesDefaultLighting = false
                XCTAssertTrue(gameplayRenderer.prepare(gameplayRig.scene, shouldAbortBlock: nil))
                let swingFrames: [(name: String, progress: Float)] = [("contact", 0.5), ("followthrough", 0.88)]
                for frame in swingFrames {
                    let time = Double(frame.progress)
                    gameplayRig.animate(time: time, swingProgress: frame.progress, courtPosition: 0)
                    SCNTransaction.flush()
                    let image = gameplayRenderer.snapshot(atTime: time, with: CGSize(width: 768, height: 1024),
                                                          antialiasingMode: .multisampling4X)
                    _ = try XCTUnwrap(image.cgImage, "\(model) \(frame.name) must produce a render")
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "equipment-\(model)-gameplay-\(frame.name)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }

    private func renderTravel(preset: RallyAthletePreset,
                              presentation: RallyAvatarRig.Presentation,
                              device: MTLDevice) throws {
        let look = RallyAvatarAppearance(
            athletePreset: preset,
            top: RallyGearReference(id: "uniqlo.dry.polo.white", colorwayHex: "#F4F4F2"),
            shorts: RallyGearReference(id: "proof.shorts", colorwayHex: "#15171B")
        )
        let rig = RallyAvatarRig(appearance: look, presentation: presentation)
        XCTAssertNil(rig.assetError)
        XCTAssertFalse(rig.root.isHidden)
        let body = try XCTUnwrap(rig.root.childNode(withName: "Human skin", recursively: true))
        let polo = try XCTUnwrap(rig.root.childNode(withName: "Polo", recursively: true))
        let shorts = try XCTUnwrap(rig.root.childNode(withName: "Court shorts", recursively: true))
        let originalBones = try XCTUnwrap(body.skinner).bones
        let originalVertices = [body, polo, shorts].map { $0.geometry?.sources(for: .vertex).first?.data }
        let feet = try ["foot.L", "foot.R"].map {
            try XCTUnwrap(rig.root.childNode(withName: $0, recursively: true))
        }

        let carrier = SCNNode()
        carrier.name = "External court translation"
        rig.root.removeFromParentNode()
        carrier.addChildNode(rig.root)
        rig.scene.rootNode.addChildNode(carrier)
        addStationaryFloor(to: rig.scene)
        rig.scene.background.contents = UIColor(red: 0.045, green: 0.065, blue: 0.07, alpha: 1)
        // Widen and lower the diagnostic view to expose shoe clearance and
        // the whole chase. Geometry, skinning, lights and materials are live.
        rig.camera.camera?.orthographicScale = 1.16
        rig.camera.camera?.wantsHDR = false // Matches the embedded court renderer.
        rig.camera.position = SCNVector3(0, 1.35, 4)
        rig.camera.look(at: SCNVector3(0, 0.82, 0))
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = rig.scene
        renderer.pointOfView = rig.camera
        renderer.autoenablesDefaultLighting = false

        rig.animate(time: 0, courtPosition: 0)
        let restHeights = feet.map { $0.worldPosition.y }
        var previousFeet = feet.map(\.simdWorldPosition)
        var previousPosition: Float = 0
        var largestLift: Float = 0
        var largestPlantedSlip: Float = 0
        var groundedComparisons = 0
        var settledFeet: [SIMD3<Float>]?
        var largestSettledDrift: Float = 0
        var csv = "time,court_x,left_x,left_y,left_z,right_x,right_y,right_z\n"

        let model = preset.athleteModel == .male ? "male" : "female"
        let view = presentation == .gameplay ? "near" : "far"
        let name = "footwork-\(view)-\(model)-model-1"
        let gif = NSMutableData()
        let physicsFrames = 279 // 4.65 seconds at 60 Hz, including a final stop.
        let captureStride = 4 // 15 fps evidence; gait still advances at 60 Hz.
        let frameCount = physicsFrames / captureStride + 1
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            gif as CFMutableData, UTType.gif.identifier as CFString, frameCount, nil
        ))
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        let frameProperties = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 15.0]
        ] as CFDictionary

        for frame in 0...physicsFrames {
            let time = Double(frame) / 60
            let position = courtPosition(at: time)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0
            carrier.position.x = position
            rig.animate(time: time, lateral: position / 0.65, courtPosition: position)
            SCNTransaction.commit()
            SCNTransaction.flush()
            let currentFeet = feet.map(\.simdWorldPosition)
            for index in feet.indices {
                let height = currentFeet[index].y - restHeights[index]
                largestLift = max(largestLift, height)
                let wasGrounded = abs(previousFeet[index].y - restHeights[index]) < 0.001
                let isGrounded = abs(height) < 0.001
                if frame > 0, abs(position - previousPosition) > 0.001, wasGrounded, isGrounded {
                    largestPlantedSlip = max(largestPlantedSlip,
                                             abs(currentFeet[index].x - previousFeet[index].x))
                    groundedComparisons += 1
                }
                if let settledFeet {
                    largestSettledDrift = max(largestSettledDrift,
                                              simd_distance(currentFeet[index], settledFeet[index]))
                }
                XCTAssertTrue(currentFeet[index].x.isFinite && currentFeet[index].y.isFinite
                              && currentFeet[index].z.isFinite, "\(name) invalid foot at \(time)")
            }
            // Allow the current step to land after the carrier stops at 4 s.
            if frame == 264 { settledFeet = currentFeet }
            previousFeet = currentFeet
            previousPosition = position
            csv += "\(time),\(position),\(currentFeet[0].x),\(currentFeet[0].y),\(currentFeet[0].z),"
                + "\(currentFeet[1].x),\(currentFeet[1].y),\(currentFeet[1].z)\n"

            if frame.isMultiple(of: captureStride) {
                try autoreleasepool {
                    let raw = renderer.snapshot(atTime: time, with: CGSize(width: 640, height: 480),
                                                antialiasingMode: .multisampling4X)
                    let caption = String(format: "%@ / %@   t %.2f s   court x %+.2f m", model, view, time, position)
                    let capture = annotate(raw, caption: caption)
                    CGImageDestinationAddImage(destination, try XCTUnwrap(capture.cgImage), frameProperties)
                    if [0, 44, 128, 212, 276].contains(frame) {
                        let still = XCTAttachment(image: capture)
                        still.name = "\(name)-frame-\(String(format: "%03d", frame))"
                        still.lifetime = .keepAlways
                        add(still)
                    }
                }
            }
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let animation = XCTAttachment(data: gif as Data, uniformTypeIdentifier: UTType.gif.identifier)
        animation.name = name
        animation.lifetime = .keepAlways
        add(animation)
        let coordinates = XCTAttachment(data: Data(csv.utf8), uniformTypeIdentifier: UTType.commaSeparatedText.identifier)
        coordinates.name = "\(name)-world-feet"
        coordinates.lifetime = .keepAlways
        add(coordinates)

        XCTAssertGreaterThan(largestLift, 0.02, "\(name): translation must visibly lift a foot")
        XCTAssertGreaterThan(groundedComparisons, 60, "\(name): the chase must retain grounded support")
        XCTAssertLessThan(largestPlantedSlip, 0.008, "\(name): grounded feet slide across the court")
        XCTAssertLessThan(largestSettledDrift, 0.006, "\(name): feet keep drifting after the player stops")
        for index in feet.indices {
            XCTAssertEqual(feet[index].worldPosition.y, restHeights[index], accuracy: 0.006,
                           "\(name): the last step must land after stopping")
        }
        XCTAssertTrue(rig.root.childNode(withName: "Human skin", recursively: true) === body)
        XCTAssertTrue(rig.root.childNode(withName: "Polo", recursively: true) === polo)
        XCTAssertTrue(rig.root.childNode(withName: "Court shorts", recursively: true) === shorts)
        XCTAssertEqual([body, polo, shorts].map { $0.geometry?.sources(for: .vertex).first?.data }, originalVertices)
        XCTAssertTrue(zip(try XCTUnwrap(body.skinner).bones, originalBones).allSatisfy { $0 === $1 })
    }

    private func courtPosition(at time: Double) -> Float {
        func move(from start: Float, to end: Float, beginning: Double, duration: Double) -> Float {
            let fraction = Float(min(1, max(0, (time - beginning) / duration)))
            let ease = fraction * fraction * (3 - 2 * fraction)
            return start + (end - start) * ease
        }
        switch time {
        case ..<0.25: return 0
        case ..<1.10: return move(from: 0, to: 0.65, beginning: 0.25, duration: 0.85)
        case ..<1.35: return 0.65
        case ..<2.95: return move(from: 0.65, to: -0.65, beginning: 1.35, duration: 1.60)
        case ..<3.15: return -0.65
        case ..<4.00: return move(from: -0.65, to: 0, beginning: 3.15, duration: 0.85)
        default: return 0
        }
    }

    private func addStationaryFloor(to scene: SCNScene) {
        let floor = SCNNode(geometry: SCNBox(width: 3.8, height: 0.012, length: 2.8, chamferRadius: 0))
        floor.position = SCNVector3(0, -0.025, 0)
        floor.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.12, green: 0.20, blue: 0.19, alpha: 1)
        floor.geometry?.firstMaterial?.roughness.contents = 1
        scene.rootNode.addChildNode(floor)
        for index in -6...6 {
            let stripe = SCNNode(geometry: SCNBox(width: 0.005, height: 0.003, length: 2.6, chamferRadius: 0))
            stripe.position = SCNVector3(Float(index) * 0.25, -0.017, 0)
            stripe.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.52, alpha: 1)
            scene.rootNode.addChildNode(stripe)
        }
        for index in -4...4 {
            let stripe = SCNNode(geometry: SCNBox(width: 3.6, height: 0.003, length: 0.005, chamferRadius: 0))
            stripe.position = SCNVector3(0, -0.017, Float(index) * 0.25)
            stripe.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.52, alpha: 1)
            scene.rootNode.addChildNode(stripe)
        }
    }

    private func annotate(_ image: UIImage, caption: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            image.draw(at: .zero)
            context.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.72).cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: image.size.width, height: 28))
            (caption as NSString).draw(at: CGPoint(x: 10, y: 7), withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.white
            ])
        }
    }
}
