# Avatar & Court Visual Overhaul Plan

**Status:** Planning document only — do not implement in this pass.  
**Target aesthetic:** Anime-inspired, stylized-premium 3D (NOT photoreal, NOT blocky placeholder art).  
**Brand north star:** XIV / premium mobile sports — clean silhouettes, confident materials, “perfect enough to model.”  
**Athletic reference:** Jannik Sinner–tier lean athletic build, interpreted through anime stylization (elongated proportions, sharp jaw, expressive eyes, dynamic pose language).

---

## 1. Goals & Non-Goals

### Goals
- Replace placeholder SF Symbol / primitive mesh avatar with a **single hero rig** that reads as a premium tennis athlete at locker scale and in marketing screenshots.
- Make **court surfaces feel alive** (Wimbledon grass shimmer, clay dust, hard-court specular) without distracting from gameplay readability.
- Treat **racket, apparel, and shoes as brand marketing surfaces** — Wilson, Nike, etc. must be recognizable at thumbnail size; partners should want their SKUs in-frame.
- Preserve and extend the existing **Locker → Shop → Equip → Play** loop (`AvatarConfig`, `ShopCatalog`, `GameEventBus`).
- Ship incrementally: each phase is shippable behind a feature flag.

### Non-Goals (this overhaul)
- Photoreal skin, scanned textures, or MetaHuman fidelity.
- Full open-world court navigation or third-person gameplay camera.
- Replacing SpriteKit core loop (`GameScene`) — gameplay stays 2.5D; avatar upgrade is parallel (Locker + optional court-side hero).
- Inventing unauthorized promo codes or fake trademarked logos in code — use approved partner asset packs or abstract stand-ins until legal clears.

---

## 2. Current State Audit (Phase 0)

### What exists today

| Area | Location | Notes |
|------|----------|-------|
| Avatar data | `Rally/Data/AvatarModels.swift` | SwiftData `AvatarConfig`: skin, hair, body type, equipped slot IDs |
| Shop catalog | `Rally/Data/ShopCatalog.swift` | Static SKUs with brand, colors, vendor URLs, categories |
| Locker UI | `Rally/Features/Shop/LockerHubView.swift` | Shop rows, equip flow, Play CTA |
| 2D fallback avatar | `Rally/Features/Avatar/AvatarView.swift` | Shapes + SF Symbols — zero authored art |
| 3D shop stage | `Rally/Features/Avatar/AvatarRealityKitView.swift` | Procedural RealityKit figure + optional `AvatarHero.usdz` |
| Visual spec bridge | `Rally/Features/Avatar/Avatar3DModels.swift` | `AvatarVisualSpec.from(config:preview:)` maps equipped items → UIColor tints |
| Gameplay court | `Rally/Game/TennisCourtBackdrop.swift`, `CourtSurface.swift` | 2D faux-3D backdrop, surface-tuned ball physics |
| Game racket (2D) | `Rally/Game/GameScene.swift` | SpriteKit strike visual only |
| Sync | `Rally/Services/RallySyncCoordinator.swift` | Avatar payload round-trip |

### Phase 0 checklist (execute before mesh work)
- [ ] Inventory all avatar entry points: Locker, Customizer, Shop detail, any onboarding.
- [ ] Capture screenshot baseline (2D + RealityKit procedural) for before/after.
- [ ] Confirm iOS deployment target (17+) and device matrix (iPhone 12+, iPad optional).
- [ ] Legal: list partner brands in `ShopCatalog` requiring approved 3D assets vs color-only placeholders.
- [ ] Measure RealityKit load time for current shop stage (target: < 400 ms warm, < 1.2 s cold).
- [ ] Document equipped slot → material slot mapping gaps (e.g., bags/accessories not rendered in 3D).
- [ ] Decide feature flag key: `rally.avatarOverhaulEnabled` in `UserDefaults` or remote config.

---

## 3. Art Direction

