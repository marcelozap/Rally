# RALLY PROGRESS LEDGER

This file is the single backlog and session log for the Rally repo.
Execute tasks top-down. Update status after every commit.
Governing priority: RALLY_NORTH_STAR.md > CLAUDE_CODE_PARALLEL_PLAN.md > RALLY_OVERHAUL_DIRECTIVE.md.

---

## SESSION LOG

| Date       | Commit     | Lane | Work                              | Notes                                           |
|------------|------------|------|-----------------------------------|-------------------------------------------------|
| 2026-07-12 | (verify)   | [CX] | BUILD VERIFY — sync data-loss fix | xcodebuild generic iOS Simulator Debug **BUILD SUCCEEDED** at `f502a1f`; no code changes. Confirms the `[CC]` id-based merge fix compiles before pushing the two local commits, while preserving dirty `agents/handoff.md` and untracked `home_after_launch.textClipping`. |
| 2026-07-04 | (verify)   | [CX] | BUILD VERIFY — real-phone install baseline | xcodebuild generic iOS Simulator Debug **BUILD SUCCEEDED** at `e1228d1`; no code changes. Confirms the install -> test -> results docs are sitting on a compiling `rally/dev` tree while preserving the existing dirty `agents/handoff.md`. |
| 2026-07-04 | (docs)     | [CX] | Real phone install guide          | Added `RALLY_REAL_PHONE_INSTALL.md` and routed current-priority/village docs to the install -> test -> results flow. Docs-only; build not required. |
| 2026-07-04 | 12a24f3    | [CX] | BUILD VERIFY — current rally/dev  | xcodebuild generic iOS Simulator Debug **BUILD SUCCEEDED** at `2bc4dcb`; no code changes. Confirms the real-phone checklist starts from a compiling tree while preserving the existing dirty `agents/handoff.md`. |
| 2026-07-03 | 2bc4dcb    | [CX] | Real phone test checklist         | Added `RALLY_REAL_PHONE_TEST.md` for the next device run: launch quiet defaults, avatar identity, outfit slot isolation, gameplay feed, tennis feel, audio toggle, Shop/Journal/World, final 1-10 scores, and top-three bug capture. Docs-only; build not required. |
| 2026-07-02 | (verify)   | [CX] | VERIFY — Fable wall spark face-occlusion fix | Verified commit `339d4e2`: xcodebuild generic iOS Simulator Debug **BUILD SUCCEEDED**; autoplay proof screenshots recorded in `RALLY_VISUAL_QA.md` at `/tmp/rally_visual_qa/fable_sparks_fix_0812_10s.png` and `/tmp/rally_visual_qa/fable_sparks_fix_0812_22s.png`. |
| 2026-07-01 | (pending)  | [CC] | Sync data-loss fix: id-based merge | `RallySyncCoordinator.apply()` no longer deletes all TrainingSession/MatchEntry/JournalEntry rows on pull. Matching ids update in place (payload fields only), unknown ids insert, local rows the server hasn't seen are kept for the next push. Also stops wiping local-only fields (`photoData`, journal `sourceRaw`/rally metrics/`courtName`/`gearCSV`) on every pull. Known trade-off documented in code: server-side deletions don't propagate until the API grows tombstones. Owner approved BUILD NOT RUN risk in chat; needs local xcodebuild + a pull/push round-trip test. |
| 2026-07-01 | (pending)  | [CC] | Wall contact sparks behind player | Closes the 2026-06-26 open item "contact glow can still cover face at exact hit frame": both wall spark systems (streak sparks in `stageWallStrikeBurst`, directional sparks in `stageWallDirectionalContactSparks`) moved from hardcoded zPosition 65/65.5 (in front of player, z=14) to behind `playerRoot` via new named tunables `wallContactSparkBehindPlayerZOffset`/`wallDirectionalSparkBehindPlayerZOffset`, matching the existing ring/flash `wallContactBurstBehindPlayerZOffset` treatment. Hardcoded +18 streak lift → `wallContactSparkLift` 8; `wallDirectionalSparkLift` 16→7 so sparks drift outward, not up across the head. BUILD NOT RUN — no Xcode in this sandbox; needs local xcodebuild + autoplay proof frame at contact. |
| 2026-07-01 | (pending)  | [CX] | Rafa follow-through finish readability | Lowered forehand/backhand follow-through endpoints in `Tunables.swift` so the racket finish clears the avatar face better at phone scale; xcodebuild generic iOS Simulator Debug BUILD SUCCEEDED; autoplay proof screenshots recorded in `RALLY_VISUAL_QA.md` at `/tmp/rally_visual_qa/follow_finish_lower_0112_10s.png` and `/tmp/rally_visual_qa/follow_finish_lower_0112_22s.png`. |
| 2026-06-29 | 129a120    | [CX] | Rafa contact pocket visual proof | Widened/lowered wall-rally contact pocket; xcodebuild generic iOS Simulator Debug BUILD SUCCEEDED; autoplay proof screenshots recorded in `RALLY_VISUAL_QA.md` at `/tmp/rally_visual_qa/contact_pocket_widen_1402_10s.png` and `/tmp/rally_visual_qa/contact_pocket_widen_1402_22s.png`. |
| 2026-06-16 | (pending)  | [CX] | Avatar readability: face, hair, ears, feet | Gameplay-scale face features strengthened in shared geometry and both renderers: larger eyes/brows/mouth minimums, more visible nose/mouth strokes, ears exposed, connected fringe lowered, and ready/outside foot toe-out increased. xcodebuild generic iOS Simulator Debug BUILD SUCCEEDED. |
| 2026-06-16 | (pending)  | [CC] | RallyTab rename + wall-rally test coverage | `RallyTab.journal` → `.world` (ContentView.swift) to match the actual "World" tab label/icon (Courts map) — was naming debt from T7 golden-file routing, confirmed single-file blast radius via grep before renaming. Added `RallyTests/WallRallyEscalationTests.swift`: full coverage of `Tunables.wallSpeedTier`/`wallSpeedScalar`/`wallTimingScalar` (tier boundaries, monotonic taper, openingBoost confined to tier 0 only). Surveyed `RallySyncCoordinator`/`RallySyncTriggers`/`RemoteTunables`/`RallyAPIClient` for live-ops risk — found one real bug (see BLOCKED/NOTES), did not touch it. Files: `Rally/App/ContentView.swift`, `RallyTests/WallRallyEscalationTests.swift` (new), `RALLY_PROGRESS.md`. BUILD NOT RUN, TESTS NOT RUN — no Xcode/simulator in this sandbox. |
| 2026-06-16 | d355b86    | [CX] | Timing taper + multiplier banners  | wallTimingScalar tapers with combo tier (1.78→1.62→1.44→1.26→1.10→0.96) matching speed ramp so tier-5 is genuinely harder. wallStreakLabel punched on each hit (comboLabel hidden in wall mode). ×2/×3 multiplier-bump banners (gold→platinum) when combo/5 steps up and no speed-tier fires same hit. xcodebuild generic iOS Simulator Debug BUILD SUCCEEDED. |
| 2026-06-16 | 0460ecc    | [coach] | Rally Pro / Owner's Box added | New president / old-head tennis coach persona representing the real repo owner with final-say authority above [CC] and [CX]. Not autonomous: cannot be invoked by agents on their own initiative, does not write code, does not hold a lane, and only formalizes rulings the owner actually states in chat. |
| 2026-06-16 | b3ed88a    | [CX] | Real Claude Code hooks for protocol | .claude/settings.json + .claude/hooks/{guard-edit,guard-bash,session-start}.sh. Mechanizes canonical-path and destructive-command guards for native Claude Code sessions; CX still follows markdown protocol directly. |
| 2026-06-16 | (verify)   | [CX] | BUILD VERIFY — whole tree         | xcodebuild generic iOS Simulator, Debug: **BUILD SUCCEEDED** after Rally Pro docs and d355b86 gameplay timing/multiplier pass. |
| 2026-06-15 | 5a72640    | [CX] | Flappy-Bird speed ramp + combo HUD | 5-tier speed escalation (combo 5/12/22/35/55 → 0.92/0.81/0.71/0.61/0.52× travel). Streak counter left-of-score. Personal-best combo persisted in UserDefaults; "★ NEW BEST!" banner on break. Speed-tier banners wired. Verified by 2026-06-16 build. |
| 2026-06-15 | e5e7898    | [CC] | Survival loop: lives + fail + ramp | Wall rally now a Flappy-style run: 3 lives, each miss costs one, 0 lives → failRun() fires existing sessionEnd→GameOver→Play Again. Endless wall-rally mode keeps running until fail. Lives pips HUD under score. Verified by 2026-06-16 build. |
| 2026-06-15 | 85e3582    | [CC] | Ball shadow lerp + strict FH/BH   | Shadow xScale 0.30–0.90 lerp with depth+altitude; maxSameLaneRun 2→1 forces strict alternation. BUILD NOT RUN |
| 2026-06-15 | 49d8a4e    | [CC] | Courts tier 2 unlocks             | Ashe/Laver/IndianWells wristband rewards in ShopCatalog; reward badge UI in CourtsMapView. BUILD NOT RUN |
| 2026-06-15 | f994b40    | [CC] | Journal CTA in exit confirmation  | Exit button → confirmationDialog; "Log how it felt" opens journal then exits; exitAfterLog flag. BUILD NOT RUN |
| 2026-06-15 | 2cf056a    | [CC] | T4: combo-scaled recovery window  | registerComboBreak scales 1–2× with previousCombo; GameScene passes combo; new MatchFlowTests case. |
| 2026-06-13 | (verify)   | [CC] | BUILD VERIFY — whole tree         | xcodebuild iPhone 16 Pro sim, Debug: **BUILD SUCCEEDED**. Clears all BUILD NOT RUN flags (b979f01–c3a664d Journal, aac00cc T4, 5c122a8 shop). |
| 2026-06-13 | aac00cc    | [CC] | T4: contact payoff + miss clarity | Perfect banners live (combo ≤3, every 5th); miss popup red/amber; wallMissCue coaching text |
| 2026-06-13 | 329c0ff    | [CX] | Avatar creator hand/hair controls | Lefty/Righty made explicit; stale bald configs reset; accidental bald removed from picker; hair lowered |
| 2026-06-13 | 662b4f5    | [CX] | Avatar hair/face/stance polish    | Hair lowered/tightened, eyes reduced, shoulders/neck stronger, SwiftUI shoe mirroring fixed |
| 2026-06-13 | 2649794    | [CC] | Courts label fix                  | "Open official camp/destination" → "View details →" |
| 2026-06-13 | c3a664d    | [CC] | Journal: venue + gear worn in session | courtName, gearCSV on JournalEntry; auto-logger reads CourtVenue + appearance store |
| 2026-06-13 | a5cb5b4    | [CC] | Journal: narrativeHeadline + matchStoryHighlights in body | canonical game engine narrative in auto-log |
| 2026-06-13 | 88b622a    | [CC] | Journal T2+: structured rally metrics | rallyScore/rallyMaxCombo/rallyAccuracyPct on model; JournalInsights week aggregates |
| 2026-06-13 | b979f01    | [CC] | Journal T2: auto-log source protocol | JournalEntrySources.swift, JournalAutoLogger, wired into GameSessionView. BUILD NOT RUN |
| 2026-06-12 | 5c122a8    | [CC] | Shop/avatar sync fixes (CX override) | equip() → appearanceStore.sync (A-4/S-4); ShopView cards render catalog imagery (S-3). BUILD NOT RUN |
| 2026-06-12 | 11f8eba    | [CC] | T4: rally-loop depth + return urgency | Outbound depth shrink 0.58, return accel 2.9×, speed tail. BUILD NOT RUN — verify locally |
| 2026-06-11 | dd3d701    | sync | Avatar overhaul + pro body mech   | torso uncoil 5.2×, sleeve gaps, scale 1.14      |
| 2026-06-11 | 39fb976    | [CC] | Gameplay player credibility pass  | Trail shoe mirror (xFlip), hair scale 0.82/0.92 |
| 2026-06-11 | 21e75ba    | [CC] | World marketplace                 | 20th listing, DEBUG router, category cards      |

