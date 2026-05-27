# Rally

Tennis lifestyle app for iPhone that combines a fast daily-use game loop with training logs, match history, journaling, avatar customization, a branded shop experience, and a high-feedback SpriteKit rally mini-game.

> Working title in the GDD: **SwipeBeat**. Repo / shipping name: **Rally**.

## What this project is

Rally is not just a standalone game prototype. It is a product concept built around one repeatable engagement loop, then extended into a broader tennis experience:

- **Play**: a high-polish rhythm-swipe mini-game designed for fast repeat sessions
- **Logs**: training sessions and match history
- **Journal**: tennis-life notes and reflection
- **Avatar + Shop**: customization and apparel discovery
- **Optional sync**: account-based backup through a lightweight backend

The core idea is that the game creates the daily-open habit, while the surrounding product makes the app useful beyond a single mechanic.

## Stack

- **SwiftUI** — menus, auth, logs, journal, shop, court atlas
- **SpriteKit** — gameplay scene (balls, rhythm spawner, hits)
- **SwiftData** — avatar, progression, training, matches, journal (local-first)
- **AVAudioEngine** — layered adaptive soundtrack (`MusicEngine`, `ToneSynth`)
- **CoreHaptics** — hit-quality patterns
- **Optional Node API** — accounts + JWT + **full JSON snapshot sync** ([`backend/`](./backend/))
- **iOS 17+**, Swift 5.9+, Xcode 15+

Architecture diagrams and **sync semantics (last-writer-wins, when uploads run)** → **[`ARCHITECTURE.md`](./ARCHITECTURE.md)**.

## Why it stands out

- Local-first product design with optional sync instead of backend-first dependency
- Clear product surface beyond gameplay alone
- Strong attention to audio, haptics, and feel
- Mix of consumer product thinking, iOS engineering, and systems design

## Repository layout

```text
Rally/
  App/              RallyApp, RootView (auth / guest gate), ContentView (tabs)
  Features/         Auth, Home, Play, Logs, Training, Match, Journal, Shop, Avatar, Courts
  Services/         API client, Keychain JWT, AuthSession, snapshot sync + triggers
  Data/             SwiftData models (split files), ShopCatalog, journal prompts, iconic courts
  Game/             SpriteKit scene, ball feed, tuning (`CourtTheme` / surfaces)
  Managers/         GameEventBus, AudioManager, HapticManager, ParticleManager
  Audio/            MusicEngine, ToneSynth
  Cosmetics/        Ball / trail catalog for gameplay
backend/            Express + SQLite dev API (see backend/README.md & DEPLOYMENT.md)
project.yml         XcodeGen → Rally.xcodeproj
RallyTests/         XCTest (Codable / helper coverage — expand over time)
ARCHITECTURE.md     Structure, auth modes, cloud sync contract
GDD.md              Creative + technical design
```

## Accounts & sync (short)

- **Sign in** — JWT in Keychain; bootstrap pulls server snapshot into SwiftData.
- **Continue offline** — guest mode (UserDefaults); no cloud backup until the user signs in (pull then replaces local per snapshot rules).
- Uploads run after login/register, editor saves, shop equip, game-over progression save, log deletes, avatar save, and app foreground (when signed in). Details in **`ARCHITECTURE.md`**.

## Generating the Xcode project

This repo ships source + [XcodeGen](https://github.com/yonaskolb/XcodeGen) rather than a checked-in `.xcodeproj`.

```bash
brew install xcodegen
xcodegen generate
open Rally.xcodeproj
```

Run unit tests from Xcode (**⌘U**) or `xcodebuild test` with the **Rally** scheme once the project is generated.

## Backend (optional)

```bash
cd backend && cp .env.example .env && npm install && npm run dev
```

Production checklist: [`backend/DEPLOYMENT.md`](./backend/DEPLOYMENT.md).

## Status

Active development. Gameplay, progression, journal, shop, court atlas, and optional cloud backup are in-repo; see `GDD.md` for the north-star product direction.

**Current planning docs:** [UI & design system](./UI_DESIGN_OVERHAUL_PLAN.md) · [Avatar & court visuals](./AVATAR_OVERHAUL_PLAN.md) · [System polish](./POLISH.md) · [Live match presentation](./PRESENTATION_PLAN.md) · [Animation & modeling](./ANIMATION_MODELING_PLAN.md) · [Execution order](./EXECUTION_ORDER.md)
