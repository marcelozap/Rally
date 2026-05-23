# Rally — Product & Game Design Document

> Rally is a **tennis lifestyle app** built around one daily-engagement hook.
> Players keep their training log, match log, and journal in one place,
> customize a tennis avatar that wears real-brand apparel from in-app
> vendors (with deep links out to buy), and tap into a high-polish
> rhythm-swipe mini-game whenever they want a few minutes of dopamine.

## A. Product surface (5 tabs)

| Tab        | Purpose                                                                                 | Backed by                                                  |
|------------|-----------------------------------------------------------------------------------------|------------------------------------------------------------|
| **Home**   | Avatar hero, weekly stats, quick log shortcuts, latest journal preview                  | SwiftData queries across all entities                      |
| **Play**   | Tennis rally mini-game (SpriteKit) — baseline aim & timing, see §0–§4                  | `GameScene` + `TennisBallFeed`                            |
| **Logs**   | Training sessions + match results, segmented control at top                              | `TrainingSession`, `MatchEntry` @Model                      |
| **Journal**| Free-form entries with mood + tags                                                       | `JournalEntry` @Model                                       |
| **Shop**   | Browse apparel/rackets by category or by vendor; "try on" overlays item on avatar; deep link to vendor product page | `ShopCatalog` (code), `Vendor` + `ShopItem` (code)         |

### Avatar lifecycle

1. **First launch:** an empty `AvatarConfig` is seeded; the customizer
   gates the main tabs until `hasCompletedSetup` is set.
2. **Steady state:** the avatar is visible on Home and on every Shop item
   detail (with a try-on toggle that previews the item on a copy of the
   config without committing).
3. **Equip:** "Equip" writes to `AvatarConfig.equipped<Slot>ID`. Every
   surface that renders the avatar re-fetches the linked `ShopItem` from
   `ShopCatalog` so equipped color/accent updates instantly.

### Why this scope

The mini-game alone has a low retention ceiling; pure rhythm games churn
hard. Pairing it with a tennis-life journal + shop turns Rally into a
daily-open app where the mini-game is the carrot, not the entire product.
The shop with deep links is the monetization wedge (affiliate revenue or
a future native marketplace).

---

## 0. Game pillars

1. **ASMR-grade impact.** Every hit is a multi-system event (visual + audio +
   haptic) coordinated to the millisecond.
2. **Readable tennis read.** Venue themes, faux-3D court, net, and depth cues
   sell “tennis” first; the adaptive music bed still responds to combo tier.
3. **One thumb, aim + timing.** A single continuous pan: release direction sets
   **shot direction** (toward the far court); release **when** the ball meets
   your strike window sets **quality**. Depth comes from timing and streaks —
   not left/right “lanes.”
4. **Silently viral.** The game must be visually mesmerizing _with the sound
   off_ — because that is how 80% of TikTok/Reels viewers will first see it.

## 0.5. Feel Target — "Flappy Bird grade"

Before any of the layered-soundtrack work below, the **per-tap feel must
match Flappy Bird**. That is the floor. Flappy's lasting power came from
four engineered properties; we explicitly target all four:

| Property                    | Flappy mechanism                                    | Rally implementation                                                       |
|-----------------------------|-----------------------------------------------------|----------------------------------------------------------------------------|
| Sub-frame input → SFX       | Single short asset, pre-loaded                       | `ToneSynth` (programmatic synth via `AVAudioSourceNode`) — zero buffer schedule latency |
| No first-tap warmup         | Apps were cold-loaded from disk; assets pre-decoded | `AudioManager.prewarm()` + `HapticManager.prewarm()` fire at `RallyApp.init` |
| Iconic SFX palette          | `wing.wav`, `point.wav`, `hit.wav`, `die.wav`        | Same four roles, synthesized: see `Tunables.Audio.{wing,point,hit,die}`     |
| Hard freeze on impact       | World pauses ~150 ms on pipe collision               | `Tunables.frameStopDeathMs = 220` on `comboBreak`, applied via `scene.speed = 0` |

