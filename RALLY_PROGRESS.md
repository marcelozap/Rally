# RALLY PROGRESS LEDGER

This file is the single backlog and session log for the Rally repo.
Execute tasks top-down. Update status after every commit.
Governing priority: RALLY_NORTH_STAR.md > CLAUDE_CODE_PARALLEL_PLAN.md > RALLY_OVERHAUL_DIRECTIVE.md.

---

## SESSION LOG

| Date       | Commit     | Lane | Work                              | Notes                                           |
|------------|------------|------|-----------------------------------|-------------------------------------------------|
| 2026-06-13 | aac00cc    | [CC] | T4: contact payoff + miss clarity | Perfect banners live (combo ≤3, every 5th); miss popup red/amber; wallMissCue coaching text |
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
- [ ] VERIFY: b979f01–c3a664d build not run; xcodebuild check that all Journal changes compile

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
- [ ] VERIFY: xcodebuild not run for 2026-06-12/13 [CC] changes; build + device check
      — depth shrink at wall, return urgency, colored miss popups, perfect banners

---

### T5 — Avatar geometry consolidation
**Lane:** [CX + CC coordination]
**Spec source:** RALLY_OVERHAUL_DIRECTIVE.md Workstream A

**BLOCKED:** avatar decoration code in GameScene pending geometry consolidation.
All avatar visual edits to GameScene.swift are tech debt until this ships.

---

### T6 — Shop real-merchandise overhaul
**Lane:** [CX]
**Spec source:** RALLY_OVERHAUL_DIRECTIVE.md Workstream B

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

## BLOCKED / NOTES

- Avatar decoration in GameScene (shoe xFlip, hair scale) lives outside RallyAvatarGeometry.
  Tech debt. Do not add more avatar drawing to GameScene until T5 consolidation lands.
- CLAUDE_CODE_PARALLEL_PLAN.md lanes: CC does not own Courts/World files by default.
  World marketplace promoted to CC lane by explicit user instruction on 2026-06-11.
  After T1 commit, Courts/World reverts to CX lane.
- Multiple stale plan files exist at repo root (ANIMATION_MODELING_PLAN.md, EXECUTION_ORDER.md,
  TOMORROW_PLAN.md, NEXT.md, POLISH.md, PRESENTATION_PLAN.md). These predate the parallel-agent
  architecture. If they conflict with RALLY_NORTH_STAR.md or CLAUDE_CODE_PARALLEL_PLAN.md,
  the governing docs win. Recommend [CX] clean-up pass to archive these.
