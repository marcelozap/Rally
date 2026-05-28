# Rally

A high-polish, rhythm-adjacent iPhone game. Swipe left or right to hit incoming neon balls in time with a dynamic soundtrack. Minimalist cyberpunk-arcade aesthetic, dopamine-heavy feedback loop.

> Working title in the GDD: **SwipeBeat**. Repo / shipping name: **Rally**.

## Stack

- **SwiftUI** — menus, auth, logs, journal, shop, court atlas
- **SpriteKit** — gameplay scene (balls, rhythm spawner, hits)
- **SwiftData** — avatar, progression, training, matches, journal (local-first)
- **AVAudioEngine** — layered adaptive soundtrack (`MusicEngine`, `ToneSynth`)
- **CoreHaptics** — hit-quality patterns
- **Optional Node API** — accounts + JWT + **full JSON snapshot sync** ([`backend/`](./backend/))
- **iOS 17+**, Swift 5.9+, Xcode 15+

Architecture diagrams and **sync semantics (last-writer-wins, when uploads run)** → **[`ARCHITECTURE.md`](./ARCHITECTURE.md)**.

## Repository layout

```text
Rally/
  App/              RallyApp, RootView (auth / guest gate), ContentView (tabs)
  Features/         Auth, Home, Play, Logs, Training, Match, Journal, Shop, Avatar, Courts
  Services/         API client, Keychain JWT, AuthSession, snapshot sync + triggers
  Data/             SwiftData models (split files), ShopCatalog, journal prompts, iconic courts
  Game/             SpriteKit scene, spawner, lanes, tuning
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

Active development — gameplay, progression, journal, shop, court atlas, and optional cloud backup are in-repo; see `GDD.md` for the north-star experience.
