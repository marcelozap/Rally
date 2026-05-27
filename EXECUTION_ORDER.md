# Rally Execution Order

This file turns the three Rally polish plans into one practical implementation sequence.

- `POLISH.md` owns UI/system consistency.
- `PRESENTATION_PLAN.md` owns live match presentation and pacing.
- `ANIMATION_MODELING_PLAN.md` owns avatar, racquet, motion, and court craft.

The goal is to remove the "prototype" feeling in the fastest possible order without spreading work randomly across the app.

## Guiding Principle

Always polish the part of Rally the player feels most strongly first.

That means:

1. live match presentation
2. gameplay silhouette / animation readability
3. highest-variance app screens
4. secondary content surfaces

If a pass does not make gameplay or the most visible product surfaces feel more shipped, it should wait.

## Phase 1: Live Match Presentation

This is the first priority because it is the fastest way to remove the "old prototype inside a nicer shell" feeling.

Primary files:

- `Rally/Game/GameScene.swift`
- `Rally/Features/Play/GameSessionView.swift`
- `Rally/Features/Play/GameOverView.swift`
- `Rally/Game/Tunables.swift`

Execution order:

1. Simplify and restyle the live HUD.
2. Improve countdown-to-play transition.
3. Refine hit feedback into a smaller premium effect family.
4. Tighten combo rise / combo break presentation.
5. Improve game-over entry pacing and match-end payoff.
6. Add court depth and atmosphere only after readability stays strong.

Success signal:

- muted gameplay already looks current
- center play space is cleaner
- match start and match end feel authored
- hits feel premium without getting louder

## Phase 2: Animation + Modeling Readability

This phase starts immediately after the match presentation baseline is stronger.

Primary files:

- `Rally/Game/GameScene.swift`
- `Rally/Game/Tunables.swift`
- `Rally/Features/Avatar/AvatarView.swift`
- `Rally/Features/Avatar/AvatarRealityKitView.swift`

Execution order:

1. Improve ready stance and split-step behavior.
2. Differentiate clean, stretched, jammed, and defensive contacts.
3. Improve racquet silhouette and string-bed readability.
4. Improve recovery honesty and return-to-center motion.
5. Improve court/player/ball depth separation.
6. Improve outfit/material finish last.

Success signal:

- the avatar reads clearly at gameplay distance
- forehand/backhand/stretch/recovery are instantly recognizable
- the racquet feels like a central gameplay object, not an accessory

## Phase 3: System Polish On High-Visibility Screens

After the match looks modern, tighten the rest of the app to the same quality bar.

Primary files:

- `Rally/Features/Home/HomeView.swift`
- `Rally/Features/Competition/CompetitionViews.swift`
- `Rally/Features/Play/GameOverView.swift`
- `Rally/Utilities/RallyUIKit.swift`

Execution order:

1. Tighten shared tokens and reusable surfaces in `RallyUIKit`.
2. Polish Home.
3. Polish Competition.
4. Recheck Game Over for consistency against the live match tone.

Success signal:

- more shared styling, fewer raw values
- cleaner hierarchy
- less palette noise
- screens feel like one product family

## Phase 4: Discovery Surfaces

Once the core game and shell are strong, move to the content-heavy discovery screens.

Primary files:

- `Rally/Features/Courts/CourtsMapView.swift`
- `Rally/Features/Courts/CourtDetailView.swift`
- `Rally/Features/Shop/ShopItemDetailView.swift`
- `Rally/Features/Journal/JournalView.swift`

Execution order:

1. Courts map filters, search, and result hierarchy.
2. Court detail structure and premium information layout.
3. Shop item detail hierarchy and product storytelling.
4. Journal surface clarity and typography rhythm.

Success signal:

- discovery screens feel premium, not utility-first
- content is easier to scan
- visuals stay branded without becoming noisy

## Phase 5: Secondary Utility Screens

Only after the product-defining surfaces are strong should we spend time on lower-visibility screens.

Examples:

- logs
- training editors
- match editors
- smaller detail and settings-style screens

## Current Recommended Focus

Right now the best next implementation pass is:

1. `GameScene.swift`: simplify HUD and improve countdown/live hierarchy
2. `GameSessionView.swift`: reduce shell-vs-scene mismatch and tighten session chrome
3. `GameOverView.swift`: keep payoff pacing aligned with the new match presentation

That is the highest-leverage sequence for making Rally feel like a shipped product instead of a promising prototype.

## Rules While Executing

- Keep one primary lane active at a time.
- Do not jump to low-visibility screens while gameplay presentation still feels dated.
- Prefer shared systems over one-off styling.
- Protect readability before adding atmosphere.
- Treat build verification separately from visual judgment when the current SwiftData plugin environment is unstable.