### Visual language
- **Silhouette first:** readable racket head, shoulders, and shoe sole at 64 pt thumbnail.
- **Anime tier, not chibi:** ~7–7.5 heads tall; subtle Sinner athletic shoulders; stylized hair masses, not individual strands.
- **Materials:** PBR with restrained roughness; rim light + soft fill; no noisy micro-detail.
- **Color:** shop `colorHex` / `accentHex` drive material tints; brand logos as separate decal planes where licensed.
- **Emotes:** keep `AvatarShopEmote` set (idle, shop look, celebrate) — rig must support upper-body overlay.

### Court VFX language
- Grass: slow parallax blade shimmer + line chalk puff on perfect hits.
- Clay: burnt-orange dust puff on bounce, slide streak on hard lateral hits.
- Hard: subtle specular sweep on baseline, electric cyan accent aligned with Rally UI.

### Brand placement rules
- Racket: head shape family per vendor SKU (Wilson Blade vs Pro Staff silhouette).
- Apparel: logo zone on chest/sleeve; never stretch UVs across seams.
- Shoes: outsole color + side swoosh/stripe as separate mesh/decal.

---

## 4. Technical Approach Options

### Option A — RealityKit hero (recommended)
**Pros:** Already integrated (`AvatarRealityKitView`); non-AR `ARView`; IBL + PBR; good SwiftUI bridge.  
**Cons:** Custom rig animation is manual; USDZ pipeline discipline required.

**Implementation sketch:**
- Author `AvatarHero.usdz` with skeleton + blend shapes (optional).
- Runtime: load USDZ, bind materials via `AvatarVisualSpec` → `SimpleMaterial` / `PhysicallyBasedMaterial`.
- Outfit slots: child entities tagged `slot_top`, `slot_bottom`, `slot_shoes`, `slot_racket` — swap meshes or tint parent.
- Keep procedural fallback entity tree for devices that fail USDZ load.

### Option B — SceneKit legacy path
**Pros:** Mature tooling, easier timeline animation.  
**Cons:** Duplicate backend alongside RealityKit; Apple pushes RealityKit for new work.

Use only if a required plugin exports SCN exclusively; otherwise avoid dual backends.

### Option C — Pre-rendered 2.5D sprite sheets
**Pros:** Cheapest GPU cost.  
**Cons:** Fails “premium 3D locker” goal; bad for brand SKU rotation.

**Decision:** **Option A** primary; delete SceneKit path if unused after audit.

### Asset pipeline
1. **DCC:** Blender (rig) → glTF export → Reality Converter / Xcode USDZ.
2. **Naming:** `Rally/Resources/Avatar/Hero/AvatarHero.usdz`, `Outfits/{skuId}.usdz` optional per-SKU mesh overrides.
3. **Textures:** 1K baseline, 2K hero close-up; ASTC in asset catalog.
4. **Versioning:** append `_v2` suffix in bundle; migrate via catalog `meshRevision` field if needed.

### Rigging requirements
- Humanoid: spine, clavicle, upper arm, forearm, hand, neck, head.
- Prop bone: `racket_attach` (right hand).
- Optional: hair as skewed child mesh per `AvatarHairStyle`.
- Body scale: drive uniform scale from `AvatarBodyType` (0.94 / 1.0 / 1.08) — same as today.

### Material / outfit slot binding

```
AvatarConfig.equippedTopID    → slot_top    (mesh swap OR tint)
AvatarConfig.equippedBottomID → slot_bottom
AvatarConfig.equippedShoesID  → slot_shoes
AvatarConfig.equippedRacketID → slot_racket (mesh + strings color)
AvatarConfig.skinTone         → skin shader
AvatarConfig.hairStyle/Color  → hair mesh visibility + tint
```

Extend `ShopItem` (optional fields, backward compatible):
- `meshAssetName: String?`
- `decalTextureName: String?`
- `brandMarkZone: String?` (enum: chest, sleeve, racketHead, …)

---

## 5. Phased Roadmap

### Phase 1 — Hero avatar mesh & rig
**Outcome:** Locker shows authored USDZ athlete replacing procedural primitives.

