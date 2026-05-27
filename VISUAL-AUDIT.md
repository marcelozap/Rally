# Visual Audit

Scope: `Rally/Features/**` and `Rally/Utilities/RallyUIKit.swift`

Note: `POLISH.md` was not present in the repo root during this pass, so this audit was completed from the prompt scope only. No UI code was changed in this task.

## Executive Summary

The app does not have a single obvious "ugly component" problem. It has a consistency problem.

The current feel comes from:

- too many color expressions in active use
- too many one-off font declarations
- too many radius and spacing values
- several major screens still styling themselves directly instead of relying on shared system components

The good news is that there is already a usable foundation in [`Rally/Utilities/RallyUIKit.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Utilities/RallyUIKit.swift). The bad news is that the foundation is not yet authoritative enough, and some of the largest screens still behave like their own design systems.

## High-Level Counts

- Audited files: `22`
- Unique color expressions found: `58`
- Unique font expressions found: `53`
- Practical corner-radius values in use: `11`
- Distinct shadow expressions found: `14`

Verdict: this is too much variance for a premium consumer app.

## Colors

### What I found

The palette is currently split across:

- shared semantic tokens in `RallyUIKit.Palette`
- direct platform colors like `.white`, `.black`, `.cyan`, `.pink`, `.yellow`
- custom literals such as `Color(red: ...)`, `UIColor(red: ...)`
- feature-driven dynamic colors like `Color(hex: metadata.color)` and `Color(hex: challenge.colorHex)`

### Most used color expressions

- `.white`: `301`
- `RallyUIKit.Palette.cyan`: `66`
- `.cyan`: `61`
- `.black`: `34`
- `RallyUIKit.Palette.gold`: `28`
- `.clear`: `20`
- `RallyUIKit.Palette.rose`: `19`
- `.pink`: `17`
- `.yellow`: `14`
- `.green`: `11`
- `RallyUIKit.Palette.champagne`: `10`

### Why this feels inconsistent

- The app is mixing semantic palette tokens with raw SwiftUI colors constantly.
- There are duplicate intentions expressed two ways, especially around cyan, gold, pink, white, and black.
- Dynamic hex colors are useful for content, but they are currently sitting beside a very noisy base UI palette.
- Several screens still use "accent by intuition" rather than a small controlled token set.

### Biggest color offenders

- [`Rally/Features/Home/HomeView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Home/HomeView.swift): `83` color references
- [`Rally/Features/Competition/CompetitionViews.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Competition/CompetitionViews.swift): `69`
- [`Rally/Utilities/RallyUIKit.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Utilities/RallyUIKit.swift): `60`
- [`Rally/Features/Play/GameOverView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Play/GameOverView.swift): `56`
- [`Rally/Features/Courts/CourtsMapView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Courts/CourtsMapView.swift): `54`

## Typography

### What I found

Typography is heavily fragmented. The app uses:

- direct `.font(.caption)`, `.font(.headline)`, `.font(.subheadline)` calls
- many `.system(... design: .rounded)` one-offs
- some serif display usage through `RallyUIKit.Typography`
- a few direct numeric font sizes like `9`, `17`, `24`, `30`, `92`

### Most used font expressions

- `.caption`: `35`
- `.system(.caption, design: .rounded)`: `23`
- `.caption.weight(.semibold)`: `17`
- `.system(.headline, design: .rounded)`: `16`
- `.system(.subheadline, design: .rounded)`: `15`
- `.caption.weight(.bold)`: `15`
- `.headline`: `14`
- `.caption2`: `12`
- `.subheadline`: `11`
- `.system(.title3, design: .rounded)`: `10`

### Why this feels inconsistent

- There is no tight type scale yet.
- Rounded, serif, and default system text are all present, but not always intentionally.
- A premium brand can absolutely mix serif display with clean utility text, but it needs much stronger rules than Rally currently has.

### Biggest typography offenders

- [`Rally/Features/Home/HomeView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Home/HomeView.swift): `47` font declarations
- [`Rally/Features/Competition/CompetitionViews.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Competition/CompetitionViews.swift): `45`
- [`Rally/Features/Courts/CourtDetailView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Courts/CourtDetailView.swift): `24`
- [`Rally/Features/Journal/JournalView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Journal/JournalView.swift): `22`
- [`Rally/Features/Courts/CourtsMapView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Courts/CourtsMapView.swift): `20`
- [`Rally/Features/Shop/ShopItemDetailView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Shop/ShopItemDetailView.swift): `20`

## Corner Radius

### Practical radius values in use

After filtering out obvious parser noise from non-radius decimals, the app is effectively using:

- `4`
- `6`
- `10`
- `12`
- `14`
- `16`
- `18`
- `20`
- `22`
- `24`
- `34`

### Most common

- `14`: `37`
- `16`: `23`
- `12`: `21`
- `18`: `14`

### Verdict

This is too many radii for a product that wants to feel premium and intentional. There is some clustering, but not enough discipline.

## Shadows

### What I found

There are `14` distinct shadow expressions, most of them lightly different versions of:

- black shadows with different opacities
- accent-colored glow shadows
- button press-state shadow variants

### Most common shadow forms

