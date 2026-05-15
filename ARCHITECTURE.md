# Rally — architecture & data flow

This doc complements [`README.md`](./README.md) and [`GDD.md`](./GDD.md). It focuses on **structure**, **sync semantics**, and **where to change things**.

## Folder map (`Rally/`)

| Area | Responsibility |
|------|----------------|
| `App/` | `RallyApp`, `RootView` (auth gate), `ContentView` (tabs) |
| `Features/` | Screen-oriented SwiftUI: Auth, Home, Play, Logs, Training, Match, Journal, Shop, Avatar, Courts |
| `Services/` | Keychain JWT, HTTP client, **full-snapshot sync**, auth session, `RallySyncTriggers` |
| `Data/` | SwiftData `@Model` types (split files), static catalogs (`ShopCatalog`, journals, courts) |
| `Game/` | SpriteKit scene, spawner, lanes, tuning |
| `Managers/` | `GameEventBus`, audio, haptics, particles |
| `Audio/` | Music / synth layers |
| `Cosmetics/` | Ball / trail definitions used by gameplay |

**Gameplay path:** `GameSessionView` → `GameScene` → events → `GameEventBus` → managers.

**Product shell path:** `Features/*` ↔ SwiftData ↔ optional **`backend/`** via `RallySyncCoordinator`.

## Cloud sync (important)

- **Model:** one JSON **snapshot per user** on the server (`avatar`, `progress`, `trainingSessions`, `matchEntries`, `journalEntries`).
- **Conflict policy:**
  - **`PlayerProgress` numerics** (`coins`, `xp`, `bestScore`, `bestCombo`, every `total*`, `dailyStreak`, `lastPlayDate`) are reconciled **max-wins** on the server during `PUT`. This protects a multi-device user from losing accrued totals if a stale device pushes after a fresh one.
  - **Avatar + collections** (training / match / journal) remain **last-writer-wins** — these are user-edited, not accrued, so blowing-away semantics are correct there.
  - The merged snapshot is echoed in the `PUT` response (`merged`) so the client can apply the reconciled progress fields locally without a second `GET`. See `mergeProgressMaxWins` in `backend/src/server.js` and `ProgressPayload.mergedMaxWins` in `Rally/Services/RallySyncPayload.swift` — keep them in sync.
- **Pull:** replaces collection rows locally and overwrites the singleton `AvatarConfig` / `PlayerProgress` fields from the payload.
- **Two-device walkthrough:**
  1. Device A finishes a run with `bestScore = 1200` → pushes → server stores 1200.
  2. Device B (stale; last pull had `bestScore = 800`) finishes a run with 900 → pushes.
  3. Server merges: max(1200, 900) = 1200 ; client B receives `merged.progress` and overwrites its local 900 with 1200.
  4. No data lost; converges in one round-trip.
- **When uploads run:**
  - After **login / register** (pull then continue locally).
  - After **avatar save** (when signed in).
  - After **training / match / journal editor saves**, **shop equip**, **game-over progression save**, **journal delete**, **training/match log deletes**.
  - When the app returns to **foreground** (push only, signed in).
- **Guests:** **Continue offline** keeps everything on-device only; no JWT → no cloud backup until the user signs in (then server snapshot replaces local per pull semantics).

See [`backend/README.md`](./backend/README.md) and [`backend/DEPLOYMENT.md`](./backend/DEPLOYMENT.md) for the API and production rollout.

## Auth modes

| Mode | Behavior |
|------|-----------|
| **Signed in** | JWT in Keychain; bootstrap validates via `GET /api/me/sync`; pushes on triggers above. |
| **Guest** | Persisted flag `UserDefaults`; skips API; same SwiftData UX. |

Signing in clears guest mode and pulls the account snapshot.

## Testing

- Unit tests live in **`RallyTests/`** (Codable roundtrips, small pure helpers).
- Add XCTest cases as you stabilize formats (`SyncEnvelope`, score CSV, etc.).

## Likely future splits

- Incremental sync or operational transforms if multi-device editing matters.
- Normalize backend tables instead of one JSON blob for analytics/reporting.
- Dedicated `Settings` feature for API URL, account, legal.