Checklist:
- [ ] Model + rig hero in Blender; export USDZ with named slot entities.
- [ ] Load path in `AvatarRealityKitView.Coordinator.tryLoadBundledHero()` — harden error handling + metrics.
- [ ] Map `AvatarVisualSpec` colors to PBR parameters (skin SSS fake via subsurface tint, not true SSS).
- [ ] Hair variants: mesh swap table keyed by `AvatarHairStyle`.
- [ ] Body types: uniform scale + slight shoulder width tweak per type.
- [ ] Feature flag: procedural fallback when USDZ missing.
- [ ] Unit smoke test: spec from default `AvatarConfig` does not crash representable update.

**Files touched (expected):**
- `Rally/Features/Avatar/AvatarRealityKitView.swift`
- `Rally/Features/Avatar/Avatar3DModels.swift`
- `Rally/Resources/Avatar/**`
- `Rally/Data/ShopCatalog.swift` (optional mesh metadata)

### Phase 2 — Materials, outfits & brand-readable SKUs
**Outcome:** Equipping shop items visibly changes outfit; racket/shoe silhouettes recognizable.

Checklist:
- [ ] Per-category material libraries (fabric, rubber sole, graphite racket).
- [ ] SKU-specific mesh overrides for top-tier partner items (start with 1 Nike top, 1 Wilson racket, 1 shoe).
- [ ] Decal system for licensed logos (texture atlas per vendor).
- [ ] `ShopItemDetailView` try-on updates RealityKit in real time (already partially wired via `preview`).
- [ ] Publish `.cosmeticEquipped` → optional in-game racket tint sync (gameplay SK racket reads equipped ID).
- [ ] Accessibility: VoiceOver reads equipped brand + item name.

**Keep from current flow:**
- `AvatarCustomizerView` skin/hair/body controls.
- `LockerHubView` equip toggles writing to SwiftData.
- `GameEventBus` `.cosmeticEquipped` for future gameplay cosmetics.

### Phase 3 — Court surface VFX & atmosphere
**Outcome:** Courts feel distinct during play and in Locker backdrop extensions.

Checklist:
- [ ] Upgrade `TennisCourtBackdrop` with animated SKShader / SKTile layers (grass wave, clay grain scroll).
- [ ] Surface-specific particle presets in `ParticleManager` (clay dust, grass clip).
- [ ] Tie perfect-hit juice to surface palette (already partially in `courtBackdrop?.pulseHorizon`).
- [ ] Optional: subtle parallax crowd plane (stylized anime silhouettes, low alpha).
- [ ] Performance budget: ≤ 2 ms GPU on iPhone 13 for backdrop + particles.

**Files touched (expected):**
- `Rally/Game/TennisCourtBackdrop.swift`
- `Rally/Game/GameScene.swift` (hook points only)
- `Rally/Game/ParticleManager.swift`
- `Rally/Game/CourtSurface.swift` (VFX tuning structs)

### Phase 4 — Brand SKU integration & marketing surfaces
**Outcome:** Partners can approve in-app renders; shop links map to real products.

Checklist:
- [ ] Asset approval workflow doc for vendors (PNG ortho + USDZ delivery spec).
- [ ] `ShopCatalog` entries reference `meshAssetName` / decal keys.
- [ ] Locker “Share look” export (UIImage from RealityKit snapshot) — marketing hook.
- [ ] Analytics events: equip SKU, snapshot share, vendor link tap (privacy-safe).
- [ ] Fallback: color-only tint when SKU mesh absent — never crash.

---

## 6. Module & File Map (post-overhaul target)

```
Rally/
  Data/
    AvatarModels.swift          # keep — source of truth for equip IDs
    ShopCatalog.swift           # extend with optional mesh/decal fields
  Features/
    Avatar/
      AvatarRealityKitView.swift    # primary renderer
      Avatar3DModels.swift          # spec + material builders
      AvatarView.swift              # demote to Settings/low-power fallback
      AvatarCustomizerView.swift    # keep
    Shop/
      LockerHubView.swift           # keep layout; swap stage content
      AvatarShopStageView.swift     # choose RealityKit vs fallback
  Game/
    GameScene.swift                 # 2D racket stays; optional tint from equip
    TennisCourtBackdrop.swift       # Phase 3 VFX
  Resources/
    Avatar/
      Hero/AvatarHero.usdz
      Outfits/
      Decals/
      IBL/neutral.hdr
```