The per-hit feedback (point/hit/wing) is intentionally tight: a 24 ms
freeze on `perfect`, 12 ms on `great`, none on `good`. That gives a hit
"weight" without breaking the 16th-note flow. The 220 ms death freeze is
reserved for `comboBreak` — that is the Flappy moment.

All numeric knobs live in one file: [`Rally/Game/Tunables.swift`](Rally/Game/Tunables.swift).
Re-tuning the feel never requires touching gameplay logic.

---

## 1. Creative Evolution

### 1.1 The "Juice" Framework — Impact Logic

A **Perfect Hit** is not one effect; it is a **timeline of effects**, each
fired by `GameEventBus` with a precise offset from `t=0` (the moment the ball
crosses the strike line).

| t (ms) | System    | Action                                                              |
|-------:|-----------|---------------------------------------------------------------------|
|     0  | Physics   | Ball velocity is _frozen_ for `frameStopMs` (3–6 ms)                |
|     0  | Haptics   | `CHHapticPattern` fires (sharp transient + 30 ms continuous)        |
|     0  | Audio     | Stinger sample triggered via pre-warmed `AVAudioPlayerNode`         |
|    +2  | Visual    | Ball scales 1.0 → 1.25 → 1.0 over 90 ms (`easeOutBack`)              |
|    +4  | Visual    | Radial neon shockwave emitter (`SKEmitterNode`, 60-particle burst)  |
|    +8  | Camera    | Screen-shake: 3 px amplitude, 120 ms, damped sine                   |
|   +12  | Visual    | Chromatic-aberration flash via `CIFilter` on a render texture       |
|   +40  | Audio     | Combo-tier instrument layer crossfaded in over 200 ms (if tier↑)    |
|   +90  | Visual    | Score number tweens up with a velocity-based blur                   |

**Frame-stop** (a.k.a. "hit pause") is the secret sauce: pausing the scene's
`speed = 0` for ~5 ms makes the brain interpret the moment as _heavier_ than
it actually is. SpriteKit makes this trivial — `scene.speed = 0` then restore
on the next `update(_:)` after `frameStopMs` elapsed.

**Hit-quality grading** drives intensity:

| Grade   | Timing window | Frame-stop | Haptic intensity | Audio stinger |
|---------|---------------|-----------:|-----------------:|---------------|
| Perfect | ±33 ms        |       6 ms |             1.0  | `hit_perfect` |
| Great   | ±66 ms        |       3 ms |             0.7  | `hit_great`   |
| Good    | ±100 ms       |       0 ms |             0.4  | `hit_good`    |
| Miss    | —             |       0 ms |        soft buzz | `hit_miss`    |

### 1.2 Adaptive Audio System — Dynamic Soundtrack

The track is **stems-based**, not a single mixdown. Each track on disk is
authored as N stems at identical tempo and bar length:

- `stem_00_drums.caf`     — always on, baseline
- `stem_01_bass.caf`      — combo ≥ 5
- `stem_02_arp.caf`       — combo ≥ 15
- `stem_03_lead.caf`      — combo ≥ 30
- `stem_04_pad.caf`       — combo ≥ 50
- `stem_fx_riser.caf`     — combo-tier transitions
- `stem_fx_drop.caf`      — on `.comboBreak`

**Technical strategy (no audio lag):**

1. **One `AVAudioEngine` per session**, with one `AVAudioPlayerNode` _per
   stem_, all attached at app launch and wired to a single shared
   `AVAudioMixerNode`. No allocation on the hot path.
2. **All stems play continuously, gated by volume**, not by start/stop. Each
   node's `volume` is ramped via `AVAudioMixerNode`-level automation or a
   per-buffer scheduled fade. Starting/stopping nodes causes glitches —
   crossfading does not.
3. **Schedule stems on the bar boundary**, not at the moment a tier is
   reached. When combo crosses a threshold, mark the target volume; the
   per-frame audio tick smoothly ramps to it over `barLengthMs / 4`.
4. **Stingers (perfect-hit cues) use a pool of pre-loaded
   `AVAudioPCMBuffer`s** played via dedicated player nodes. No file I/O at
   hit-time. The pool is sized for the maximum simultaneous stinger count
   (~8) and round-robins.
