# Rally human assets

These are anatomical CC0 MakeHuman graphical assets, converted by the project-owned
`python3 scripts/prepare_avatar_assets.py` converter. See `asset-manifest.json` for
source URLs, hashes, transforms and the coordinate/skinning contract.

Rebuild with verified downloads: `python3 scripts/prepare_avatar_assets.py`.
After that, rebuild without network: `python3 scripts/prepare_avatar_assets.py --offline`.
Use `--source-cache /path/to/cache` to keep raw inputs in a durable location.
The default cache is `/tmp/rally-avatar-source-cache`; it is not an app dependency.

The skin, eyes and hair use real UV maps with V flipped once for direct SceneKit
UIImage sampling. Do not add another material or runtime V flip. Body helpers are separate, never body
geometry. There are exactly two base models: an original adult male (1.78m, 70% muscle,
60% lean-weight interpolation), and an original adult female (1.73m, 65% muscle,
55% lean-weight interpolation). Female geometry uses the adult female identity
and female-specific body targets, not a scale transform of the male. The neutral model must be dressed by
the shared renderer. All meshes
share one full rig and calibrated scale; no independent face or limb primitives
are required. `sourceVertexIndices` refer to the original OBJ for each mesh.

There are six fixed identities, defined in the manifest `players` array: three
male and three female (European, Asian, Black), each with an authored adult face
and source skin atlas. Asian and Black faces apply source target differences
only above a smooth neck transition, not a skin tint. Their authored skull-base
head landmarks are aligned to remove macro stature offsets while retaining local
facial shape differences. Below Y=1.45m (male) or
1.40m (female), the body vertices and skeleton positions remain identical to
the same-sex base, so all garments share one fit per sex. Never rescale each
identity to its slightly different head height.

Use the selected player prefix for athlete/eyes and exact hair/texture names
from the manifest. Construct the rig from that athlete. Clothing uses the same-sex
base prefix: empty for male, `female-` for female. Existing unprefixed assets
remain the European male; `female-` remains the European female.

`shoes.json` and `socks.json` are separated connected components and use
`shoes-diffuse.png` UVs. `shirt.json` is the real tee component from a system
outfit; `polo.json` is Namuhekam's CC0 polo. Short, medium, long and ponytail
hair meshes each use corresponding RGBA texture files; alpha is embedded.
Sneaker soles extend below the barefoot origin; use `shoes.json` bounds to
align the shoe sole to the ground.

The output is a realistic anatomical base, not a scanned person, virtual fit
simulation, or brand-approved garment. Product-specific clothing needs its own
accurate supplied mesh/textures.

CC0 applies to the graphical assets; no MakeHuman application code is embedded.