---

## 7. iOS 17 Constraints & Performance

- **Minimum:** iOS 17 (`@Observable`, SwiftData assumptions in repo).
- **RealityKit:** non-AR `ARView` is supported; avoid AR session entitlement.
- **Memory:** hero USDZ + 4 outfit meshes ≤ 25 MB compressed in bundle tier 1.
- **Thermal:** cap shop stage to 30 fps on A14; full 60 fps during emote burst only.
- **SwiftData:** no blob storage for meshes — bundle assets only; config stores IDs.
- **Accessibility:** Reduce Motion → disable hair sway + court shimmer shaders.

---

## 8. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Partner logo legal | App Store rejection | Separate licensed decal pack; legal sign-off gate Phase 4 |
| USDZ load failure on older devices | Blank locker | Procedural fallback + telemetry |
| Dual 2D/3D maintenance | Drift | Single `AvatarVisualSpec`; deprecate `AvatarView` after flag on |
| Gameplay vs locker visual mismatch | Brand distrust | Sync racket tint + optional handle color in `GameScene` from equip ID |
| Asset size bloat | Download churn | On-demand resources for outfit meshes; hero in base bundle |
| Rigging timeline | Blocks Phase 2 | Phase 1 ships with tint-only outfits on hero mesh |

---

## 9. What to Keep (do not rewrite)

- `AvatarConfig` SwiftData model and equip ID fields.
- `ShopCatalog` vendor structure and external product URLs.
- Locker shop UX: category filter, vendor grouping, Play CTA.
- `GameEventBus` events (`cosmeticEquipped`, session lifecycle).
- `CourtVenue` surface physics tuning (gameplay feel separate from visuals).
- Audio/haptics pipelines — unrelated to avatar art.

---

## 10. Milestone Checklist (scope, not dates)

- [ ] **M0:** Phase 0 audit doc + feature flag landed.
- [ ] **M1:** `AvatarHero.usdz` loads in Locker; idle emote; fallback tested.
- [ ] **M2:** All four equip slots tint/swap on hero; Customizer updates live.
- [ ] **M3:** At least 3 partner SKUs with distinct silhouettes approved.
- [ ] **M4:** Court VFX per `CourtVenue` surface in gameplay backdrop.
- [ ] **M5:** Game racket reads equipped SKU accent color.
- [ ] **M6:** Share snapshot + vendor analytics hooks behind flag.
- [ ] **M7:** Remove procedural RealityKit body (optional cleanup) once crash-free ≥ 99.5% sessions.

---

## 11. Suggested Agent Execution Order

1. Run Phase 0 audit commands; add feature flag scaffolding (no art).
2. Import placeholder `AvatarHero.usdz` (greybox) to validate pipeline.
3. Implement slot entity tagging + material binding in `AvatarRealityKitView`.
4. Author final hero mesh externally; drop into `Resources/Avatar/Hero/`.
5. Extend `ShopCatalog` with mesh metadata; wire 3 hero SKUs.
6. Phase 3 court shaders in isolation (`TennisCourtBackdrop` unit snapshots).
7. GameScene racket tint hook + QA pass on all `CourtVenue` cases.
8. Marketing snapshot export + documentation for partner asset delivery.

---

## 12. Acceptance Criteria (definition of done)

- Locker avatar reads as **premium stylized 3D** at arm’s length on iPhone 15 Pro Max and iPhone SE class devices.
- Equipping a shop item changes the avatar within **one frame of SwiftUI update** (≤ 16 ms perceived).
- Partner racket SKU recognizable vs generic racket at 200 pt render width.
- Gameplay remains SpriteKit-first; frame time regression **< 5%** with Phase 3 VFX enabled.
- No regression to shop purchase/equip persistence or Rally sync payloads.

---

*Document owner: Rally iOS team. Execute phases in order; do not skip Phase 0 legal/perf audit.*