Credibility pass (39fb976) is partial progress toward **T4 Gameplay feel** and **T5 Avatar polish**.
Note: shoe/hair edits modify avatar drawing inside GameScene.swift — per North Star law 1, avatar
drawing belongs in RallyAvatarGeometry. Flagged as tech debt: "avatar decoration code in GameScene
pending geometry consolidation." Treat ALL avatar visual code as CX territory unless ledger says
takeover=YES.

---

## BACKLOG

### T1 — World marketplace (Courts/Atlas screen)  ← DONE (21e75ba; Courts/World reverts to CX lane)
**Lane:** [CC] override (CX owns Courts normally; user promoted to CC for this task)
**Spec source:** RALLY_OVERHAUL_DIRECTIVE.md Workstream C

- [x] 1a Venue listing model — `IconicTennisCourt` covers all required fields
- [x] 1b 20-listing seed catalog with real URLs — 20 listings (21e75ba)
- [x] 1c Link repair via RallyReferralLinkRouter — DEBUG logging; zero nil-URL controls (21e75ba)
- [x] 1d Safe area — .safeAreaInset(edge: .top) confirmed; category chips functional (21e75ba)
- [x] 1e Per-category storefront cards (venues=cyan, camps=gold) + disclosure line (21e75ba)

Accept criteria (W-series audit gates from RALLY_OVERHAUL_DIRECTIVE.md §5):
- W-1: No element occluded by Dynamic Island on iPhone 16 Pro
- W-2: Every venue has non-nil venueWebsiteURL and bookingOrMembershipURL
- W-3: Every link-shaped control routes through RallyReferralLinkRouter or does not render
- W-4: Referral code injection applies to World links identically to Shop links

