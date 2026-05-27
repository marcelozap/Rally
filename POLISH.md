# POLISH

This file defines the product-polish direction for the Rally app so UI cleanup work can be judged against a shared standard instead of screen-by-screen taste.

## Goal

Rally should feel premium, sporty, fast, and cohesive.

The app should not read as a collection of individually styled SwiftUI screens. It should feel like one product with one visual system.

## Product Feel

The target feel is:

- Premium, not flashy
- Athletic, not aggressive
- Playful, not childish
- Clean, not sterile
- Branded, not overdesigned

## What "Polish" Means Here

Polish in Rally is mostly consistency, restraint, and hierarchy.

A polished screen should have:

- a clear focal point
- consistent spacing rhythm
- predictable corner-radius usage
- limited accent colors
- intentional typography hierarchy
- shared component behavior across features

## Core Rules

### 1. Prefer shared tokens over raw styling

Use shared `RallyUIKit` colors, typography, spacing, radius, and shadows wherever possible.

Avoid introducing new one-off values unless the screen truly needs a new system token.

### 2. Reduce palette noise

Accent color should feel deliberate.

Avoid mixing semantic palette tokens with many raw colors like `.cyan`, `.pink`, `.yellow`, `.white`, and custom literals in the same screen unless the content itself requires it.

### 3. Tighten typography

Typography should follow a small repeatable scale.

Avoid stacking many ad hoc `.system(... design: .rounded)` variants and arbitrary numeric sizes when an existing type role can do the job.

### 4. Simplify radii and spacing

The UI should feel built from a recognizable system, not tuned by hand everywhere.

Prefer a compact set of spacing and radius values and reuse them aggressively.

### 5. Let components carry the brand

Buttons, cards, pills, section headers, stat blocks, and empty states should get their character from shared components instead of repeated local modifiers.

### 6. Preserve speed

Polish should not make the app feel heavier.

Views should remain readable, tappable, and quick to scan, especially on the Home and Play-adjacent surfaces.

## Priority Areas

The first polish passes should focus on the screens with the highest visual variance and the most user visibility:

1. `Rally/Features/Home/HomeView.swift`
2. `Rally/Features/Competition/CompetitionViews.swift`
3. `Rally/Features/Play/GameOverView.swift`
4. `Rally/Features/Courts/CourtsMapView.swift`
5. `Rally/Features/Courts/CourtDetailView.swift`
6. `Rally/Features/Journal/JournalView.swift`
7. `Rally/Features/Shop/ShopItemDetailView.swift`

## Token Direction

Until the shared system is tightened further, use this as the default direction:

- Color: semantic palette first, raw color literals last
- Type: one display voice plus one utility voice
- Radius: small, medium, large system steps only
- Spacing: a compact scale reused everywhere
- Shadow: one subtle depth family plus one branded glow family

## Screen Review Checklist

When polishing a screen, check:

1. Does this screen look like Rally immediately?
2. Are there raw colors here that should be semantic tokens?
3. Are there one-off font declarations that should be shared styles?
4. Are spacing and radii repeating a system or drifting?
5. Are buttons and cards using shared component patterns?
6. Is the most important action obvious within three seconds?
7. Would removing one decorative treatment make the screen stronger?

## Anti-Goals

Do not polish Rally into:

- a generic startup app
- a neon overload sports app
- a luxury app that loses energy
- a minimal app with no personality

The goal is discipline, not blandness.

## Definition of Done for a Polish Pass

A polish task is successful when:

- the screen uses more shared system styling than before
- visual variance goes down without flattening the brand
- hierarchy becomes easier to scan
- no feature behavior regresses
- the result feels more intentional at a glance
