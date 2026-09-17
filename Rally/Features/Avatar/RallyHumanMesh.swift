import Foundation

extension RallyHumanMesh {
    /// Hide only skin explicitly covered by the authored casualsuit tee.
    /// Call when the wardrobe changes, using the same-sex tee's final hem.
    /// The source mask also covers jeans, so the hem condition is mandatory.
    /// Do not use this mask for tanks, polos or unrelated product-specific meshes.
    func hidingTeeCoveredSkin(sourceVertexIndices: [Int], aboveHem hem: Float) -> Self {
        guard sourceVertexIndices.count == positions.count / 3, hem.isFinite else { return self }
        let covered = sourceVertexIndices.enumerated().map { vertex, source in
            positions[vertex * 3 + 1] > hem && Self.teeCoveredBodySourceVertices.contains(source)
        }
        var result = self
        result.indices = []
        result.indices.reserveCapacity(indices.count)
        for triangle in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[triangle])
            let b = Int(indices[triangle + 1])
            let c = Int(indices[triangle + 2])
            // Preserve the exposed edge; never remove a partially covered face.
            if !(covered[a] && covered[b] && covered[c]) {
                result.indices.append(contentsOf: indices[triangle..<(triangle + 3)])
            }
        }
        return result
    }

    // CC0 MakeHuman system assets: male_casualsuit04.mhclo / delete_verts.
    // Exact original source-OBJ IDs, matching athlete.json sourceVertexIndices.
    // Asset manifest source SHA-256:
    // 8c1a2d3272cd51ba03f0840d593eddc6325d3d2c4c8529f8203d2c2cad3d0cef
    // https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip
    // Extracted from ZIP member clothes/male_casualsuit04/male_casualsuit04.mhclo.
    private static let teeCoveredBodySourceVertices: Set<Int> = {
        let ranges: [ClosedRange<Int>] = [
            1355...1394, 1399...1402, 1404...1413, 1420...1423, 1430...1453,
            1455...1455, 1458...1459, 1471...1474, 1476...1477, 1502...1502,
            1506...1508, 1527...1643, 1653...1653, 1663...1686, 1689...1693,
            1762...1897, 3753...3760, 3774...3783, 3786...3787, 3837...3846,
            3849...3849, 3871...3871, 3923...4773, 6335...6335, 6390...6390,
            6392...6413, 6431...6431, 6736...6755, 8047...8086, 8092...8101,
            8108...8111, 8118...8141, 8143...8143, 8146...8147, 8158...8160,
            8162...8163, 8186...8186, 8190...8192, 8208...8315, 8325...8325,
            8335...8358, 8361...8365, 8434...8565, 10420...10427, 10441...10449,
            10452...10453, 10503...10511, 10514...10514, 10536...10536, 10588...11391,
            12932...12932, 12987...12987, 12989...13010, 13332...13351, 15128...15327,
            15556...15576, 15580...15587, 15594...15610, 15615...15660, 15675...15676,
            15678...15692, 15701...15701, 15712...15712, 15725...15745, 15757...15757,
            15760...15760, 15768...15768, 15772...15773, 15781...15781, 15792...15792,
            15803...15803, 15805...15805, 15815...15815, 15827...15827, 15838...15838,
            15848...15848, 15850...15850, 15861...15861, 15871...15871, 15873...15873,
            15877...15882, 15892...15916, 15919...15919, 15934...15934, 15942...16374,
            16399...16415, 16417...16433, 16435...16436, 16441...16474, 16476...16481,
            16483...16545, 16860...16880, 16884...16891, 16898...16911, 16913...16919,
            16924...16972, 16987...16988, 16990...17004, 17013...17013, 17024...17024,
            17037...17060, 17073...17073, 17076...17077, 17085...17085, 17089...17090,
            17098...17098, 17109...17109, 17120...17120, 17122...17122, 17132...17132,
            17144...17144, 17155...17155, 17165...17165, 17167...17167, 17178...17178,
            17188...17188, 17190...17190, 17194...17199, 17209...17235, 17238...17238,
            17253...17253, 17261...17703, 17728...17744, 17746...17763, 17765...17767,
            17772...17808, 17810...17815, 17817...17881, 17952...17975, 18002...18721,
        ]
        return Set(ranges.flatMap { $0 })
    }()
}