Commit: `[CC] World marketplace: listings, live referral links, declutter, safe area`

---

### T2 — Journal (training history surface)
**Lane:** [CX]
**Spec source:** RALLY_NORTH_STAR.md §Journal

- [x] auto-log rally sessions — JournalAutoLogger wired into GameSessionView (b979f01)
- [x] Garmin-ready source protocol — JournalEntrySources.swift: JournalEntrySource protocol,
      RallySessionJournalSource, GarminJournalSource stub (b979f01)
- [x] JournalEntry.sourceRaw / sourceKind — provenance persisted on model (b979f01)
- [x] Structured rally metrics — rallyScore, rallyMaxCombo, rallyAccuracyPct on model (88b622a)
- [x] JournalInsights: this-week rally aggregates (sessions, bestScore, bestCombo, avgAcc) (88b622a)
- [x] Richer auto-log body: segment breakdown (Early/Mid/Late), narrativeHeadline,
      matchStoryHighlights (clean returns, changeup winners, pressure holds) (a5cb5b4/6766cfe)
- [x] venue/court association — courtName persisted on JournalEntry; reads CourtVenue.current (c3a664d)
- [x] gear worn in session — gearCSV from equipped appearance slots via RallyReferralCatalog (c3a664d)
- [ ] calendar-style weekly/monthly history (CX surface work)
- [ ] manual training notes UI (CX surface work)
- [x] VERIFY: b979f01–c3a664d compile — xcodebuild sim Debug BUILD SUCCEEDED (2026-06-13)

