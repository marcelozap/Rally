# RALLY PROGRESS LEDGER

This file is the single backlog and session log for the Rally repo.
Execute tasks top-down. Update status after every commit.
Governing priority: RALLY_NORTH_STAR.md > CLAUDE_CODE_PARALLEL_PLAN.md > RALLY_OVERHAUL_DIRECTIVE.md.

---

## SESSION LOG

| Date       | Commit     | Lane | Work                              | Notes                                           |
|------------|------------|------|-----------------------------------|-------------------------------------------------|
| 2026-06-11 | dd3d701    | sync | Avatar overhaul + pro body mech   | torso uncoil 5.2×, sleeve gaps, scale 1.14      |
| 2026-06-11 | 39fb976    | [CC] | Gameplay player credibility pass  | Trail shoe mirror (xFlip), hair scale 0.82/0.92 |
| 2026-06-11 | (pending)  | [CC] | World marketplace                 | 20th listing, DEBUG router, category cards      |

Credibility pass (39fb976) is partial progress toward **T4 Gameplay feel** and **T5 Avatar polish**.
Note: shoe/hair edits modify avatar drawing inside GameScene.swift — per North Star law 1, avatar
drawing belongs in RallyAvatarGeometry. Flagged as tech debt: "avatar decoration code in GameScene
pending geometry consolidation." Treat ALL avatar visual code as CX territory unless ledger says
takeover=YES.

---

## BACKLOG

### T1 — World marketplace (Courts/Atlas screen)  ← ACTIVE
**Lane:** [CC] override (CX owns Courts normally; user promoted to CC for this task)
**Spec source:** RALLY_OVERHAUL_DIRECTIVE.md Workstream C

- [x] 1a Venue listing model — `IconicTennisCourt` covers all required fields
- [ ] 1b 20-listing seed catalog with real URLs — 19 now; add 1 venue
- [ ] 1c Link repair via RallyReferralLinkRouter — DEBUG logging; zero nil-URL controls
- [ ] 1d Safe area + marker decluttering + functional category chips
- [ ] 1e Per-category storefront cards + disclosure line

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

- auto-log rally sessions
- calendar-style weekly/monthly history
- manual training notes
- Garmin-ready source protocol (stubs OK)

---

### T3 — Home/Loadout craft (premium pregame surface)
**Lane:** [CX]
**Spec source:** RALLY_NORTH_STAR.md §Home And Loadout

---

### T4 — Gameplay feel (camera/physics/contact)
**Lane:** [CC]
**Spec source:** RALLY_NORTH_STAR.md §Gameplay Feel Contract

- readable depth: ball scale, shadow, court perspective
- contact payoff: hit-stop, flash, sparks, haptic, timing text
- return acceleration urgency
- miss clarity

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
- Needs editorial product cards, Try On → appearance store, Shop → router

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
