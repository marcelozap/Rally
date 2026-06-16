# Rally iOS — context dump for new session

Repo: `/Users/a14/Desktop/Rally`, branch `cursor/init-rally-ios-scaffold`, remote `https://github.com/marcelozap/Rally.git`.

**Before doing anything, run:**
```bash
cd /Users/a14/Desktop/Rally
pwd && git log --oneline -1 && git status --short
```
Stop if pwd is not that path.

**Read these files first (in order):**
1. `AGENTS.md`
2. `RALLY_NORTH_STAR.md`
3. `RALLY_PROGRESS.md`
4. `agents/current-priority.md`
5. `agents/lanes.md`

---

## What Rally is

Premium tennis iOS game. SpriteKit gameplay inside a SwiftUI shell. Six pillars: Gameplay, Avatar, Loadout, Shop, Locker, Journal. North Star: one avatar identity, one appearance store, all commerce through `RallyReferralLinkRouter`.

**Architecture:** SwiftData models (`JournalEntry`, `AvatarConfig`, `PlayerProgress`). `RallyAvatarAppearanceStore` is the single source of truth for avatar appearance. `GameScene` consumes it, never re-invents it. `RallyReferralCatalog` has 12 real gear items. `CourtVenue` / `IconicCourtsCatalog` has 20+ venue listings. GPS-based court check-in unlocks wristband rewards in `ShopCatalog`.

---

## Lane rules (critical — never cross these)

- **CC lane (Claude Code):** `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift`, `Rally/Game/MatchFlow.swift`, `Rally/Features/Courts/`, `Rally/Features/Journal/`, `Rally/Features/Play/GameSessionView.swift` (shared, edit carefully)
- **CX lane (Codex/Cursor):** `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Features/Home/HomeView.swift`, `Rally/Features/Shop/`, `Rally/Services/RallyReferralCatalog.swift`
- **Shared:** `Rally.xcodeproj/project.pbxproj`, `Rally/Features/Avatar/RallyAvatarAppearance.swift`, `RALLY_PROGRESS.md`

Commit prefixes: `[CC]` for Claude Code, `[CX]` for Codex, `[sync]` for checkpoints. Every code task ends with a build unless doc-only. No `git push` from sandbox (no credentials).

---

## Recent commits (most recent first)

- `bcc8b6a` [CC] Audit fix: Miami court name ("Australia" bug fixed) + ball shadow 0.22→0.32
- `6025cb7` [CX] Shop tab badge for cosmetic unlocks + locker equipped-item highlight
- `85e3582` [CC] Ball shadow lerp (xScale 0.30–0.90 with depth); maxSameLaneRun 2→1 (strict FH/BH alternation)
- `49d8a4e` [CC] Courts tier 2 unlocks: Ashe/Laver/Indian Wells wristband rewards in ShopCatalog; reward badge UI in CourtsMapView
- `f994b40` [CC] Journal CTA in exit confirmation dialog (exit button → confirmationDialog)
- `2cf056a` [CC] combo-scaled recovery window (registerComboBreak scales 1–2× with previousCombo)
- `aac00cc` [CC] T4: contact payoff + miss clarity (perfect banners, red/amber miss popups)
- `c3a664d` [CC] Journal: venue + gear worn in session
- `88b622a` [CC] Journal: structured rally metrics on model + JournalInsights week aggregates

**Build status:** All commits through 2026-06-13 verified BUILD SUCCEEDED on iPhone 16 Pro sim. Commits from 2026-06-15 (`85e3582`, `49d8a4e`, `f994b40`, `2cf056a`, `bcc8b6a`, `6025cb7`) are BUILD NOT RUN — need xcodebuild from the Mac.

---

## Highest priority remaining work

1. **Nose invisible at device scale** (CX lane) — `RallyAvatarView.swift`: nose stroke `lineWidth: 0.85 * scale` renders ~0.46pt at gameplay scale — sub-pixel on Retina. Fix: `max(1.4 * scale, 1.1)`.

2. **~300 lines dead code in HomeView** (CX lane) — `avatarCard`, `homeLoadoutSection`, `essentialsSection`, `thisWeekStrip`, `pregameRow`, `pregameChip` defined but never called. Safe to delete.

3. **`RallyTab.journal` used for World/Courts tab** (Shared) — naming debt, should be `case world`. Touches `ContentView.swift`.

4. **Real-phone install (Priority 1 per agents/current-priority.md)** — install on device, write down bugs, don't fix during the test. Test: launch, avatar customization, handedness, outfit selection, PLAY transition, avatar identity match in gameplay, touch timing, haptics, audio balance, Shop links, Journal/session logging.

5. **Two-handed backhand visual verification** — code looks correct but needs screenshot on device to confirm.

## Known tech debt

- Avatar decoration code (shoe xFlip, hair scale) inside GameScene.swift — should move to RallyAvatarGeometry (T5, BLOCKED)
- T6 Shop Try On → appearance store write still TBD (CX decision)
- `xcodegen generate` needed for NSLocationWhenInUseUsageDescription (xcodegen not in sandbox)

---

## Key files

- `Rally/Game/GameScene.swift` — main gameplay, ~7000+ lines
- `Rally/Game/Tunables.swift` — all numeric constants
- `Rally/Game/MatchFlow.swift` — phase coordinator (warmUp/exchange/pressure/breaker/recovery)
- `Rally/Features/Avatar/RallyAvatarGeometry.swift` — canonical avatar drawing geometry
- `Rally/Features/Avatar/RallyAvatarView.swift` — SwiftUI + SpriteKit avatar renderers
- `Rally/Data/JournalEntrySources.swift` — JournalAutoLogger, RallySessionJournalSource
- `Rally/Data/JournalModels.swift` — JournalEntry @Model with rally metrics fields
- `Rally/Data/ShopCatalog.swift` — gear items, court unlock → shop item map
- `Rally/Features/Courts/CourtsMapView.swift` — world screen, 20+ venues, tier-2 reward badges
- `Rally/Features/Play/GameSessionView.swift` — session container, handleSessionEnded, exit confirmation dialog
