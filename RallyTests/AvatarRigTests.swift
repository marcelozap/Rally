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
