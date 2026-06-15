# Lane Ownership

Rally can support two agents only if each agent stays in its lane.

## Commit Prefixes

- `[CX]` Codex / Cursor
- `[CC]` Claude Code
- `[sync]` checkpoint / handoff
- `[lock]` lock claim or release

## CX Lane

CX owns product surface quality and commerce:

- `Rally/Features/Home/HomeView.swift`
- `Rally/Features/Avatar/RallyAvatarGeometry.swift`
- `Rally/Features/Avatar/RallyAvatarView.swift`
- `Rally/Features/Avatar/RallyAvatarAppearance.swift`
- avatar creator files
- `Rally/Features/Avatar/AvatarCustomizerView.swift`
- `Rally/Features/Shop/AvatarShopStageView.swift`
- `Rally/Features/Shop/ShopView.swift`
- `Rally/Features/Shop/ShopItemDetailView.swift`
- `Rally/Features/Shop/LockerHubView.swift`
- `Rally/Services/RallyGearItem.swift`
- `Rally/Services/RallyReferralCatalog.swift`
- `Rally/Services/RallyReferralLinkRouter.swift`
- root direction docs

Current CX priorities:

1. avatar face / hair / feet readability
2. Home and Locker craft
3. Shop cards with real product imagery
4. TestFlight polish

## Rafa Lane

Rafa is the gameplay specialist. Use `agents/rafa-gameplay.md` for his operating rules.

Rafa owns:

- gameplay feel and camera POV
- ball depth and wall contact
- forehand and two-handed backhand mechanics
- footwork, planted stance, and recovery
- gameplay HUD simplicity
- audio/haptic feel tied directly to hits

## CC Lane

CC owns gameplay, journal, courts, audio, haptics, and backend foundations:

- `Rally/Game/GameScene.swift`
- `Rally/Game/Tunables.swift`
- gameplay-only helpers under `Rally/Game/`
- `Rally/Features/Journal/`
- `Rally/Features/Courts/`
- audio and haptics files
- backend sync and live-ops files

Current CC priorities:

1. gameplay feel and camera POV
2. forehand / two-handed backhand mechanics
3. session logging and training journal
4. sync/live-ops hardening

## Sinner Lane

Sinner is the store and Locker specialist. Use `agents/sinner-store.md` for his operating rules.

Sinner owns:

- Shop cards and product imagery
- Locker outfit selection
- gear item presentation
- Try On flow
- referral commerce routing
- shoe, shorts, racket, top, socks, and headband selection clarity

## Carlos Lane

Carlos is the world and courts specialist. Use `agents/carlos-world.md` for his operating rules.

Carlos owns:

- Courts map
- venue cards
- official / booking links
- marker decluttering
- court check-ins and unlocks
- world safe-area polish

## Shared Files

Shared files require caution and often a lock:

- `Rally.xcodeproj/project.pbxproj`
- `Rally/Features/Play/GameSessionView.swift`
- `Rally/Features/Avatar/RallyAvatarAppearance.swift`
- `RALLY_PROGRESS.md`

Prefer additive call-site changes. Do not rearrange another agent's work.