5. **All stems share a sample rate (48 kHz) and bit depth** so the engine
   never resamples mid-session.
6. **Pre-warm**: load + schedule all buffers on a background queue before
   `GameScene` presents; transition only when ready.

Result: zero perceptible audio latency, no clicks at tier changes, and a
soundtrack that audibly _grows_ with the player's skill.

### 1.3 Procedural Difficulty Curve — Rhythm-Based Spawning

The game does not just "spawn faster." It **spawns _on the beat_**.

- Each track ships with a JSON **beatmap** at authoring time:
  `{ bpm: 128, beats: [{t: 0.5, lane: .left, kind: .normal}, ...] }`.
- The spawner reads the next N beats ahead and emits balls so they _arrive
  at the strike line on the beat_, accounting for travel time at the current
  ball speed.
- **Density curve** is a function of `(elapsedTime, currentCombo)`:
  - Easy: quarter-notes only.
  - Building: eighth-notes, alternating lanes.
  - Peak: sixteenth-note runs, double-balls (two lanes simultaneously
    requiring a "both swipe").
- **Generative variation**: each session perturbs the beatmap with a seeded
  RNG so two players with the same track get _similar but not identical_
  charts. This keeps short-form videos visually fresh.

The player isn't dodging projectiles — they're **playing the drums**. Missing
a beat doesn't just cost points; it audibly silences a drum hit in the
soundtrack until the next bar.

---

## 2. Technical Blueprint

### 2.1 Manager Pattern + GameEvent bus

Single source of truth for "something interesting just happened":

```swift
enum GameEvent {
    case hit(quality: HitQuality, lane: Lane, position: CGPoint)
    case miss(lane: Lane)
    case comboTier(Int)         // emitted when crossing a tier boundary
    case comboBreak(previous: Int)
    case sessionStart, sessionEnd
    case cosmeticEquipped(Cosmetic.ID)
}
```

`GameEventBus` is an `actor`-free, main-thread observer hub (gameplay is
already main-thread by virtue of SpriteKit):

```swift
final class GameEventBus {
    static let shared = GameEventBus()
    private var listeners: [WeakBox<AnyObject>: (GameEvent) -> Void] = [:]

    func subscribe(_ owner: AnyObject, _ handler: @escaping (GameEvent) -> Void)
    func publish(_ event: GameEvent)
}
```

`HapticManager`, `AudioManager`, and `ParticleManager` each subscribe once at
app launch. The `GameScene` is the only publisher. This means:

- Adding a new feedback channel = add a new manager + subscribe. Zero changes
  to gameplay code.
- Disabling haptics / sound is `manager.isEnabled = false`. No `if` branches
  scattered through gameplay.
- The same `GameEvent` stream is trivially recordable for replay or analytics.

### 2.2 Unlockable Cosmetics Schema

Designed so a single Swift type + an asset folder is enough to ship a new
skin — no engine changes.

```swift
struct Cosmetic: Identifiable, Codable, Hashable {
    enum Kind: String, Codable { case ballSkin, trail, hitBurst, theme }
    enum Rarity: String, Codable { case common, rare, epic, mythic }
    enum Unlock: Codable {
        case freeAtLaunch
        case scoreThreshold(Int)
        case comboMilestone(Int)
        case promo(code: String)
        case purchase(productID: String)
    }

    let id: ID
    let kind: Kind
    let displayName: String
    let rarity: Rarity
    let unlock: Unlock

    /// Asset references (look-up in Assets.xcassets / particle plists)
    let textureName: String?
    let particleName: String?
    let tint: CodableColor?

    /// Optional behavioral tweaks the cosmetic introduces.
    let modifiers: CosmeticModifiers?
}

struct CosmeticModifiers: Codable, Hashable {
    var trailLengthMultiplier: Double = 1.0
    var hitBurstParticleCountMultiplier: Double = 1.0
    var screenShakeMultiplier: Double = 1.0
}
```

Catalog ships as `Resources/cosmetics.json`, hot-loadable so the live ops
team can add skins via a remote-config drop without an App Store release.

