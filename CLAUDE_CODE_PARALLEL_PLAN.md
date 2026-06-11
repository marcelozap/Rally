# CLAUDE CODE PARALLEL PLAN

## Canonical Repo

Path: `/Users/a14/Desktop/Rally`

Branch: `cursor/init-rally-ios-scaffold`

Remote: `https://github.com/marcelozap/Rally.git`

Every session must run:

```bash
pwd
git pull --ff-only || true
git log --oneline -1
git status --short
```

Stop if `pwd` is not `/Users/a14/Desktop/Rally`.

## Shared Direction

Read these before work:

1. `AGENTS.md`
2. `RALLY_NORTH_STAR.md`
3. `RALLY_OVERHAUL_DIRECTIVE.md`

`RALLY_NORTH_STAR.md` wins if documents conflict.

## Commit Prefixes

- `[CC]` for Claude Code commits.
- `[CX]` for Codex/Cursor commits.
- `[sync]` for checkpoint or handoff commits.

## File Ownership Lanes

### Claude Code Lane: Gameplay And Avatar Mechanics

Owns:

- `Rally/Game/GameScene.swift`
- `Rally/Game/Tunables.swift`
- `Rally/Features/Avatar/RallyAvatarGeometry.swift`
- `Rally/Features/Avatar/RallyAvatarRebuildDefaults.swift`
- gameplay-only helpers under `Rally/Game/`

Primary goals:

- make the player grounded and anatomically readable
- make forehand and two-handed backhand distinct
- improve camera/depth/wall/contact feel
- simplify top gameplay chrome to score and exit

Do not edit:

- Shop commerce files
- Courts/World files
- Journal UI files
- Home layout except tiny call-site plumbing when required

### Codex Lane: UI Surfaces, Commerce, Journal, Docs

Owns:

- `Rally/Features/Home/HomeView.swift`
- `Rally/Features/Shop/ShopView.swift`
- `Rally/Features/Shop/ShopItemDetailView.swift`
- `Rally/Features/Shop/LockerHubView.swift`
- `Rally/Services/RallyGearItem.swift`
- `Rally/Services/RallyReferralCatalog.swift`
- `Rally/Services/RallyReferralLinkRouter.swift`
- `Rally/Features/Journal/`
- `Rally/Features/Courts/`
- repo-root direction docs

Primary goals:

- premium Home/Loadout craft
- reliable outfit selection
- real product-driven Shop
- Journal and This Week strip
- World/Courts safe-area and link polish

Do not edit:

- core gameplay swing code
- avatar anatomy geometry
- wall/contact physics

## Shared Files

These files are shared and require caution:

- `Rally/Features/Avatar/RallyAvatarAppearance.swift`
- `Rally/Features/Avatar/RallyAvatarView.swift`
- `Rally.xcodeproj/project.pbxproj`

Rules:

- Prefer additive call-site changes.
- Do not rearrange another agent's work.
- If a conflict is likely, stop and report the exact conflict.

## Task 1 For Claude Code

Direct implementation order. No plan. No audit. Read `RALLY_NORTH_STAR.md` first.

Task: Gameplay player credibility pass.

Files allowed:

- `Rally/Game/GameScene.swift`
- `Rally/Game/Tunables.swift`
- `Rally/Features/Avatar/RallyAvatarGeometry.swift`
- `Rally/Features/Avatar/RallyAvatarRebuildDefaults.swift`

Implement:

1. Fix feet and legs:
   - feet shoulder-width and planted on court plane
   - no inward-caved toes
   - visible thigh/knee/calf separation
   - knees connect thighs to shins
   - shadow under both shoes

2. Fix body connections:
   - shoulders attach arms cleanly
   - wrists attach hands cleanly
   - hips attach legs cleanly
   - torso upright, no humpback silhouette
   - shorts/pelvis must not read as diaper

3. Fix face and hair readability:
   - hair visible from gameplay camera
   - face friendly and simple at iPhone scale
   - no bald read
   - no hostile brow

4. Fix racket ownership:
   - racket visually held in hand
   - no floating racket
   - grip hand draws over handle when needed

5. Fix forehand/backhand alternation:
   - rally target alternates sides often enough to force forehand and backhand
   - right-handed backhand reads as true two-handed backhand
   - backhand is not a mirrored forehand
   - both hands stay on racket through contact and early follow-through

6. Fix gameplay top chrome:
   - score centered or clearly placed
   - exit away from score
   - no heavy top card covering play

Build after changes:

```bash
xcodebuild -scheme Rally -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' -configuration Debug build
```

Commit:

```bash
git add Rally/Game/GameScene.swift Rally/Game/Tunables.swift Rally/Features/Avatar/RallyAvatarGeometry.swift Rally/Features/Avatar/RallyAvatarRebuildDefaults.swift
git commit -m "[CC] Gameplay player credibility pass"
git push
```

Do not stage screenshots, videos, DerivedData, or unrelated files.

## Task 2 For Codex

Home/Loadout craft and outfit selection reliability.

Files:

- `Rally/Features/Home/HomeView.swift`
- `Rally/Features/Shop/LockerHubView.swift`
- `Rally/Features/Avatar/RallyAvatarView.swift` only if needed for draw-call parity

Goals:

- top/shorts/shoes/racket selection must work
- selected slot visually clear
- buttons premium, consistent, pressed
- one type scale
- one radius family
- no default-looking controls

## Merge Discipline

1. Pull before work.
2. Build before commit.
3. Commit only owned files.
4. Push after commit.
5. If merge conflict touches shared files, stop and ask.

