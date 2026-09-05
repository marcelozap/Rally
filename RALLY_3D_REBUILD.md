# Shared character and rhythm rally rebuild

September 5, 2026. Requested direction: realistic, lean tennis athletes with a
rhythmic player-selection stance. The final roster is six fixed players: men and
women with White/European, Asian and Black representation. Gameplay combines timed contact, deliberate
flick gestures, and an escalating survival loop.

## Character architecture

- `RallyAvatarRig` is the only production character renderer. Home, Customizer,
  Locker and Shop use the SceneKit view; GameScene embeds the same rig for both
  players with SK3DNode.
- Two detailed athletic bodies, six authored head identities, real UV skin/eyes/hair,
  and 163 shared bones replace the previous disconnected 2D shapes. All three men
  share one garment fit, and all three women share another. Presets keep their
  physique, face and hairstyle fixed; players choose a generic model, optionally
  change skin/hair colors, and equip clothing. Color only affects materials.
- `RallyAthletePreset` is persisted in local storage and included in sync payloads.
  Older saves default to Men Model 1, and older server payloads preserve local selection.
  The selector uses Model 1/2/3 under Men and Women, with six skin and five hair colors.
  Optional color overrides persist and sync without changing garment geometry.
- Clothing has separate tee, polo, shorts/skort, footwear and sock surfaces.
  Color and gear selection remain in `RallyAvatarAppearance`. Product previews
  do not overwrite other equipped slots. These generic meshes illustrate style;
  exact commercial product representation requires supplied garment assets.
- The ready pose uses arm and leg inverse kinematics: knees flex, weight shifts,
  shoes stay planted and the racket follows the hand. Drag rotates the preview;
  pinch inspects clothing details. Reduced Motion keeps a still ready pose.
- The app loads bundled assets without a runtime network dependency. Missing
  required clothing suppresses the figure rather than displaying an undressed
  body. See `Rally/Resources/Avatar3D/asset-manifest.json` for CC0 source licenses,
  pinned hashes and regeneration instructions.

## Gameplay

- Release an upward or diagonal flick on the incoming ball's side as the
  contracting ring reaches its fixed target. Tiny, horizontal and downward
  movements do not count as committed strokes.
- Timing alone determines Perfect/Great/Good. Flick speed cannot promote a late
  release to Perfect. Early/late feedback reflects the actual signed offset.
- Flick direction and lift shape the outgoing trajectory. Alternating returns,
  accelerating combo tiers, bounded score multipliers, three lives and immediate
  retry create the repeatable skill loop.
- Timing grades are independent of avatar size and clothing. Rendered racket
  position supplies visual contact placement. Existing audio opt-in is retained.

## Verification

- Final full iOS simulator XCTest suite: 117 tests passed, zero failures
  (2026-09-05). Includes 11 rig tests, 18 flick/timing tests, preset persistence
  and sync compatibility: source/bone integrity, all six identities, clothing
  visibility/fallback, same-rig switching, slot independence, handedness, planted
  feet, fast-pan origin, aim direction, device scaling and timing boundaries.
- Backend preset-preservation tests: 5 passed. The compatibility change is in
  source only; the backend was not deployed.
- All 34 source meshes pass geometry/skinning validation, and the six-family
  offline converter regenerates byte-identical resources.
- Standard generic iOS Simulator build: passed.
- Build/test logs: `/Users/a14/Documents/ChatGPT/Rally/Proof/`.
- Final focused avatar suite: 11 tests passed after the final scalp/material
  correction, including six exact iOS SCNRenderer snapshots.
- Six-player gallery: `/Users/a14/Documents/ChatGPT/Rally/Proof/roster.html`.
  Stable PNGs: `Proof/roster-renders/roster-{Alex,Kai,Miles,Emma,Maya,Zoe}.png`.
  These are exact 768×1024 iOS renders, not mockups or simulator UI screenshots.
- Visual review confirmed distinct aligned faces, dressed athletic bodies, planted
  shoes and a seated racket grip. Home/chooser entry and restored court compositing
  were checked in the simulator before the Mac locked.
- Final six-player UI selection/rotation and manual scoring interaction remain
  pending because the Mac locked. Unlock was requested. Earlier manual drags
  exposed the fast-pan origin issue; its fix is covered by regression tests,
  but a successful post-fix manual rally was not verified.
- Simulator checks cannot establish real-device haptic quality or sustained
  frame rate. A phone playtest is still needed to judge the final game feel.

## Workspace

Current checkout: `/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally`.
It is the relocated `rally/dev` repository verified against the Rally origin.
The owner authorized this rebuild after locating it in this task. Existing
`agents/handoff.md` and `home_after_launch.textClipping` edits were preserved.

## Generic models and exact clothing intake — September 5 follow-up

- Removed personal model names; skin and hair colors are the only editing controls.
  Legacy creator settings stay inactive. Explicit color choices persist, round-trip
  through sync payloads and leave body, skeleton, hairstyle and garment vertices unchanged.
- Real clothing work now has six exact brand/style/colorway references and a validated
  per-body asset registry. Five verified-price products are surfaced in Shop; the UNIQLO
  polo remains a source reference pending its US price. See `RALLY_CLOTHING_MODELING.md`.
- Shop/Locker photos require an exact product and slot; they never substitute another
  brand or colorway. NB tank photo and product link corrected. Garment details show
  style code, color, composition and construction. Current 3D clothes stay labeled
  style previews until actual SKU geometry and materials are authored.
- Full iOS test pass: 136 tests, zero failures. Final additional bundled-manifest
  test passed in the focused eight-test garment suite (137 distinct tests covered).
  Standard generic iOS Simulator build passed. Backend color-preservation tests:
  seven passed, source change only; backend not deployed.
- New render proof: `Proof/generic-models/` and refreshed `Proof/roster.html` under
  `/Users/a14/Documents/ChatGPT/Rally/`. Before/after color renders were inspected;
  generic roster filenames include model family so labels cannot overwrite each other.
- App installed and launched in the iPhone 16 Pro simulator. Interactive manual
  checks are still pending because the Mac session was locked; the renders above
  come directly from the production rig through iOS SCNRenderer.
