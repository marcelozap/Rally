# Rally

A high-polish, rhythm-adjacent iPhone game. Swipe left or right to hit incoming
neon balls in time with a dynamic soundtrack. Minimalist cyberpunk-arcade
aesthetic, dopamine-heavy feedback loop, "TikTok-viral" by design.

> Working title in the GDD: **SwipeBeat**. Repo / shipping name: **Rally**.

## Stack

- **SwiftUI** — menus, settings, cosmetics shop, run summary
- **SpriteKit** — core gameplay scene (ball spawning, hit detection, particles)
- **AVAudioEngine** — layered adaptive soundtrack
- **CoreHaptics** — millisecond-accurate haptic patterns tied to hit quality
- **iOS 17+**, Swift 5.9+, Xcode 15+

## Architecture at a glance

A single `GameEventBus` routes typed `GameEvent`s (e.g. `.perfectHit`,
`.comboTier(n)`, `.miss`) to the three manager systems in parallel:

```
                +------------------+
                |  GameScene (SK)  |
                +---------+--------+
                          |
                          v
                +---------+--------+
                |  GameEventBus    |
                +---------+--------+
                          |
        +-----------------+-----------------+
        v                 v                 v
+---------------+ +---------------+ +----------------+
| HapticManager | | AudioManager  | | ParticleMgr    |
+---------------+ +---------------+ +----------------+
```

This keeps gameplay logic decoupled from feedback systems and lets you tune
"juice" in isolation.

See [`GDD.md`](./GDD.md) for the full creative + technical design.

## Project layout

```
Rally/
  App/            SwiftUI entry point and menus
  Game/           SpriteKit scene, spawner, hit detection
  Managers/       HapticManager, AudioManager, ParticleManager, GameEventBus
  Cosmetics/      Extensible ball-skin / trail schema
  Resources/      Assets.xcassets, audio stems (added later)
project.yml       XcodeGen spec (use to regenerate Rally.xcodeproj)
```

## Generating the Xcode project

This repo ships source + an [XcodeGen](https://github.com/yonaskolb/XcodeGen)
spec rather than a checked-in `.xcodeproj`, so the project file is always in
sync with the source tree.

```bash
brew install xcodegen
xcodegen generate
open Rally.xcodeproj
```

If you'd rather skip XcodeGen, create a new "App" target in Xcode named `Rally`
and drag the `Rally/` folder in.

## Status

Day-0 scaffold. Hit logic, audio layering, and rhythm-spawner are stubbed and
documented in `GDD.md` so they can be filled in incrementally.
