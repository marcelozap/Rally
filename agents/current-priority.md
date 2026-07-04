# Current Priority

Last updated: 2026-07-04

Rally is close enough for real-device testing. The next work should reduce risk and improve what the player immediately feels.

## Current Operating Mode

Active branch: `rally/dev`

Canonical repo: `/Users/a14/Desktop/Rally`

Do not use or reference the old `cursor/init-rally-ios-scaffold` branch as the active lane.

The tree is build-verified on `rally/dev`. If `agents/handoff.md` is dirty, preserve it unless the user explicitly asks to resolve that handoff.

Primary lane right now: **Rafa Gameplay**. Finish the addictive wall-rally loop before starting new Shop, World, or Journal feature work.

## Priority 1: Real Phone Test

Use these two files:

- `RALLY_REAL_PHONE_TEST.md` — step-by-step device checklist
- `RALLY_REAL_PHONE_RESULTS.md` — scorecard, top-three bugs, and patch order

Install on a real iPhone and test:

- launch
- avatar customization
- handedness
- outfit selection
- PLAY transition
- gameplay avatar identity match
- touch timing
- haptics
- audio balance after manually enabling Sound (Rally is intentionally quiet by default)
- Shop links
- Journal/session logging

Write bugs down in `RALLY_REAL_PHONE_RESULTS.md`. Do not fix during the test.

After the test, fix only the top three observed bugs in score-impact order.

## Quiet Audio Policy

Sound is intentionally **off by default** so autoplay, simulator runs, and late-night testing do not wake the room. The player can opt in from the visible sound toggles on Home/Locker and Game Settings. Do not re-enable launch audio or prewarm the audio engine unless `RallyDefaults.resolvedSoundEnabled()` returns true.

## Priority 2: Avatar Identity

The recurring visual defect is still:

- no readable mouth/eyes at gameplay scale
- hair can read bald or disconnected
- ears/head/neck relationship is fragile
- feet can still look turned inward
- Home and gameplay must always be the same person

Fix through shared geometry and verified screenshots, not per-screen hacks.

## Priority 3: Rafa Gameplay POV And Mechanics

The camera still needs to feel like tennis, not a flat toy:

- more believable court perspective
- stronger wall depth read
- ball scale/shadow must read instantly
- forehand/backhand alternation must be obvious
- two-handed backhand must use both hands through contact

## Priority 4: Sinner Store / Locker Clarity

The store and Locker should feel premium and easy:

- shoes must read like tennis shoes, not dress shoes
- shorts must read like tennis shorts, not a generic square
- product cards should use real imagery when available
- item cycling can use left/right arrows where that is cleaner than crowded tiles
- Try On should instantly update the shared avatar

## Priority 5: Carlos World / Courts Reliability

The world layer should be clean and trustworthy:

- links open real destinations
- cards do not hide under the Dynamic Island
- markers do not pile up
- venue actions are named honestly

## Priority 6: TestFlight Prep

Before wider testers:

- app icon warning resolved
- privacy strings verified
- no debug overlays by default
- no broken links
- no stale folder confusion
- build from clean repo

## Do Not Start Yet

Do not chase big new features until the real-phone loop is stable.
