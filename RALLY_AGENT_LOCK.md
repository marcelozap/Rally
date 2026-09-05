# RALLY AGENT LOCK — collision-avoidance protocol

Two agents (Claude Code = `[CC]`, Codex/Cursor = `[CX]`) work this repo in parallel.
On **2026-06-13** both independently diagnosed and started editing the *same* avatar
files at the same time (the "avatar identity" bug). That is the exact failure this
file exists to prevent. Read this file **before touching any file**, every session.

> Governing order: RALLY_NORTH_STAR.md > this file > CLAUDE_CODE_PARALLEL_PLAN.md > RALLY_OVERHAUL_DIRECTIVE.md.
> `AGENTS.md` points here from its mandatory-first-action section.

---

## THE RULE (how collisions are avoided)

A committed claim is the only thing the other agent can see — uncommitted edits are invisible
to them. So locks live in git, not in your head:

1. **Session start — ALWAYS:** `git fetch` / `git pull`, then read the **ACTIVE LOCKS** table below.
2. **Before editing a file:** if it is in **SHARED HOT ZONES** *or* already in ACTIVE LOCKS held by
   the other agent → **STOP. Do not edit it.** Surface it to the user; do not "just take it."
3. **To claim work:** add a row to ACTIVE LOCKS, commit *only* this file with
   `[lock] <agent> claims <area>`, and push **before** you start editing the locked files.
   Now the other agent can see your claim.
4. **To release:** when your change is committed, delete your row (or mark it `RELEASED`) in the
   same commit as the work, or a follow-up `[lock] release` commit.
