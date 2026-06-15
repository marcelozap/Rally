# Current Priority

Last updated: 2026-06-15

Rally is close enough for real-device testing. The next work should reduce risk and improve what the player immediately feels.

## Priority 1: Real Phone Test

Install on a real iPhone and test:

- launch
- avatar customization
- handedness
- outfit selection
- PLAY transition
- gameplay avatar identity match
- touch timing
- haptics
- audio balance
- Shop links
- Journal/session logging

Write bugs down. Do not fix during the test.

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
