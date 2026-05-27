# Presentation Plan

This document covers the polish layer between UI consistency and animation/modeling quality: how Rally presents the live match moment to moment.

`POLISH.md` is about app-system coherence.
`ANIMATION_MODELING_PLAN.md` is about character, motion, and asset craft.
This file is about the live playable experience as a designed performance.

## Goal

Rally should feel current the second gameplay starts.

The match should not read like a raw SpriteKit prototype inside a nicer app shell. It should feel like the most intentional and premium part of the product.

The target is:

- immediate readability
- premium pacing
- clean hierarchy
- physical impact
- modern restraint

## What This Track Owns

This plan covers:

- in-match HUD behavior
- camera composition
- court framing and depth
- state transitions
- hit feedback hierarchy
- combo and score presentation
- countdown, pause, break, and game-over flow
- how all of those feel together in motion

## Core Principle

Presentation is where mechanics become product.

Even when the engine is good, the game will still feel old if:

- the HUD is noisy
- transitions are abrupt or flat
- the court reads as depthless
- feedback layers compete instead of supporting each other
- the screen never establishes a premium rhythm

## Experience Goal

A new player should feel three things quickly:

1. This is clean and easy to read.
2. This feels responsive and satisfying.
3. This looks more expensive than a typical mobile side project.

## Presentation Pillars

### 1. Readability First

The player must always understand:

- where the ball is
- when contact matters
- what their current state is
- whether they are succeeding or breaking down

If an effect makes this less clear, it is not polish.

### 2. Impact With Restraint

Hits should feel sharp and premium, not chaotic.

We want:

- weight
- speed
- clarity
- rhythm

We do not want:

- clutter
- oversized arcade flash
- constant on-screen noise

### 3. Premium Rhythm

The screen should breathe.

Quiet moments need restraint.
Big moments need escalation.
State changes need timing.

Without rhythm, even good visuals feel cheap.

### 4. One Visual Hierarchy

At any moment, the screen should have one dominant focus:

- the incoming ball
- the moment of contact
- the combo rise
- the break / miss
- the end-state result

Everything else should support that focus, not compete with it.

## HUD Direction

### Target Feel

The HUD should feel modern, light, and editorial.

It should not feel like:

- debug labels
- floating prototype text
- score widgets added one by one

### HUD Priorities

Show only what matters during live play:

- score or run value
- combo
- momentum / streak state
- maybe one secondary performance metric

Everything else should be minimized, delayed, contextual, or moved out of the main action area.

### HUD Rules

- Keep the center play field clean.
- Use stable anchors for recurring information.
- Avoid multiple competing accent colors in the same HUD state.
- Treat combo as a hero moment only when it meaningfully rises.
- Make support information quieter than gameplay-critical information.

## Camera and Framing

### Goal

The camera should make the court feel intentional, not merely visible.

### Priorities

- clearer depth between foreground, player, ball, and background
- stronger framing of the contact zone
- more premium sense of stage composition
- subtle reactive movement only where it improves feel

### Direction

Prefer:

- controlled parallax
- subtle zoom or emphasis at high-momentum moments
- slight framing shifts that support motion direction

Avoid:

- excessive shake
- constant camera drift
- aggressive zooms that hurt ball tracking

## Court and World Readability

The court should feel like a designed arena for play.

Upgrade:

- visual separation between lines, surface, and outer space
- horizon or background treatment
- tonal depth
- subtle environmental atmosphere

The world should help sell focus and speed without distracting from the ball.

## State Transitions

Transitions are one of the biggest “new app vs old app” signals.

### Key Transitions To Design

- home/play shell into active match
- pre-match loading into countdown
- countdown into first live ball
- live rally into combo surge
- combo break into recovery state
- match end into game over
- reward reveal into return-to-shell

### Rules

- Transitions should have a clear beginning and end.
- Timing should feel deliberate, not default.
- Each transition should change hierarchy, not just animate opacity.
- Repeated transitions should remain fast and not feel heavy.

## Hit Feedback Hierarchy

When contact happens, the screen should clearly communicate:

1. was the shot good?
2. how strong was the contact?
3. what happened to the rally state?

Feedback layers can include:

- hit pause
- contact flash
- ball trail change
- directional streak
- combo text
- haptic/audio sync

But they must feel like one event, not stacked unrelated effects.

## Combo and Momentum Presentation

Combo should feel earned, not always-on.

Improve:

- how combo rises visually
- how tier thresholds feel special
- how combo break feels sharp without being melodramatic
- how momentum is visible before the player consciously reads numbers

Consider using:

- progressive scale and emphasis
- controlled glow increase
- more distinct tier identity
- different pacing for climb versus collapse

## Countdown, Pause, and End States

These states often expose prototype-quality quickly.

### Countdown

Should feel cinematic and confident, not like temporary text on top of gameplay.

### Pause / Break

Should preserve mood and hierarchy rather than freezing into a crude overlay.

### Game Over

Should feel like a designed payoff sequence, not a sudden context switch.

## Audio-Visual Sync

Presentation quality depends heavily on sync.

The game should feel like:

- hits land exactly when visuals peak
- combo rises align with soundtrack lift
- breaks collapse both sound and screen energy together

If those layers feel separate, the game will still read as older.

## First Practical Improvements

If we want the fastest visible gains, do this first:

1. Simplify and restyle the live HUD.
2. Improve countdown-to-play transition.
3. Refine hit feedback into a smaller, more premium effect family.
4. Improve game-over entry and payoff pacing.
5. Add more depth and atmosphere to the court presentation.
6. Make combo tiers feel more authored and less like text increments.

## Review Checklist

When reviewing presentation work, ask:

1. Does gameplay look premium with the sound off?
2. Is the ball always easy to track?
3. Is the HUD cleaner than before?
4. Do transitions feel authored, not default?
5. Do hits feel strong without becoming noisy?
6. Does combo presentation escalate elegantly?
7. Does the game-over flow feel like a payoff, not a dump of info?
8. Does the match now feel like the strongest part of the app?

## Anti-Goals

Do not turn presentation polish into:

- constant effects spam
- over-animated HUD chrome
- fake-premium blur overload
- camera behavior that harms readability
- slow transitions that interrupt fast repeat play

The target is confident, fast, premium presentation.

## Definition of Done

This lane is succeeding when:

- the live match looks modern immediately
- the HUD feels minimal but sufficient
- transitions have clear rhythm
- contact feedback is elegant and readable
- combo and breaks feel emotionally legible
- short muted clips of gameplay look launch-ready instead of prototype-grade