5. **If you see the other agent already holds a lock you need:** do not wait silently and do not
   work around it. Tell the user, quote the lock row, and let them re-cut the boundary. If the
   owner rules on the dispute, log that ruling under Rally Pro in `agents/rally-pro-coach.md`
   (Owner's Box, final say) so the next session inherits the decision instead of re-asking.

A lock is cooperative — it only works if both agents check it first. That check is non-negotiable.

---

## ACTIVE LOCKS (live — edit this table)

| Since (UTC date) | Agent | Area / files | Status | Notes |
|------------------|-------|--------------|--------|-------|
| 2026-09-05 | [CX] | Mirror Rally prototype + gameplay footwork — shared avatar rig/helpers/tests, GameScene/contact lifecycle, Tunables, GameSessionView/GameOverView and mode labels, project registration and proof/progress | RELEASED | 20-second Mirror Rally, projected near/far contact, grounded travel steps and immediate retry implemented. 176 full tests plus 15 final scene/rig tests passed; generic simulator build passed. Native animation proof saved; live UI/device feel remains pending Mac unlock. Same authorized relocated checkout. |
| 2026-09-05 | [CX] | Generic athlete labels + skin/hair colors; `Rally/Features/Avatar/`, avatar config/sync/tests, Home label, product modeling catalog/resources and source documentation | RELEASED | Completed generic labels/color controls and exact product intake. 136 full + 8 focused garment tests, seven backend tests and generic simulator build passed. Product-specific garment authoring remains next; source brief records exact references. Unowned handoff/textClipping preserved. |
| 2026-09-05 | [CX] | Shared 3D character rebuild — `Rally/Features/Avatar/`, `Rally/Game/` character/timing integration, Home/Shop stages, `Rally/Data/AvatarModels.swift`, athlete preset sync payload/coordinator, model resources, project registration, identity/rig/gameplay tests and progress/proof docs | RELEASED | Owner requested realistic character models for clothing commerce after locating this relocated repo at `Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally`; verified `rally/dev`, origin, and 2a348f5. Preserved existing handoff and textClipping edits. Six fixed athletes, 117 tests passing, exact iOS renders reviewed; final UI/manual playtest awaits Mac unlock. Details in RALLY_3D_REBUILD.md. |
| 2026-07-01 | [CC] | Sync data-loss fix — `Rally/Services/RallySyncCoordinator.swift`, `RALLY_PROGRESS.md` row append | RELEASED | id-based merge landed: update-in-place on matching ids, insert unknown, keep unseen local rows; local-only fields no longer wiped on pull. BUILD NOT RUN (no Xcode in sandbox) — needs local build + sync round-trip test. |
| 2026-07-01 | [CC] | Rafa gameplay feel polish — `Rally/Game/GameScene.swift` (effects/HUD, NOT avatar-assembly block), `Rally/Game/Tunables.swift`, `RALLY_PROGRESS.md` row append | RELEASED | Contact-frame face occlusion fixed: both wall spark systems moved behind playerRoot via named tunables; spark lifts reduced. BUILD NOT RUN in this sandbox (no Xcode) — needs local build + autoplay proof before the T4 item is considered visually closed. |
| 2026-06-27 | [CX] | Avatar anatomy readability — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Game/GameScene.swift` avatar consumption, `RALLY_VISUAL_QA.md` | RELEASED | Build/proof passed after tightening shared eyes/mouth, attaching lower hair crown, adding ear interiors, widening sleeve/shoulder caps, and adding tennis-shoe toe caps. Proof: Home `/tmp/rally_visual_qa/avatar_anatomy_home_061824.png`; gameplay `/tmp/rally_visual_qa/avatar_anatomy_game_061832.png`. |
| 2026-06-27 | [CX] | Rafa contact payoff readability — `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift`, `RALLY_VISUAL_QA.md` | RELEASED | Tuned wall strike burst to bloom beside/behind the player instead of on top of the face; build passed and proof captured in `RALLY_VISUAL_QA.md`. |
| 2026-06-26 | [CX] | Rafa avatar/gameplay credibility — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Game/GameScene.swift` avatar consumption, `RALLY_VISUAL_QA.md` | RELEASED | Build/proof passed after removing gameplay-only head-stack lift so head/hair/ears/features co-anchor to the neck/layout. Proof: `/tmp/rally_visual_qa/head_anchor_gameplay_193707.png`. Remaining: contact glow can still cover face at exact hit frame. |
| 2026-06-22 | [CX] | Avatar gameplay anatomy readability — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Game/GameScene.swift` avatar consumption, `RALLY_VISUAL_QA.md` | RELEASED | Build/proof passed after strengthening gameplay-scale eyes/mouth/ears/neck, reconnecting hair, flattening shoulder caps, slimming tennis shoes, and reducing inward toe rotation. Proof: Home `/tmp/rally_visual_qa/avatar_readability_home_125529.png`; gameplay `/tmp/rally_visual_qa/avatar_readability_game_125538.png`. |
| 2026-06-22 | [CX] | Rafa contact glow readability — `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift`, `RALLY_VISUAL_QA.md` | RELEASED | Build/proof passed after reducing wall spark count/alpha, shifting sparks outward from the avatar silhouette, and making audio lazy so muted launches no longer abort. Proof: Home `/tmp/rally_visual_qa/launch_after_lazy_audio_013154.png`; gameplay `/tmp/rally_visual_qa/autoplay_after_lazy_audio_contact_013559.png`. |
| 2026-06-20 | [CX] | Avatar anatomy credibility — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Game/GameScene.swift` avatar consumption | RELEASED | Released without code changes after owner redirected to workflow/credit optimization. Re-claim before touching avatar hot zones. |
| 2026-06-19 | [CX] | Avatar face/hair/feet readability — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Game/GameScene.swift` avatar consumption | RELEASED | Build/proof passed after reducing oversized gameplay face minimums and lifting the shared hair fringe contract so the face reads less like a black mask while hair stays attached. Proof: Home `/tmp/rally_visual_qa/avatar_home_212313.png`; gameplay `/tmp/rally_visual_qa/avatar_readability_212124.png`. |
| 2026-06-18 | [CX] | Rafa wall-rally no-ball watchdog — `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift` | RELEASED | Build/proof passed after tightening empty-court feed delay/rescue thresholds and forcing expired pending-feed tokens into the rescue path instead of a normal delay. Proof: `/tmp/rally_visual_qa/wall_feed_watchdog_195151.png`. |
| 2026-06-18 | [CX] | Avatar anatomy polish — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Game/GameScene.swift` avatar consumption | RELEASED | Build/proof passed after lowering connected hair fringe, strengthening small-scale eyes/mouth, narrowing tennis shoes, flipping gameplay toe-out away from center, and replacing round gameplay shoulder pads with sloped sleeve panels. Proof: Home `/tmp/rally_visual_qa/avatar_polish_home_161215.png`; gameplay `/tmp/rally_visual_qa/avatar_polish_game_161947.png`. |
| 2026-06-18 | [CX] | Rafa no-ball recovery — `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift` | RELEASED | Build passed after pruning stale invisible wall exchanges before feed scheduling and delayed-spawn occupancy checks, preventing empty-court dead air from stranded exchanges. |
| 2026-06-18 | [CX] | Avatar anatomy pass — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Game/GameScene.swift` avatar consumption | RELEASED | Build/proof passed after slimming gameplay-scale eyes, softening nose/mouth strokes, adding a subtle neck shadow, and replacing round shoulder pads with sloped sleeve panels. Proof: `/tmp/rally_visual_qa/avatar_anatomy_home_093803.png`. |
| 2026-06-18 | [CX] | Rafa wall-rally ball feed reliability — `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift` | RELEASED | Build passed after making the empty-court watchdog clear stale pending spawn tokens in-frame and reset the empty-court timer on spawn, preventing no-ball dead air. |
| 2026-06-18 | [CX] | Avatar anatomy readability — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift` | RELEASED | Build/proof passed after strengthening shared gameplay-scale eyes/mouth/nose, lifting connected hair fringe through the shared contract, enlarging ears, and increasing toe-out. Proof: Home `/tmp/rally_visual_qa/home_avatar_readability_063946.png`; gameplay `/tmp/rally_visual_qa/game_avatar_readability_063957.png`. |
| 2026-06-18 | [CX] | Rafa gameplay POV readability — `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift` | RELEASED | Build/proof passed after lowering and slightly shrinking the gameplay player, moving wall-rally contact farther outside the body, and reducing ball bloom. Proof: `/tmp/rally_visual_qa/autoplay_pov_readability_060748.png`. |
| 2026-06-18 | [CX] | Rafa opening contact timing — `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift` | RELEASED | Build/proof passed: `-RallyAutoPlay` now reaches live scoring contact (`443`, x5) instead of zero-score Game Over by using proof-mode contact timing plus cull-boundary contact conversion. |
| 2026-06-18 | [CX] | Rafa opening rally grace — `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift` | RELEASED | Build/proof passed: first zero-score opening misses no longer spend lives during a short opening grace window, preventing instant Game Over before the feed is legible. |
| 2026-06-18 | [CX] | Rafa wall-rally feed readability — `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift` | RELEASED | Build passed after shortening the post-GO opening wall feed and wiring the existing feed cue so the first balls visibly travel toward the contact pocket. |
| 2026-06-18 | [CX] | Avatar nose readability — `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Game/GameScene.swift` | RELEASED | Build passed after making the shared SwiftUI/GameScene nose stroke visible at iPhone scale without changing avatar identity. |
| 2026-06-18 | [CX] | Rafa camera/avatar readability — `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift`, `Rally/Features/Avatar/RallyAvatarGeometry.swift` | RELEASED | Build passed after larger gameplay avatar scale, stronger gameplay-scale face details, lower shared hair fringe, corrected mouth runtime anchor, and stronger toe-out stance. |
| 2026-06-13 | [CC] | Avatar identity render — `RallyAvatarView.swift`, `RallyAvatarGeometry.swift`, `Rally/Game/GameScene.swift` (head/hair block) | RELEASED | Claude Code session canceled by user; stale hold released so Codex can repair the runtime drift bug. |
| 2026-06-14 | [CX] | Avatar runtime identity repair — `Rally/Game/GameScene.swift` head/hair/face/feet update block | RELEASED | Runtime repair built successfully; re-claim before any further avatar render edits. Visual QA still decides whether another pass is needed. |
| 2026-06-14 | [CX] | Home/Loadout + Shop controls — `Rally/Features/Home/HomeView.swift`, `Rally/Features/Shop/LockerHubView.swift`, `Rally/Features/Shop/ShopView.swift`, `Rally/Features/Shop/ShopItemDetailView.swift` | RELEASED | Checkpoint committed; visual QA still pending. |
| 2026-06-14 | [CX] | Avatar readability pass — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Game/GameScene.swift` | RELEASED | Gameplay camera/readability pass built: stronger POV, larger runtime avatar, exposed ears/features, reduced inward shoe rotation. |
| 2026-06-14 | [CX] | Avatar face/feet readability — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift` | RELEASED | Committed as `3617aee`: gameplay-scale face, softer ears/mouth, outward shoe stance, and stronger court POV. |
| 2026-06-14 | [CX] | Avatar/gameplay readability follow-up — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift` | RELEASED | Build passed after stronger gameplay-scale face, connected hair mass, exposed ears/mouth, wider shoes, toe-out stance, and stronger court POV. Visual QA still decides if another anatomy pass is needed. |
| 2026-06-16 | [CX] | Avatar readability repair — `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Game/GameScene.swift` head/face/feet consumption | RELEASED | Focused gameplay-scale eyes/mouth/ears, connected hair, and foot toe-out consistency pass. xcodebuild generic iOS Simulator Debug BUILD SUCCEEDED. |
| 2026-06-17 | [CX] | Rafa avatar/gameplay readability — `Rally/Game/GameScene.swift`, `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Game/Tunables.swift` | RELEASED | Build passed after lowering connected hair fringe, strengthening gameplay-scale facial features, restoring runtime hand skin tone, and increasing ready/outside foot toe-out. Visual QA still decides if another anatomy pass is needed. |
| 2026-06-17 | [CX] | Rafa wall-rally spawn lifecycle — `Rally/Game/GameScene.swift` | RELEASED | Build passed after clearing stale pending spawn token before spawning the scheduled wall ball, preventing the empty-court watchdog from thinking a feed is still pending forever. |
| 2026-06-17 | [CX] | Loadout try-on persistence drift — `Rally/Features/Avatar/RallyAvatarAppearance.swift` | RELEASED | Build passed after persisted AvatarConfig sync stopped inheriting stale global try-on previews; explicit try-on still uses the preview path. |

---

## SHARED HOT ZONES (always require a lock before editing — no exceptions)

These files are touched by both agents' concerns and have already caused a collision:

- `Rally/Features/Avatar/RallyAvatarView.swift`
- `Rally/Features/Avatar/RallyAvatarGeometry.swift`
- `Rally/Features/Avatar/RallyAvatarAppearance.swift`
- `Rally/Features/Avatar/RallyAvatarPartRenderer.swift`
- `Rally/Game/GameScene.swift` (avatar-assembly block specifically)
- `RALLY_PROGRESS.md` (append-only; never rewrite another agent's rows)

Default lane ownership (when NOT in a hot zone) still follows `AGENTS.md`:
`[CX]` owns Home / Avatar / Shop SwiftUI; `[CC]` owns Game / Journal / Courts / audio-haptics.

---

## STANDING REQUEST — avatar identity contract (kept, do not lose)

The durable agreement behind the current fix, so it is not re-litigated or re-diverged:

- There is **one** composition rule for the head: every head part (head, hair, back-hair,
  highlight, headwear, eyes, brows, nose, ears) is drawn at the **same anchor and the same
  scale** in *both* renderers. The part geometry already encodes the correct relative offsets;
  any per-part Y nudge or scale split re-opens the "disconnected hair / black-over-face /
  different-person-after-PLAY" bug.
- The only intentional vertical offset is the front-fringe clearance, and it is a **single
  shared constant**: `RallyAvatarGeometry.hairFringeLift(scale:)`. Both `RallyAvatarView` and
  `GameScene` call it. Tune the avatar by changing that one number — never by hardcoding a new
  offset in one renderer.
- If a future change needs a head offset, add it to `RallyAvatarGeometry` as a shared value both
  renderers read. Do **not** introduce a literal like `headY + 4.6*scale` in a single renderer.

---

## INCIDENT LOG

- **2026-06-13** — Double-diagnosis collision. `[CC]` fixed the avatar identity (co-anchor +
  shared `hairFringeLift`) and verified Home on-device; in parallel `[CX]`, handed a collaboration
  prompt, began implementing the same fix (its own `AvatarHeadComposition`) in the same files.
  No data lost (caught before `[CX]` wrote to the tree). This file created in response.