### 2.3 Module map

```
Rally/
  App/
    RallyApp.swift            # @main, ModelContainer, prewarms audio + haptics
    ContentView.swift         # TabView root + first-launch avatar gate
  Game/
    GameScene.swift           # SpriteKit scene + camera node + frame-stop
    GameEvent.swift           # typed event payload
    HitQuality.swift
    Lane.swift
    TennisBallFeed (in GameScene.swift)   # paced incoming balls, no BPM chart
    RhythmSpawner.swift       # legacy beatmap helpers / tests
    Tunables.swift            # every "feel" number, single source of truth
  Audio/
    ToneSynth.swift           # programmatic SFX synth (no asset files)
  Managers/
    GameEventBus.swift
    HapticManager.swift       # CHHapticEngine + cached pattern players
    AudioManager.swift        # AVAudioEngine + ToneSynth wiring
    ParticleManager.swift     # bursts, flashes, death sequence
    CameraShake.swift         # damped-sine shake utility
  Data/
    TrainingSession.swift, MatchModels.swift (CourtSurface, SetScore), JournalModels.swift,
    AvatarModels.swift, PlayerProgress.swift  # SwiftData @Model types (split files)
    ShopCatalog.swift         # static vendor + shop item catalog
  Services/                 # optional cloud: AuthSession, API, sync coordinator + triggers
  Features/
    Home/HomeView.swift
    Logs/LogsView.swift
    Training/TrainingLogView.swift
    Training/TrainingEditorView.swift
    Match/MatchLogView.swift
    Match/MatchEditorView.swift
    Journal/JournalView.swift
    Journal/JournalEditorView.swift
    Shop/ShopView.swift
    Shop/ShopItemDetailView.swift
    Avatar/AvatarView.swift           # SwiftUI composition (skin, hair, kit, racket)
    Avatar/AvatarCustomizerView.swift # first-launch flow
  Cosmetics/
    # (In-game ball-skin cosmetics — distinct from Shop apparel. Future.)
    Cosmetic.swift
    CosmeticCatalog.swift
  Resources/
    Assets.xcassets/          # (added in Xcode)
    cosmetics.json            # in-game cosmetics seed (future)
```

---

## 3. Viral Mechanic — "Echo Trail"

The one mechanic engineered explicitly for silent-video virality:

When the player hits **5+ Perfect Hits in a row**, each subsequent ball
leaves a **persistent neon afterimage** that traces the exact path of the
combo across the screen. The screen becomes a glowing, self-drawn waveform of
the player's run. On a `comboBreak`, the trail shatters into particles all
at once.

Why this works:

- **Reads in 2 seconds, silent.** A TikTok viewer scrolling past sees a
  neon line drawing _itself_ — they stop.
- **The trail _is_ the score.** Better runs literally make prettier art.
- **Shareable artifact.** End-of-run "Save your trail" exports a 1080×1920
  PNG of the final waveform with a watermark + score. Free user-generated
  marketing.
- **In-game depth.** Some cosmetics modify the trail color/shape, giving
  whales something visually distinct to flex.

Implementation outline:

- A dedicated `SKShapeNode` per active combo, path built up incrementally on
  each hit using `addLine(to:)`.
- Path is rendered with `strokeColor` set to the current theme's neon, with
  `glowWidth` proportional to combo tier.
- On `.comboBreak`, the node is replaced by an `SKEmitterNode` configured to
  emit along the previous path (sampled at ~30 points) and faded out.

---

## 4. Day-0 → Day-N roadmap

1. **Day 0 (this commit):** scaffold, manager pattern, event bus, stubs.
2. **Day 1–3:** core swipe → hit detection → grade. Single hardcoded beatmap.
3. **Day 4–6:** AudioManager stem layering with one track.
4. **Day 7–9:** ParticleManager + frame-stop + Echo Trail.
5. **Day 10–12:** Cosmetics catalog + unlock conditions + main-menu shop UI.
6. **Day 13+:** Beatmap authoring tool, additional tracks, Game Center,
   share-card export.
