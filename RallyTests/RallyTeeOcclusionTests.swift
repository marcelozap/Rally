import XCTest
@testable import Rally

@MainActor
final class RallyTeeOcclusionTests: XCTestCase {
    func testOnlyFullyCoveredTrianglesAboveTheTeeHemAreHidden() {
        let mesh = fixture(heights: [
            1.2, 1.2, 1.2, // Authored covered region.
            1.2, 1.2, 1.2, // One exposed source vertex at the cuff/neck edge.
            1.2, 1.2, 1.0, // Crosses the hem; preserve the edge.
            0.8, 0.8, 0.8  // The original outfit's jeans must not hide legs.
        ])
        let result = mesh.hidingTeeCoveredSkin(
            sourceVertexIndices: [1355, 1356, 1357, 1355, 1356, 42,
                                  1355, 1356, 1357, 1355, 1356, 1357],
            aboveHem: 1.0
        )
        XCTAssertEqual(result.indices, Array(mesh.indices.dropFirst(3)))
        XCTAssertEqual(result.positions, mesh.positions)
        XCTAssertEqual(result.normals, mesh.normals)
        XCTAssertEqual(result.uvs, mesh.uvs)
        XCTAssertEqual(result.boneWeights, mesh.boneWeights)
        XCTAssertEqual(result.boneIndices, mesh.boneIndices)
    }

    func testUnknownAndInterpolatedSourceVerticesRemainVisible() {
        let mesh = fixture(heights: [1.2, 1.2, 1.2, 1.2, 1.2, 1.2])
        let result = mesh.hidingTeeCoveredSkin(
            sourceVertexIndices: [1355, 1356, -1, 42, 43, 44], aboveHem: 1.0
        )
        XCTAssertEqual(result.indices, mesh.indices)
    }

    func testInvalidCorrespondenceOrHemDoesNotRemoveSkin() {
        let mesh = fixture(heights: [1.2, 1.2, 1.2])
        for sourceIndices in [[], [1355], [1355, 1356, 1357, 1358]] {
            XCTAssertEqual(mesh.hidingTeeCoveredSkin(sourceVertexIndices: sourceIndices, aboveHem: 1).indices,
                           mesh.indices)
        }
        for hem: Float in [.nan, .infinity, -.infinity] {
            XCTAssertEqual(mesh.hidingTeeCoveredSkin(sourceVertexIndices: [1355, 1356, 1357], aboveHem: hem).indices,
                           mesh.indices)
        }
    }

    func testAllAthleteIdentitiesKeepTheSourceCorrespondenceRequiredByTheTeeMask() throws {
        for name in ["athlete", "male-asian-athlete", "male-black-athlete",
                     "female-athlete", "female-asian-athlete", "female-black-athlete"] {
            let mesh = try RallyHumanMesh.load(name)
            let sourceIndices = try XCTUnwrap(mesh.sourceVertexIndices, name)
            XCTAssertEqual(sourceIndices.count, mesh.positions.count / 3, name)
            let hem: Float = name.hasPrefix("female-") ? 0.915 : 0.990
            let masked = mesh.hidingTeeCoveredSkin(sourceVertexIndices: sourceIndices, aboveHem: hem)
            XCTAssertLessThan(masked.indices.count, mesh.indices.count, name)
            // Every triangle reaching the exposed legs remains in the same order.
            func belowHemTriangles(_ indices: [UInt32]) -> [[UInt32]] {
                stride(from: 0, to: indices.count, by: 3).compactMap { offset in
                    let triangle = Array(indices[offset..<(offset + 3)])
                    return triangle.contains { mesh.positions[Int($0) * 3 + 1] <= hem } ? triangle : nil
                }
            }
            XCTAssertEqual(belowHemTriangles(masked.indices), belowHemTriangles(mesh.indices), name)
        }
    }

    private func fixture(heights: [Float]) -> RallyHumanMesh {
        RallyHumanMesh(
            positions: heights.enumerated().flatMap { [Float($0.offset % 3) * 0.01, $0.element, 0] },
            normals: heights.flatMap { _ in [Float(0), 0, 1] },
            uvs: heights.flatMap { _ in [Float(0), 0] },
            indices: heights.indices.map(UInt32.init),
            bones: nil,
            boneIndices: heights.flatMap { _ in [0, 0, 0, 0] },
            boneWeights: heights.flatMap { _ in [Float(1), 0, 0, 0] }
        )
    }
}