---

### T3 — Home/Loadout craft (premium pregame surface)
**Lane:** [CX]
**Spec source:** RALLY_NORTH_STAR.md §Home And Loadout

---

### T4 — Gameplay feel (camera/physics/contact)  ← ACTIVE
**Lane:** [CC]
**Spec source:** RALLY_NORTH_STAR.md §Gameplay Feel Contract

- [x] readable depth: outbound leg (racket→wall) now shrinks to wallExchangeDepthFarScale
      (was full-size to the wall); reentry inherits far handoff scale and grows back (2026-06-12)
- [x] return acceleration urgency: exit 0.70 / gain 0.65 (~2.9× terminal vs exit speed,
      was ~1.19×); return travel 0.62→0.56 s; speed-driven tail alpha/length (2026-06-12)
- [x] contact payoff: perfect banners now live (combo ≤3 + every 5th); stroke-aware label text (aac00cc)
- [x] miss clarity: popup red/amber by reason; wallMissCue coaching text filled in (aac00cc)
- [x] VERIFY (compile): xcodebuild sim Debug BUILD SUCCEEDED for all 2026-06-12/13 [CC] changes (2026-06-13)
- [x] VERIFY (visual): boot sim, play a rally, screenshot — confirm depth shrink at wall,
      return urgency, colored miss popups, perfect banners read on screen (North Star Law 10)
- [x] follow-through readability: forehand/backhand finish endpoints lowered so the racket
      clears the avatar face better in autoplay proof frames (2026-07-01)
- [x] contact-effect face occlusion: verified `339d4e2` wall sparks render behind/outside
      the player silhouette under autoplay proof (2026-07-02)

---

### T5 — Avatar geometry consolidation
**Lane:** [CX + CC coordination]
**Spec source:** RALLY_OVERHAUL_DIRECTIVE.md Workstream A

**BLOCKED:** avatar decoration code in GameScene pending geometry consolidation.
All avatar visual edits to GameScene.swift are tech debt until this ships.

---

### T6 — Shop real-merchandise overhaul
**Lane:** [CX]
**Spec source:** RALLY_OVERHAUL_DIRECTIVE.md Workstream B, `shop-art-direction.md` (golden file,
routed 2026-06-16 — full "Locker Room Before the Match" hero-stage/try-on/card redesign spec;
read it before starting CX Shop work, ordered impact list at its bottom)

- RallyReferralCatalog.json has 12 items (meets S1 audit)
- [x] Shop CTA → router (ShopItemDetailView routes via RallyReferralLinkRouter; verified 2026-06-12)
- [x] Detail-view product imagery via AsyncImage (verified present 2026-06-12)
- [x] Browse cards (apparelSwatch, brandVisualCardContent) render catalog imagery — SF Symbol
      now loading/fallback only, not terminal state (2026-06-12, CC override per user instruction)
