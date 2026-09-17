# Tee skin occlusion

Reviewed 2026-09-17 against the male European and female Black backhand proof renders.

The apparent shoulder tears are intersections between the body and its separate tee mesh. Both tee assets are continuous after welding equal-position UV seams: their only four boundary loops are the neck, lower hem and two cuffs, and duplicated seam vertices have identical bone weights. The converter fits a coarse garment to the body and derives garment skin weights from the MHCLO references; this does not guarantee clearance through an articulated stroke.

The upstream `male_casualsuit04.mhclo` contains an explicit `delete_verts` section for covered skin. `scripts/prepare_avatar_assets.py` currently stops parsing at that section and does not export its mask. The runtime previously retained all skin above the socks, including the covered shoulders and torso.

`RallyHumanMesh.hidingTeeCoveredSkin(sourceVertexIndices:aboveHem:)` applies the exact authored source-vertex ranges. It removes a triangle only when all three original body vertex IDs are covered and all three bind positions are above the supplied final tee hem. The height condition is required because this source outfit also contains jeans. Source IDs correspond to `sourceVertexIndices` already stored in each athlete JSON, including the duplicated UV vertices and all six identities. Geometry, skin weights, normals and visible body regions remain unchanged.

Call only for the authored default tee, when rebuilding the wardrobe. Do not apply this mask to tanks, polos, fallback helper garments or product-specific meshes. The separately verified polo MHCLO has no authored `delete_verts` section. No polo mask was inferred from the tee.

Source: [MakeHuman CC0 system asset archive](https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip), member `clothes/male_casualsuit04/male_casualsuit04.mhclo`. SHA-256: `8c1a2d3272cd51ba03f0840d593eddc6325d3d2c4c8529f8203d2c2cad3d0cef`. The source matches the existing asset manifest. Its compressed ZIP member starts at byte 107013531 and has 42767 compressed bytes; the local ZIP header supplies the filename/extra-field lengths before raw DEFLATE extraction. Expand the integers and inclusive `a - b` ranges following `delete_verts`; the helper stores the same 130 ranges. No full asset rebuild or appearance conversion is required.

Static check: using hem Y 0.990 m for male and 0.915 m for female removes 2732 and 2817 fully covered body triangles respectively. Those counts are diagnostic examples; runtime uses the actual selected tee hem, not these constants. A conservative shoulder clearance adjustment and actual rendered stroke review are still needed: this mask addresses skin breakthrough, not arm anatomy or garment deformation quality.