- `color: .black.opacity(0.35...)`
- `color: Color.black.opacity(0.22...)`
- `color: Color.black.opacity(0.24...)`
- `color: Color.black.opacity(0.16...)`
- `color: Color.black.opacity(0.14...)`
- `color: Color.black.opacity(0.12...)`

### Verdict

The shadow language is not wild, but it is not standardized. It feels accumulated rather than designed.

## Spacing and Padding

### Most common spacing values

- `12`: `92`
- `8`: `73`
- `10`: `60`
- `16`: `49`
- `14`: `48`
- `4`: `43`
- `6`: `42`
- `18`: `22`
- `20`: `19`
- `24`: `11`

### Drift values also in active use

- `2`
- `3`
- `5`
- `7`
- `9`
- `13`
- `17`
- `22`
- `28`
- `30`
- `32`
- `34`
- `36`
- `40`

### Verdict

This is not complete chaos, but it is not clean enough either.

There is a visible near-scale around:

- `4`
- `6`
- `8`
- `10`
- `12`
- `14`
- `16`
- `18`
- `20`
- `24`

But the drift values are frequent enough that the app still reads as manually tuned screen-by-screen instead of system-designed.

## Shared System Reuse vs Hardcoded Styling

### Stronger reuse

These screens do use shared system pieces such as `RallyUIKit`, shared button styles, or shared modifiers:

- [`Rally/Features/Auth/AuthView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Auth/AuthView.swift)
- [`Rally/Features/Avatar/AvatarCustomizerView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Avatar/AvatarCustomizerView.swift)
- [`Rally/Features/Avatar/AvatarView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Avatar/AvatarView.swift)
- [`Rally/Features/Courts/CourtDetailView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Courts/CourtDetailView.swift)
- [`Rally/Features/Courts/CourtsMapView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Courts/CourtsMapView.swift)
- [`Rally/Features/Home/HomeView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Home/HomeView.swift)
- [`Rally/Features/Journal/JournalView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Journal/JournalView.swift)
- [`Rally/Features/Logs/LogsView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Logs/LogsView.swift)
- [`Rally/Features/Match/MatchEditorView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Match/MatchEditorView.swift)
- [`Rally/Features/Match/MatchLogView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Match/MatchLogView.swift)
- [`Rally/Features/Play/GameOverView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Play/GameOverView.swift)
- [`Rally/Features/Play/GameSessionView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Play/GameSessionView.swift)
- [`Rally/Features/Shop/ShopItemDetailView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Shop/ShopItemDetailView.swift)
- [`Rally/Features/Shop/ShopView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Shop/ShopView.swift)
- [`Rally/Features/Training/TrainingEditorView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Training/TrainingEditorView.swift)
- [`Rally/Features/Training/TrainingLogView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Training/TrainingLogView.swift)

### Hardcoded or weak reuse

These are still much more self-styled or do not meaningfully rely on the shared UI system:

- [`Rally/Features/Competition/CompetitionViews.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Competition/CompetitionViews.swift)
- [`Rally/Features/Journal/JournalEditorView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Journal/JournalEditorView.swift)
- [`Rally/Features/Avatar/Avatar3DModels.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Avatar/Avatar3DModels.swift)
- [`Rally/Features/Avatar/AvatarRealityKitView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Avatar/AvatarRealityKitView.swift)
- [`Rally/Features/Shop/AvatarShopStageView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Shop/AvatarShopStageView.swift)

### Biggest screen-level risk

Even among screens that do reuse shared components, some still carry too many local overrides. The biggest examples are:

- [`Rally/Features/Home/HomeView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Home/HomeView.swift)
- [`Rally/Features/Play/GameOverView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Play/GameOverView.swift)
- [`Rally/Features/Courts/CourtsMapView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Courts/CourtsMapView.swift)

So the problem is not just "shared vs hardcoded." It is also "shared system exists, but is still too easy to override locally."

## Screens Most Responsible for the Amateur Feel

If I had to name the highest-impact files to normalize first:

1. [`Rally/Features/Competition/CompetitionViews.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Competition/CompetitionViews.swift)
Reason: huge variance, no meaningful shared-system authority.

2. [`Rally/Features/Home/HomeView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Home/HomeView.swift)
Reason: very high visual density, too many local decisions for the flagship surface.

3. [`Rally/Features/Play/GameOverView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Play/GameOverView.swift)
Reason: important screen, still highly customized even after recent polish.

4. [`Rally/Features/Courts/CourtsMapView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Courts/CourtsMapView.swift)
Reason: content-rich and visually busy, so inconsistency becomes obvious fast.

5. [`Rally/Features/Journal/JournalEditorView.swift`](/Users/a14/Documents/New%20project/Rally/Rally/Features/Journal/JournalEditorView.swift)
Reason: weak shared reuse and enough one-off layout/styling to feel older than the rest of the app.

## Bottom Line

The app already has the beginnings of a premium visual direction, but it is not yet acting like one system.

Current state:

- base direction: promising
- consistency: weak
- token discipline: weak
- screen-to-screen cohesion: uneven
- shared component authority: improving, but not strong enough

If Task 1 is the token-definition pass, the right move is not "pick prettier colors." The right move is to drastically reduce degrees of freedom:

- fewer base colors
- one explicit typography ladder
- a tight radius scale
- a tight spacing scale
- a very small shadow system
- a rule that key surfaces stop hardcoding local styling unless there is a clear content reason