- [x] equip() now writes to shared RallyAvatarAppearanceStore — was stale until next onAppear
      re-sync (2026-06-12, CC override per user instruction)
- [ ] Try On writes to appearance store slots (currently preview-only via appearance(for:previewItem:);
      works visually on stage — CX to decide if store-write is still wanted per directive B3)
- [ ] CX: review the two 2026-06-12 CC-override edits in ShopView.swift / ShopItemDetailView.swift

---

### T7 — Findings carried over from RALLY_CHAT_CONTEXT.md (golden file, routed 2026-06-16)

That file was a stale session-boot context dump (wrong branch name on its header — said
`cursor/init-rally-ios-scaffold`, repo is actually on `rally/dev`; everything else in it matched
current state). Archived to `archive/RALLY_CHAT_CONTEXT_2026-06-16.md`. Its non-duplicate findings,
carried forward here so they aren't lost:

- [ ] **[CX]** Nose invisible at device scale — `RallyAvatarView.swift` nose stroke
      `lineWidth: 0.85 * scale` renders ~0.46pt at gameplay scale, sub-pixel on Retina.
      Suggested fix: `max(1.4 * scale, 1.1)`.
- [ ] **[CX]** ~300 lines dead code in `HomeView.swift` — `avatarCard`, `homeLoadoutSection`,
      `essentialsSection`, `thisWeekStrip`, `pregameRow`, `pregameChip` defined but never called.
      Safe to delete.
- [x] **[CC]** `RallyTab.journal` naming debt — enum case in `ContentView.swift` actually backs
      the World/Courts tab (`tag(RallyTab.journal)` on the "World" tabItem). Confirmed blast
      radius via grep: only `ContentView.swift` references the case directly; `HomeView.swift`
      only holds the `RallyTab` type, never `.journal`. Renamed to `case world` (2026-06-16).

---

## BLOCKED / NOTES

- **Sync data-loss risk found 2026-06-16 (NOT fixed — needs a session with build access,
  flagging only):** `RallySyncCoordinator.apply()` (`Rally/Services/RallySyncCoordinator.swift`)
  deletes every local `TrainingSession`/`MatchEntry`/`JournalEntry` row and re-inserts the
  server's envelope wholesale on **every** `pull()`. Avatar and Progress have real conflict
  protection (revision header + 409 + max-wins merge-back), but these three collections do not —
  there is no id-based diff/merge, so a `pull()` racing ahead of a not-yet-pushed local save
  (e.g. foreground refresh right after writing a journal entry) silently discards that entry.
  Surveyed `RallySyncTriggers.swift`, `RallyAPIClient.swift`, `RemoteTunables.swift` too —
  those are well-hardened (offline-first, fail-safe, feature-flagged, cached-fallback). This one
  collection-replace path is the actual gap. Did not touch the fix itself: it's data-loss-adjacent
  logic touching the user's real journal/training history, and unverifiable without Xcode/sim in
  this sandbox — exactly the kind of change North Star's "real-phone checks beat agent confidence"
  rule says not to push blind. Recommended fix shape for whoever picks this up: merge by `dto.id`
  (update existing row if id matches, insert if new, optionally soft-delete-track removals)
  instead of delete-all-then-insert.
  **STATUS 2026-07-01 [CC]:** fixed as recommended (id-based merge, local-only fields preserved,
  unseen local rows kept). BUILD NOT RUN — sandbox has no Xcode; treat as open until a local
  build + sync round-trip verifies it.
- Avatar decoration in GameScene (shoe xFlip, hair scale) lives outside RallyAvatarGeometry.
  Tech debt. Do not add more avatar drawing to GameScene until T5 consolidation lands.
- CLAUDE_CODE_PARALLEL_PLAN.md lanes: CC does not own Courts/World files by default.
  World marketplace promoted to CC lane by explicit user instruction on 2026-06-11.
  After T1 commit, Courts/World reverts to CX lane.
- Multiple stale plan files exist at repo root (ANIMATION_MODELING_PLAN.md, EXECUTION_ORDER.md,
  TOMORROW_PLAN.md, NEXT.md, POLISH.md, PRESENTATION_PLAN.md). These predate the parallel-agent
  architecture. If they conflict with RALLY_NORTH_STAR.md or CLAUDE_CODE_PARALLEL_PLAN.md,
  the governing docs win. Recommend [CX] clean-up pass to archive these.
