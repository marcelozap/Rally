import XCTest
import SceneKit
import UIKit
import Metal
@testable import Rally

@MainActor
final class AvatarRigTests: XCTestCase {
    private let presetAssets: [(preset: RallyAthletePreset, prefix: String, hair: String)] = [
        (.maleEuropean, "", "hair-short"),
        (.maleAsian, "male-asian-", "hair-short"),
        (.maleBlack, "male-black-", "hair-afro"),
        (.femaleEuropean, "female-", "hair-ponytail"),
        (.femaleAsian, "female-asian-", "hair-ponytail"),
        (.femaleBlack, "female-black-", "hair-ponytail")
    ]

    func testBundledMeshesShareAValidSkinningContract() throws {
        for prefix in ["", "female-"] {
            try assertValidSkinningContract(prefix: prefix, assets: [
                "athlete", "helper-tights", "eyes", "hair-short", "hair-medium", "hair-long", "hair-ponytail",
                "shirt", "polo", "shoes", "socks"
            ])
        }
        for spec in presetAssets where spec.prefix != "" && spec.prefix != "female-" {
            try assertValidSkinningContract(prefix: spec.prefix, assets: ["athlete", "eyes", spec.hair])
        }
    }

    private func assertValidSkinningContract(prefix: String, assets: [String]) throws {
        let human = try RallyHumanMesh.load(prefix + "athlete")
        let skeleton = try XCTUnwrap(human.bones)
        XCTAssertEqual(skeleton.count, 163)
        XCTAssertEqual(Set(skeleton.map(\.name)).count, skeleton.count)
        for (index, bone) in skeleton.enumerated() {
            XCTAssertEqual(bone.position.count, 3, bone.name)
            XCTAssertTrue(bone.position.allSatisfy(\.isFinite), bone.name)
            XCTAssertTrue(bone.parent == -1 || (0..<index).contains(bone.parent), bone.name)
        }

        for asset in assets {
            let name = prefix + asset
            let mesh = try RallyHumanMesh.load(name)
            let vertexCount = mesh.positions.count / 3
            XCTAssertGreaterThan(vertexCount, 0, name)
            XCTAssertFalse(mesh.indices.isEmpty, name)
            XCTAssertEqual(mesh.positions.count % 3, 0, name)
            XCTAssertEqual(mesh.normals.count, vertexCount * 3, name)
            XCTAssertEqual(mesh.uvs.count, vertexCount * 2, name)
            XCTAssertTrue(mesh.positions.allSatisfy(\.isFinite), name)
            XCTAssertTrue(mesh.uvs.allSatisfy(\.isFinite), name)
            XCTAssertTrue(mesh.indices.allSatisfy { Int($0) < vertexCount }, name)
            XCTAssertEqual(mesh.indices.count % 3, 0, name)
            let normalsAreUnit = stride(from: 0, to: mesh.normals.count, by: 3).allSatisfy { i in
                let n = SIMD3<Float>(mesh.normals[i], mesh.normals[i + 1], mesh.normals[i + 2])
                return abs(simd_length(n) - 1) < 0.001
            }
            XCTAssertTrue(normalsAreUnit, "Invalid surface normals in \(name)")

            let indices = try XCTUnwrap(mesh.boneIndices, name)
            let weights = try XCTUnwrap(mesh.boneWeights, name)
            XCTAssertEqual(indices.count, vertexCount * 4, name)
            XCTAssertEqual(weights.count, vertexCount * 4, name)
            XCTAssertTrue(indices.allSatisfy { skeleton.indices.contains($0) }, name)
            XCTAssertTrue(weights.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }, name)
            let weightsAreNormalized = stride(from: 0, to: weights.count, by: 4).allSatisfy { i in
                abs(weights[i..<(i + 4)].reduce(0, +) - 1) < 0.001
            }
            XCTAssertTrue(weightsAreNormalized, "Unnormalized skin weights in \(name)")
            XCTAssertEqual(mesh.bones?.map(\.name), skeleton.map(\.name), name)
            XCTAssertEqual(mesh.bones?.map(\.parent), skeleton.map(\.parent), name)
            XCTAssertEqual(mesh.bones?.map(\.position), skeleton.map(\.position), name)
        }
    }

    func testBodyProfilesKeepSkinAndClothingOnTheSameSkeleton() throws {
        for spec in presetAssets {
            try assertClothingSharesSkeleton(preset: spec.preset)
        }
    }

    private func assertClothingSharesSkeleton(preset: RallyAthletePreset) throws {
        var look = RallyAvatarAppearance(athletePreset: preset)
        let rig = RallyAvatarRig(appearance: look)
        XCTAssertNil(rig.assetError)
        let body = try XCTUnwrap(rig.root.childNode(withName: "Human skin", recursively: true))
        let skin = try XCTUnwrap(body.skinner)
        let originalBones = skin.bones
        XCTAssertEqual(originalBones.count, 163)

        for profile in [RallyAvatarBodyProfile.slim, .athletic, .strong] {
            look.bodyProfile = profile
            rig.apply(look)
            rig.animate(time: 0.4, swingProgress: 0.5)
            XCTAssertFalse(rig.root.isHidden)
            XCTAssertEqual(rig.root.scale.x, 1, accuracy: 0.0001)
            XCTAssertEqual(rig.root.scale.y, 1, accuracy: 0.0001)
            XCTAssertEqual(rig.root.scale.z, 1, accuracy: 0.0001)
            XCTAssertTrue(rig.root.childNode(withName: "Human skin", recursively: true) === body)
            for name in ["Performance tee", "Court shorts", "Court shoes"] {
                let garment = try XCTUnwrap(rig.root.childNode(withName: name, recursively: true), name)
                let garmentSkin = try XCTUnwrap(garment.skinner, name)
                XCTAssertTrue(garmentSkin.skeleton === skin.skeleton, name)
                XCTAssertEqual(garmentSkin.bones.count, originalBones.count, name)
                XCTAssertTrue(zip(garmentSkin.bones, originalBones).allSatisfy { $0 === $1 }, name)
                XCTAssertGreaterThan(garment.geometry?.elements.first?.primitiveCount ?? 0, 0, name)
            }
        }
    }

    func testTopPreviewLeavesIdentityAndOtherGearUnchanged() throws {
        let persisted = RallyAvatarAppearance()
        let rig = RallyAvatarRig(appearance: persisted)
        let body = try XCTUnwrap(rig.root.childNode(withName: "Human skin", recursively: true))
        let beforeShorts = try materialColor("Court shorts", in: rig)
        let beforeShoes = try materialColor("Court shoes", in: rig)
        let beforeSkin = try XCTUnwrap(body.geometry?.firstMaterial?.multiply.contents as? UIColor)
        var preview = persisted
        preview.top = RallyGearReference(id: "preview.performance.tee", colorwayHex: "#E82D55")
        rig.apply(preview)

        XCTAssertEqual(try materialColor("Performance tee", in: rig), preview.topUIColor)
        XCTAssertEqual(try materialColor("Court shorts", in: rig), beforeShorts)
        XCTAssertEqual(try materialColor("Court shoes", in: rig), beforeShoes)
        XCTAssertEqual(body.geometry?.firstMaterial?.multiply.contents as? UIColor, beforeSkin)
        XCTAssertTrue(rig.root.childNode(withName: "Human skin", recursively: true) === body)
        XCTAssertEqual(persisted, RallyAvatarAppearance())
    }

    func testSwitchingFromPoloToTeeRemovesItsCollar() {
        var look = RallyAvatarAppearance()
        look.top = RallyGearReference(id: "uniqlo.dry.polo.white", colorwayHex: "#117755")
        let rig = RallyAvatarRig(appearance: look, assetLoader: { name in
            if name == "polo" { throw CocoaError(.fileNoSuchFile) }
            return try RallyHumanMesh.load(name)
        })
        XCTAssertNotNil(rig.root.childNode(withName: "Polo collar", recursively: true))
        look.top = RallyGearReference(id: "preview.tee", colorwayHex: "#EEEEEE")
        rig.apply(look)
        XCTAssertNil(rig.root.childNode(withName: "Polo collar", recursively: true))
    }

    func testMissingOptionalGarmentsStillProduceAClothedPreview() throws {
        let rig = RallyAvatarRig(appearance: RallyAvatarAppearance(), assetLoader: { name in
            if ["shirt", "polo", "shorts", "shoes"].contains(name) {
                throw CocoaError(.fileNoSuchFile)
            }
            return try RallyHumanMesh.load(name)
        })
        XCTAssertNil(rig.assetError)
        XCTAssertFalse(rig.root.isHidden)
        for name in ["Performance tee", "Court shorts", "Court shoes"] {
            let node = try XCTUnwrap(rig.root.childNode(withName: name, recursively: true), name)
            XCTAssertFalse(node.isHidden, name)
            XCTAssertGreaterThan(node.geometry?.elements.first?.primitiveCount ?? 0, 0, name)
        }
    }

    func testMissingRequiredClothingNeverDisplaysAnUndressedBody() {
        for spec in presetAssets {
            let look = RallyAvatarAppearance(athletePreset: spec.preset)
            let rig = RallyAvatarRig(appearance: look, assetLoader: { name in
                if name.hasSuffix("helper-tights") { throw CocoaError(.fileReadCorruptFile) }
                return try RallyHumanMesh.load(name)
            })
            XCTAssertNotNil(rig.assetError)
            let body = rig.root.childNode(withName: "Human skin", recursively: true)
            XCTAssertTrue(rig.root.isHidden || body == nil || body?.isHidden == true)
        }
    }

    func testGameplayContactCrossesToTheCorrectSideForBothHandsAndLateralPositions() {
        for spec in presetAssets {
            let look = RallyAvatarAppearance(athletePreset: spec.preset)
            let rig = RallyAvatarRig(appearance: look, presentation: .gameplay)
            XCTAssertNil(rig.assetError)
            assertCorrectContactSide(rig)
        }
    }

    func testStrokePathsKeepTheEstablishedContactAndReturnToReady() {
        for leftHanded in [false, true] {
            let hand: Float = leftHanded ? -1 : 1
            for backhand in [false, true] {
                let contact = RallyAvatarRig.strokeWristTarget(progress: 0.5, backhand: backhand, leftHanded: leftHanded)
                XCTAssertEqual(contact.x, (backhand ? 0.26 : -0.46) * hand, accuracy: 0.000001)
                XCTAssertEqual(contact.y, 1.21 + 0.15, accuracy: 0.000001)
                XCTAssertEqual(contact.z, 0.31, accuracy: 0.000001)
                let ready = RallyAvatarRig.strokeWristTarget(progress: 0, backhand: backhand, leftHanded: leftHanded)
                let recovered = RallyAvatarRig.strokeWristTarget(progress: 1, backhand: backhand, leftHanded: leftHanded)
                XCTAssertLessThan(simd_distance(ready, recovered), 0.000001)
                let prepared = RallyAvatarRig.strokeWristTarget(progress: 0.22, backhand: backhand, leftHanded: leftHanded)
                let finish = RallyAvatarRig.strokeWristTarget(progress: 0.78, backhand: backhand, leftHanded: leftHanded)
                XCTAssertGreaterThan(contact.z - prepared.z, 0.20, "Preparation must travel into contact")
                XCTAssertGreaterThan(abs(finish.x - contact.x), 0.5, "The finish must cross through the stroke")
            }
        }
    }

    func testStrokePathsAreContinuousThroughContactAndMirrorForLeftHandedPlayers() {
        for backhand in [false, true] {
            var previous = RallyAvatarRig.strokeWristTarget(progress: 0, backhand: backhand, leftHanded: false)
            for frame in 1...240 {
                let p = Float(frame) / 240
                let right = RallyAvatarRig.strokeWristTarget(progress: p, backhand: backhand, leftHanded: false)
                let left = RallyAvatarRig.strokeWristTarget(progress: p, backhand: backhand, leftHanded: true)
                XCTAssertTrue(right.x.isFinite && right.y.isFinite && right.z.isFinite)
                XCTAssertLessThan(simd_distance(previous, right), 0.025, "No arm teleport between neighboring poses")
                XCTAssertEqual(left.x, -right.x, accuracy: 0.000001)
                XCTAssertEqual(left.y, right.y, accuracy: 0.000001)
                XCTAssertEqual(left.z, right.z, accuracy: 0.000001)
                previous = right
            }
            for knot: Float in [0.22, 0.5, 0.78] {
                let epsilon: Float = 0.0001
                let before = RallyAvatarRig.strokeWristTarget(progress: knot - epsilon, backhand: backhand, leftHanded: false)
                let at = RallyAvatarRig.strokeWristTarget(progress: knot, backhand: backhand, leftHanded: false)
                let after = RallyAvatarRig.strokeWristTarget(progress: knot + epsilon, backhand: backhand, leftHanded: false)
                XCTAssertLessThan(simd_length((at - before) / epsilon - (after - at) / epsilon), 0.025,
                                  "Stroke velocity should not stop or jump at a phase boundary")
            }
        }
    }

    func testStrokeRecoveryDoesNotSnapTheRacketOrHandsAtTheReadyBoundary() throws {
        for preset in [RallyAthletePreset.maleEuropean, .femaleBlack] {
            let rig = RallyAvatarRig(appearance: RallyAvatarAppearance(athletePreset: preset), presentation: .gameplay)
            for leftHanded in [false, true] {
                for backhand in [false, true] {
                    rig.animate(time: 1.0, swingProgress: 1, backhand: backhand, leftHanded: leftHanded)
                    let racketFinish = rig.racketHeadWorldPosition
                    let wrist = try XCTUnwrap(rig.root.childNode(withName: leftHanded ? "wrist.R" : "wrist.L", recursively: true))
                    let handFinish = wrist.simdWorldPosition
                    rig.animate(time: 1.0, leftHanded: leftHanded)
                    let racketReady = rig.racketHeadWorldPosition
                    XCTAssertEqual(racketFinish.x, racketReady.x, accuracy: 0.0001)
                    XCTAssertEqual(racketFinish.y, racketReady.y, accuracy: 0.0001)
                    XCTAssertEqual(racketFinish.z, racketReady.z, accuracy: 0.0001)
                    XCTAssertLessThan(simd_distance(handFinish, wrist.simdWorldPosition), 0.0001)
                }
            }
        }
    }

    func testTwoHandedBackhandKeepsTheSupportingPalmOnTheUpperHandle() throws {
        for spec in presetAssets {
            let rig = RallyAvatarRig(appearance: RallyAvatarAppearance(athletePreset: spec.preset), presentation: .gameplay)
            XCTAssertNil(rig.assetError)
            for leftHanded in [false, true] {
                let supportSide = leftHanded ? "R" : "L"
                let dominantSide = leftHanded ? "L" : "R"
                for p: Float in [0.18, 0.22, 0.34, 0.42, 0.5, 0.6, 0.7, 0.76, 0.82] {
                    rig.animate(time: 0, swingProgress: p, backhand: true, leftHanded: leftHanded)
                    let grip = try XCTUnwrap(rig.backhandGripPositions(leftHanded: leftHanded))
                    XCTAssertLessThan(simd_distance(grip.palm, grip.handle), 0.015,
                                      "Upper palm must hold the handle: \(spec.preset), left=\(leftHanded), p=\(p)")
                    if p <= 0.5 {
                        let chest = try XCTUnwrap(rig.root.childNode(withName: "spine01", recursively: true))
                        for side in [dominantSide, supportSide] {
                            let elbow = try XCTUnwrap(rig.root.childNode(withName: "lowerarm01.\(side)", recursively: true))
                            let elbowInChest = chest.simdConvertPosition(elbow.simdWorldPosition, from: nil)
                            if abs(elbowInChest.x) < 0.17 {
                                XCTAssertGreaterThan(elbowInChest.z, 0.13,
                                                     "Elbow crossing the chest must clear the shirt: \(spec.preset), left=\(leftHanded), side=\(side), p=\(p)")
                            }
                        }
                    }
                    let finger = try XCTUnwrap(rig.root.childNode(withName: "finger3-2.\(supportSide)", recursively: true))
                    XCTAssertGreaterThan(abs(finger.simdOrientation.angle), 1.4, "Supporting fingers must wrap, not hover open")
                    let racket = try XCTUnwrap(rig.root.childNode(withName: "Tennis racket", recursively: true))
                    XCTAssertEqual(racket.parent?.name, "wrist.\(dominantSide)")
                    var racketCount = 0
                    rig.root.enumerateChildNodes { node, _ in
                        if node.name == "Tennis racket" { racketCount += 1 }
                    }
                    XCTAssertEqual(racketCount, 1)
                    let withSupport = rig.racketHeadWorldPosition
                    rig.setRacketVisible(false)
                    rig.animate(time: 0, swingProgress: p, backhand: true, leftHanded: leftHanded)
                    XCTAssertEqual(rig.racketHeadWorldPosition.x, withSupport.x, accuracy: 0.0001)
                    XCTAssertEqual(rig.racketHeadWorldPosition.y, withSupport.y, accuracy: 0.0001)
                    XCTAssertEqual(rig.racketHeadWorldPosition.z, withSupport.z, accuracy: 0.0001)
                    rig.setRacketVisible(true)
                }
            }
        }
    }

    func testBackhandGripJoinsAndReleasesWithoutHandOrFingerJumps() throws {
        XCTAssertEqual(RallyAvatarRig.backhandGripEngagement(progress: 0), 0)
        XCTAssertEqual(RallyAvatarRig.backhandGripEngagement(progress: 1), 0)
        XCTAssertEqual(RallyAvatarRig.backhandGripEngagement(progress: .nan), 0)
        for p: Float in [0.18, 0.5, 0.82] {
            XCTAssertEqual(RallyAvatarRig.backhandGripEngagement(progress: p), 1, accuracy: 0.00001)
        }
        for preset in [RallyAthletePreset.maleEuropean, .femaleBlack] {
            let rig = RallyAvatarRig(appearance: RallyAvatarAppearance(athletePreset: preset), presentation: .gameplay)
            for leftHanded in [false, true] {
                let side = leftHanded ? "R" : "L"
                let wrist = try XCTUnwrap(rig.root.childNode(withName: "wrist.\(side)", recursively: true))
                let finger = try XCTUnwrap(rig.root.childNode(withName: "finger3-2.\(side)", recursively: true))
                rig.animate(time: 0, leftHanded: leftHanded)
                let readyPosition = wrist.simdWorldPosition
                let readyOrientation = wrist.simdWorldOrientation
                let readyFinger = finger.simdOrientation
                var previousPosition = readyPosition
                var previousFinger = readyFinger
                for step in 0...120 {
                    let p = Float(step) / 120
                    rig.animate(time: 0, swingProgress: p, backhand: true, leftHanded: leftHanded)
                    XCTAssertLessThan(simd_distance(previousPosition, wrist.simdWorldPosition), 0.070,
                                      "No hand teleport while joining/releasing: left=\(leftHanded), p=\(p)")
                    XCTAssertGreaterThan(abs(simd_dot(previousFinger.vector, finger.simdOrientation.vector)), 0.93)
                    previousPosition = wrist.simdWorldPosition
                    previousFinger = finger.simdOrientation
                }
                XCTAssertLessThan(simd_distance(readyPosition, wrist.simdWorldPosition), 0.0001)
                XCTAssertGreaterThan(abs(simd_dot(readyOrientation.vector, wrist.simdWorldOrientation.vector)), 0.9999)
                XCTAssertGreaterThan(abs(simd_dot(readyFinger.vector, finger.simdOrientation.vector)), 0.9999)
            }
        }
    }

    /// Close render evidence makes both palms/fingers and the single handle
    /// inspectable for each athlete and handedness at all three held phases.
    func testRasterizeTwoHandedBackhandsForVisualReview() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        for spec in presetAssets {
            try autoreleasepool {
                let look = RallyAvatarAppearance(athletePreset: spec.preset,
                    top: RallyGearReference(id: "proof.tee", colorwayHex: "#EFECE3"))
                let rig = RallyAvatarRig(appearance: look, presentation: .gameplay)
                XCTAssertNil(rig.assetError)
                rig.scene.background.contents = UIColor(red: 0.055, green: 0.075, blue: 0.07, alpha: 1)
                rig.camera.camera?.orthographicScale = 0.78
                rig.camera.position = SCNVector3(0, 1.40, 3)
                rig.camera.look(at: SCNVector3(0, 1.40, 0))
                let renderer = SCNRenderer(device: device, options: nil)
                renderer.scene = rig.scene
                renderer.pointOfView = rig.camera
                renderer.autoenablesDefaultLighting = false
                for leftHanded in [false, true] {
                    for (phase, p) in [("load", Float(0.22)), ("contact", Float(0.5)), ("finish", Float(0.76))] {
                        rig.animate(time: 0, swingProgress: p, backhand: true, leftHanded: leftHanded)
                        // Front three-quarter evidence avoids hiding the grip
                        // behind the player's torso as the gameplay camera does.
                        rig.root.eulerAngles.y = leftHanded ? 0.25 : -0.25
                        SCNTransaction.flush()
                        let capture = renderer.snapshot(atTime: 1, with: CGSize(width: 768, height: 768),
                                                        antialiasingMode: .multisampling4X)
                        let attachment = XCTAttachment(image: capture)
                        attachment.name = "backhand-\(spec.preset.rawValue)-\(leftHanded ? "left" : "right")-\(phase)"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    }
                }
            }
        }
    }

    func testAthleticLoadingCoilsBeforeContactAndTransfersWeightAfterIt() {
        for leftHanded in [false, true] {
            for backhand in [false, true] {
                let direction: Float = (leftHanded ? -1 : 1) * (backhand ? -1 : 1)
                for p: Float in [0, 0.5, 1] {
                    XCTAssertEqual(RallyAvatarRig.groundstrokeBodyMotion(progress: p, backhand: backhand, leftHanded: leftHanded),
                                   RallyAvatarRig.BodyMotion(), "Contact and ready poses must retain their existing transforms")
                }
                let load = RallyAvatarRig.groundstrokeBodyMotion(progress: 0.22, backhand: backhand, leftHanded: leftHanded)
                let finish = RallyAvatarRig.groundstrokeBodyMotion(progress: 0.76, backhand: backhand, leftHanded: leftHanded)
                XCTAssertLessThan((load.lowerSpineYaw + load.upperSpineYaw) * direction, -0.6)
                XCTAssertGreaterThan((finish.lowerSpineYaw + finish.upperSpineYaw) * direction, 0.3)
                XCTAssertLessThan(load.pelvisOffset.x * direction, 0)
                XCTAssertGreaterThan(finish.pelvisOffset.x * direction, 0)
                XCTAssertLessThan(load.pelvisOffset.y, -0.015, "Loading should compress the knees before the hit")
                XCTAssertGreaterThan(finish.pelvisOffset.z, 0.015, "The finish should carry weight forward")
                let mirrored = RallyAvatarRig.groundstrokeBodyMotion(progress: 0.22, backhand: backhand, leftHanded: !leftHanded)
                XCTAssertEqual(load.pelvisOffset.x, -mirrored.pelvisOffset.x)
                XCTAssertEqual(load.pelvisYaw, -mirrored.pelvisYaw)
                XCTAssertEqual(load.upperSpineYaw, -mirrored.upperSpineYaw)
            }
        }
    }

    func testLoadedStrokesKeepStationaryShoesAnchoredForBothCourtPlayers() throws {
        for preset in [RallyAthletePreset.maleEuropean, .femaleBlack] {
            for presentation in [RallyAvatarRig.Presentation.gameplay, .opponent] {
                let rig = RallyAvatarRig(appearance: RallyAvatarAppearance(athletePreset: preset), presentation: presentation)
                let feet = try ["foot.L", "foot.R"].map { try XCTUnwrap(rig.root.childNode(withName: $0, recursively: true)) }
                rig.animate(time: 0)
                let anchors = feet.map(\.simdWorldPosition)
                for leftHanded in [false, true] {
                    for backhand in [false, true] {
                        for p: Float in [0, 0.12, 0.22, 0.36, 0.5, 0.64, 0.76, 0.90, 1] {
                            rig.animate(time: 0, swingProgress: p, backhand: backhand, leftHanded: leftHanded)
                            for (index, foot) in feet.enumerated() {
                                XCTAssertLessThan(simd_distance(foot.simdWorldPosition, anchors[index]), 0.002,
                                                  "Hip loading must not slide or lift a stationary shoe")
                                let up = simd_normalize(foot.simdConvertVector(SIMD3<Float>(0, 1, 0), to: nil))
                                XCTAssertGreaterThan(up.y, 0.995)
                            }
                            let racket = rig.racketHeadWorldPosition
                            XCTAssertTrue(racket.x.isFinite && racket.y.isFinite && racket.z.isFinite)
                        }
                    }
                }
            }
        }
    }

    func testServeFollowThroughSettlesIntoGameplayReadyWithoutAJump() throws {
        for preset in [RallyAthletePreset.maleEuropean, .femaleBlack] {
            let rig = RallyAvatarRig(appearance: RallyAvatarAppearance(athletePreset: preset), presentation: .gameplay)
            let names = ["root", "wrist.L", "wrist.R", "foot.L", "foot.R"]
            let joints = try names.map { try XCTUnwrap(rig.root.childNode(withName: $0, recursively: true)) }
            for leftHanded in [false, true] {
                rig.animate(time: 0, leftHanded: leftHanded)
                let readyPositions = joints.map(\.simdWorldPosition)
                let readyRacket = rig.racketHeadWorldPosition
                rig.animateLesson(progress: 1, leftHanded: leftHanded, serve: true)
                for (index, joint) in joints.enumerated() {
                    XCTAssertLessThan(simd_distance(joint.simdWorldPosition, readyPositions[index]), 0.0002, names[index])
                }
                XCTAssertEqual(rig.racketHeadWorldPosition.x, readyRacket.x, accuracy: 0.0002)
                XCTAssertEqual(rig.racketHeadWorldPosition.y, readyRacket.y, accuracy: 0.0002)
                XCTAssertEqual(rig.racketHeadWorldPosition.z, readyRacket.z, accuracy: 0.0002)

                rig.animateLesson(progress: 0.75, leftHanded: leftHanded, serve: true)
                let lowerSpine = try XCTUnwrap(rig.root.childNode(withName: "spine03", recursively: true))
                XCTAssertEqual(lowerSpine.eulerAngles.x, 0.0625, accuracy: 0.0001,
                               "Serve contact keeps the established extension")
                XCTAssertEqual(lowerSpine.eulerAngles.y, (leftHanded ? 1 : -1) * sin(Float.pi * 0.75) * 0.25, accuracy: 0.0001)
                let upperSpine = try XCTUnwrap(rig.root.childNode(withName: "spine01", recursively: true))
                XCTAssertEqual(upperSpine.eulerAngles.y, 0, accuracy: 0.0001)
            }
        }
    }

    func testClippedGarmentEdgesStayOnTheSeamAndRetainNormalizedSkinning() throws {
        for prefix in ["", "female-"] {
            let source = try RallyHumanMesh.load(prefix + "shoes")
            let cut: Float = 0.012
            for keepAbove in [false, true] {
                let mesh = source.clipped(atY: cut, keepAbove: keepAbove)
                XCTAssertFalse(mesh.indices.isEmpty)
                let count = mesh.positions.count / 3
                XCTAssertEqual(mesh.normals.count, count * 3)
                XCTAssertEqual(mesh.uvs.count, count * 2)
                let weights = try XCTUnwrap(mesh.boneWeights)
                let joints = try XCTUnwrap(mesh.boneIndices)
                XCTAssertEqual(weights.count, count * 4)
                XCTAssertEqual(joints.count, count * 4)
                XCTAssertTrue(mesh.positions.allSatisfy(\.isFinite))
                XCTAssertTrue(mesh.normals.allSatisfy(\.isFinite))
                var seamCount = 0
                for vertex in Set(mesh.indices) {
                    let y = mesh.positions[Int(vertex) * 3 + 1]
                    XCTAssertTrue(keepAbove ? y >= cut - 0.000001 : y <= cut + 0.000001,
                                  "No original triangle may cross the new material seam")
                    if abs(y - cut) < 0.000001 { seamCount += 1 }
                    let start = Int(vertex) * 4
                    XCTAssertEqual(weights[start..<(start + 4)].reduce(0, +), 1, accuracy: 0.00001)
                }
                XCTAssertGreaterThan(seamCount, 8, "A cut must insert a connected boundary, not discard intersecting faces")
            }
        }
    }

    func testCoveredFeetCannotBreakThroughMandatoryFootwear() throws {
        for spec in presetAssets {
            let rig = RallyAvatarRig(appearance: RallyAvatarAppearance(athletePreset: spec.preset))
            let geometry = try XCTUnwrap(rig.root.childNode(withName: "Human skin", recursively: true)?.geometry)
            let source = try XCTUnwrap(geometry.sources(for: .vertex).first)
            let element = try XCTUnwrap(geometry.elements.first)
            let indices = element.data.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) }
            source.data.withUnsafeBytes { buffer in
                for index in Set(indices) {
                    let y = buffer.loadUnaligned(fromByteOffset: source.dataOffset + Int(index) * source.dataStride + MemoryLayout<Float>.size, as: Float.self)
                    XCTAssertGreaterThan(y, 0.12, "Hidden feet must not reappear through shoes during a pose")
                }
            }
            XCTAssertNotNil(rig.root.childNode(withName: "Court shoes", recursively: true))
            XCTAssertNotNil(rig.root.childNode(withName: "Court shoe soles", recursively: true))
        }
    }

    private func assertCorrectContactSide(_ rig: RallyAvatarRig) {
        for leftHanded in [false, true] {
            for lateral: Float in [-1, 0, 1] {
                let forehandSign: Float = leftHanded ? -1 : 1
                rig.animate(time: 0, swingProgress: 0.5, backhand: false, lateral: lateral, leftHanded: leftHanded)
                let forehand = rig.camera.convertPosition(rig.racketHeadWorldPosition, from: nil)
                let center = rig.camera.convertPosition(rig.root.worldPosition, from: nil)
                XCTAssertGreaterThan((forehand.x - center.x) * forehandSign, 0,
                                     "Forehand racket must reach its court side; leftHanded=\(leftHanded), lateral=\(lateral)")
                rig.animate(time: 0, swingProgress: 0.5, backhand: true, lateral: lateral, leftHanded: leftHanded)
                let backhand = rig.camera.convertPosition(rig.racketHeadWorldPosition, from: nil)
                XCTAssertLessThan((backhand.x - center.x) * forehandSign, 0,
                                  "Backhand must cross the body; leftHanded=\(leftHanded), lateral=\(lateral)")
                XCTAssertTrue(forehand.y.isFinite && backhand.y.isFinite)
            }
        }
    }

    func testRhythmicStanceKeepsBothFeetPlantedAcrossProfiles() throws {
        for spec in presetAssets {
            try assertFeetStayPlanted(preset: spec.preset)
        }
    }

    private func assertFeetStayPlanted(preset: RallyAthletePreset) throws {
        for presentation in [RallyAvatarRig.Presentation.studio, .gameplay] {
            var look = RallyAvatarAppearance(athletePreset: preset)
            let rig = RallyAvatarRig(appearance: look, presentation: presentation)
            let left = try XCTUnwrap(rig.root.childNode(withName: "foot.L", recursively: true))
            let right = try XCTUnwrap(rig.root.childNode(withName: "foot.R", recursively: true))
            rig.animate(time: 0)
            let plantedHeights = [left.worldPosition.y, right.worldPosition.y]
            for profile in [RallyAvatarBodyProfile.slim, .athletic, .strong] {
                look.bodyProfile = profile
                rig.apply(look)
                for time in [0.0, 0.35, 0.9, 1.7, 2.6, 4.2] {
                    for swing: Float? in [nil, 0.25, 0.5, 0.8] {
                        rig.animate(time: time, swingProgress: swing, lateral: Float(sin(time)))
                        for (index, foot) in [left, right].enumerated() {
                            XCTAssertEqual(foot.worldPosition.y, plantedHeights[index], accuracy: 0.006,
                                           "The planted ankle must not bounce with the pelvis rhythm")
                            let up = simd_normalize(foot.simdConvertVector(SIMD3<Float>(0, 1, 0), to: nil))
                            XCTAssertGreaterThan(up.y, 0.995, "Foot orientation must stay flat through the stance")
                        }
                    }
                }
            }
        }
    }

    func testSixPresetsHaveDistinctAuthoredAnatomyAndRoundTripIdentity() throws {
        XCTAssertEqual(presetAssets.count, 6)
        var vertexData = Set<Data>()
        for spec in presetAssets {
            let mesh = try RallyHumanMesh.load(spec.prefix + "athlete")
            let vertices = try XCTUnwrap(mesh.geometry().sources(for: .vertex).first?.data)
            XCTAssertTrue(vertexData.insert(vertices).inserted, "Each preset must have distinct authored anatomy")
            let look = RallyAvatarAppearance(athletePreset: spec.preset)
            let restored = try JSONDecoder().decode(RallyAvatarAppearance.self, from: JSONEncoder().encode(look))
            XCTAssertEqual(restored, look)
            XCTAssertEqual(restored.athletePreset, spec.preset)
        }
    }

    func testSwitchingPresetOnOneRigReplacesAnatomyAndKeepsEquippedClothing() throws {
        var look = RallyAvatarAppearance(athletePreset: .maleEuropean)
        look.top = RallyGearReference(id: "test.tee", colorwayHex: "#DD4466")
        look.shorts = RallyGearReference(id: "test.shorts", colorwayHex: "#224466")
        let rig = RallyAvatarRig(appearance: look, presentation: .gameplay)
        let camera = rig.camera
        var previousBody = try XCTUnwrap(rig.root.childNode(withName: "Human skin", recursively: true))
        var previousVertices = try XCTUnwrap(previousBody.geometry?.sources(for: .vertex).first?.data)
        var previousBones = try XCTUnwrap(previousBody.skinner?.bones)

        let sequence: [RallyAthletePreset] = [.femaleEuropean, .maleAsian, .femaleAsian, .maleBlack, .femaleBlack, .maleEuropean]
        for preset in sequence {
            look.athletePreset = preset
            rig.apply(look)
            rig.animate(time: 0.6, swingProgress: 0.5)
            XCTAssertNil(rig.assetError)
            XCTAssertFalse(rig.root.isHidden)
            XCTAssertTrue(rig.camera === camera)
            let body = try XCTUnwrap(rig.root.childNode(withName: "Human skin", recursively: true))
            let vertices = try XCTUnwrap(body.geometry?.sources(for: .vertex).first?.data)
            let skin = try XCTUnwrap(body.skinner)
            XCTAssertFalse(body === previousBody)
            XCTAssertNil(previousBody.parent, "The prior body must leave the scene")
            XCTAssertNotEqual(vertices, previousVertices)
            XCTAssertEqual(skin.bones.count, 163)
            XCTAssertTrue(zip(skin.bones, previousBones).allSatisfy { $0 !== $1 })
            for name in ["Performance tee", "Court shorts", "Court shoes"] {
                let garment = try XCTUnwrap(rig.root.childNode(withName: name, recursively: true))
                let garmentSkin = try XCTUnwrap(garment.skinner)
                XCTAssertTrue(garmentSkin.skeleton === skin.skeleton)
                XCTAssertTrue(zip(garmentSkin.bones, skin.bones).allSatisfy { $0 === $1 })
            }
            XCTAssertEqual(try materialColor("Performance tee", in: rig), look.topUIColor)
            XCTAssertEqual(try materialColor("Court shorts", in: rig), look.shortsUIColor)
            var bodyCount = 0
            var racketCount = 0
            rig.root.enumerateChildNodes { node, _ in
                if node.name == "Human skin" { bodyCount += 1 }
                if node.name == "Tennis racket" { racketCount += 1 }
            }
            XCTAssertEqual(bodyCount, 1)
            XCTAssertEqual(racketCount, 1, "Model switching must retain one attached racket")
            assertCorrectContactSide(rig)
            previousBody = body
            previousVertices = vertices
            previousBones = skin.bones
        }
    }

    func testSkinAndHairColorOverridesChangeRenderingWithoutReplacingModelsOrClothes() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        for preset in [RallyAthletePreset.maleBlack, .femaleEuropean] {
            var look = RallyAvatarAppearance(athletePreset: preset)
            let rig = RallyAvatarRig(appearance: look)
            XCTAssertNil(rig.assetError)
            rig.animate(time: 1.0)
            rig.scene.background.contents = UIColor(white: 0.06, alpha: 1)
            let body = try XCTUnwrap(rig.root.childNode(withName: "Human skin", recursively: true))
            let skin = try XCTUnwrap(body.skinner)
            let originalBones = skin.bones
            let clothes = try ["Performance tee", "Court shorts", "Court shoes"].map { name in
                try XCTUnwrap(rig.root.childNode(withName: name, recursively: true), name)
            }
            let garmentColors = try ["Performance tee", "Court shorts", "Court shoes"].map {
                try materialColor($0, in: rig)
            }
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = rig.scene
            renderer.pointOfView = rig.camera
            renderer.autoenablesDefaultLighting = false
            let render = { () -> UIImage in
                SCNTransaction.flush()
                return renderer.snapshot(atTime: 1.0, with: CGSize(width: 384, height: 512),
                                         antialiasingMode: .multisampling4X)
            }
            let before = render()
            let unchanged = render()
            let noise = try meanColorDifference(before, unchanged)
            let originalGeometry = geometryVertices(in: rig.root)
            look.skinToneOverrideHex = preset == .maleBlack ? "#E9C6A5" : "#633D2A"
            rig.apply(look)
            let skinChanged = render()
            XCTAssertGreaterThan(try meanColorDifference(unchanged, skinChanged), max(0.0002, noise * 5),
                                 "Skin color selection must visibly change the rendered material")
            look.hairColorOverrideHex = "#E6BE62"
            rig.apply(look)
            let hairChanged = render()
            XCTAssertGreaterThan(try meanColorDifference(skinChanged, hairChanged), max(0.0002, noise * 5),
                                 "Hair color selection must visibly change the rendered material")

            XCTAssertTrue(rig.root.childNode(withName: "Human skin", recursively: true) === body)
            XCTAssertTrue(body.skinner === skin)
            XCTAssertTrue(zip(skin.bones, originalBones).allSatisfy { $0 === $1 })
            XCTAssertEqual(geometryVertices(in: rig.root), originalGeometry, "Color must not change the body or hair shape")
            for (index, garment) in clothes.enumerated() {
                let name = try XCTUnwrap(garment.name)
                XCTAssertTrue(rig.root.childNode(withName: name, recursively: true) === garment)
                XCTAssertEqual(try materialColor(name, in: rig), garmentColors[index])
            }
            let family = preset.athleteModel == .male ? "male" : "female"
            let label = preset.displayName.lowercased().replacingOccurrences(of: " ", with: "-")
            for (state, capture) in [("before", before), ("after", hairChanged)] {
                let attachment = XCTAttachment(image: capture)
                attachment.name = "colors-\(family)-\(label)-\(state)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    /// Produces inspectable iOS SceneKit evidence, not a pixel-based quality
    /// assertion. Run this method alone when refreshing the roster review.
    func testRasterizeRosterForVisualReview() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "Roster capture requires a Metal renderer")
        for spec in presetAssets {
            try autoreleasepool {
                let look = RallyAvatarAppearance(
                    athletePreset: spec.preset,
                    top: RallyGearReference(id: "uniqlo.dry.polo.white", colorwayHex: "#F4F4F2"),
                    shorts: RallyGearReference(id: "proof.shorts", colorwayHex: "#15171B")
                )
                let rig = RallyAvatarRig(appearance: look, presentation: .studio)
                XCTAssertNil(rig.assetError)
                XCTAssertFalse(rig.root.isHidden)
                _ = try XCTUnwrap(rig.root.childNode(withName: "Polo", recursively: true))
                _ = try XCTUnwrap(rig.root.childNode(withName: "Court shorts", recursively: true))
                rig.scene.background.contents = UIColor(red: 0.055, green: 0.065, blue: 0.08, alpha: 1)
                rig.animate(time: 1.0)
                SCNTransaction.flush()

                let renderer = SCNRenderer(device: device, options: nil)
                renderer.scene = rig.scene
                renderer.pointOfView = rig.camera
                renderer.autoenablesDefaultLighting = false
                let capture = renderer.snapshot(atTime: 1.0, with: CGSize(width: 768, height: 1024),
                                                antialiasingMode: .multisampling4X)
                let attachment = XCTAttachment(image: capture)
                let model = spec.preset.athleteModel == .male ? "male" : "female"
                let label = spec.preset.displayName.lowercased().replacingOccurrences(of: " ", with: "-")
                attachment.name = "roster-\(model)-\(label)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    private func materialColor(_ name: String, in rig: RallyAvatarRig) throws -> UIColor {
        let node = try XCTUnwrap(rig.root.childNode(withName: name, recursively: true), name)
        let material = try XCTUnwrap(node.geometry?.firstMaterial, name)
        return try XCTUnwrap((material.diffuse.contents as? UIColor) ?? (material.multiply.contents as? UIColor), name)
    }

    private func geometryVertices(in root: SCNNode) -> [Data] {
        var vertices: [Data] = []
        root.enumerateChildNodes { node, _ in
            if let data = node.geometry?.sources(for: .vertex).first?.data { vertices.append(data) }
        }
        return vertices
    }

    private func meanColorDifference(_ first: UIImage, _ second: UIImage) throws -> Double {
        func rgba(_ image: UIImage) throws -> [UInt8] {
            let cgImage = try XCTUnwrap(image.cgImage)
            var pixels = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
            try pixels.withUnsafeMutableBytes { bytes in
                let context = try XCTUnwrap(CGContext(
                    data: bytes.baseAddress, width: cgImage.width, height: cgImage.height,
                    bitsPerComponent: 8, bytesPerRow: cgImage.width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                ))
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
            }
            return pixels
        }
        let a = try rgba(first)
        let b = try rgba(second)
        XCTAssertEqual(a.count, b.count)
        guard !a.isEmpty, a.count == b.count else { return 0 }
        var total: Double = 0
        for i in a.indices where i % 4 != 3 { total += Double(abs(Int(a[i]) - Int(b[i]))) }
        return total / (Double(a.count / 4 * 3) * 255)
    }
}
