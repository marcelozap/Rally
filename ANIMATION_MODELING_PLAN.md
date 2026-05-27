# Animation + Modeling Plan

This document defines the next polish layer after UI consistency: the craft of how Rally looks and moves in the live game experience.

`POLISH.md` covers app-system quality.
This file covers motion quality, character quality, materials, and presentation quality inside the playable world.

## Goal

Rally should not feel like a prototype with tennis theming.

It should feel like a modern, premium sports product where the player, racquet, court, ball, and feedback all belong to the same visual language.

The core target is:

- readable at speed
- believable enough to feel physical
- stylish enough to feel current
- restrained enough to avoid arcade-cheap motion

## What This Track Owns

This plan covers:

- avatar silhouette and proportions
- racquet and gear model quality
- animation quality and responsiveness
- body mechanics and footwork readability
- court/world materials and depth
- transitions, impact feel, and motion finish

This plan does not replace gameplay tuning or UI-system work. It sits on top of them.

## Quality Bar

When this work is succeeding, the player should feel:

- the avatar has weight
- swings have intention
- recovery has consequence
- the court has atmosphere
- hits feel authored, not accidental
- the whole play session looks like one shipped product

## Main Problem To Solve

Older-feeling sports apps usually break in the same places:

- stiff or generic character motion
- weak silhouette and proportions
- no convincing weight transfer
- placeholder materials
- flat court presentation
- feedback that is loud but not elegant

If Rally still feels “student project,” it will usually be because one of those is still visible.

## Three Lanes

### 1. Character Modeling

Make the player look premium before they even move.

Focus:

- stronger silhouette
- cleaner athletic proportions
- better hand/racquet readability
- less placeholder-feeling face/hair/clothing forms
- clear outfit layering that reads well on phone screens

### 2. Animation

Make the player motion feel intentional and responsive.

Focus:

- anticipation
- contact clarity
- follow-through
- recovery
- lateral movement
- idle life
- transitions between all of those states

### 3. World Presentation

Make the court and feedback feel current.

Focus:

- better court depth
- lighting and material separation
- more premium ball/hit effects
- stronger between-state transitions
- more controlled camera composition

## Modeling Direction

### Avatar Art Direction

The avatar should read as:

- athletic
- aspirational
- stylish
- contemporary

Avoid:

- toy-like proportions
- exaggerated mobile-game caricature
- muddy clothing forms
- over-detailed realism that clashes with the rest of the app

Best target: stylized premium realism.

That means:

- clean forms
- strong silhouette
- simplified facial detail
- believable materials
- readable body posture

### Silhouette Priorities

From gameplay distance, the player should clearly read:

- stance
- swing side
- recovery direction
- whether they are balanced or stretched

If the silhouette cannot tell that story, extra texture detail will not save it.

### Racquet Quality

The racquet matters more than many other props because it is central to feel.

Improve:

- frame silhouette
- string-bed readability
- grip proportion
- contact-point clarity against the ball

The racquet should not look like a generic flat accessory. It should feel like a tuned instrument.

### Outfit Direction

Outfits should support the “premium tennis lifestyle” brand:

- sharp base shapes
- limited color blocking
- clean trims
- modern athletic materials

Avoid noisy patterns unless they are intentionally hero cosmetics.

## Animation Direction

### Motion Principles

Every shot should communicate:

1. preparation
2. commitment
3. contact
4. follow-through
5. recovery

If one of those phases is missing, the swing will feel cheap even if it is technically responsive.

### Highest-Value Animation Improvements

1. Better split-step / ready stance behavior before incoming balls.
2. Cleaner weight shift into forehand and backhand contact.
3. Stronger distinction between clean, jammed, stretched, and defensive contact.
4. Better lateral recovery after wide balls.
5. More believable transition back to center after off-balance shots.
6. Stronger idle and between-point life so the avatar never looks frozen.

### Contact States To Differentiate

Rally will feel much more advanced if contact states animate differently:

- clean balanced drive
- late jammed contact
- wide stretch forehand
- wide stretch backhand
- defensive block
- slice carve
- topspin lift
- mishit / off-center contact

This is a major maturity jump because it turns animation into gameplay readability, not decoration.

### Footwork Priorities

Footwork is one of the biggest realism multipliers.

Add or improve:

- ready bounce / split-step
- first push step into wide movement
- plant before contact
- crossover or side-shuffle recovery
- slight stumble or drag on bad recovery

The feet do not need full sim realism. They need to tell the truth about balance.

### Recovery Animation

Recovery should be visually tied to the engine state.

Good recovery:

- recenters quickly
- restores upright posture
- restores racquet readiness

Bad recovery:

- leaves the player hanging wide
- reduces reach clarity
- shows slower re-centering
- visibly exposes the next side

This is one of the best places to make the game feel “new.”

## Presentation and Effects

### Court Presentation

The court should feel like a designed stage, not just a gameplay surface.

Improve:

- baseline and service-box readability
- subtle reflections or finish variation
- better separation between playable floor and background
- stronger horizon/depth treatment
- more premium color grading

### Lighting Direction

Lighting should support depth and quality without becoming flashy.

Target:

- clear character separation from court
- readable ball tracking
- subtle specular hits on racquet and shoes
- soft atmospheric falloff in the environment

Avoid flat even lighting across everything.

### Ball Readability

The ball must stay readable first, stylish second.

Improve:

- contact flash quality
- motion trail quality
- bounce readability
- depth cueing during travel

If the ball gets harder to track while becoming prettier, it is a failed polish pass.

### Hit Effects

Hit effects should feel premium, not noisy.

Preferred language:

- fast clean energy rings
- directional streaks
- restrained glow
- material-aware spark bursts

Avoid:

- giant random particles
- muddy bloom
- effects that hide contact timing

## State Transitions

Transitions are a major source of “shipped product” feel.

Important transitions:

- menu to match start
- countdown to live play
- hit pause back into motion
- combo rise
- miss / break
- point end
- game over

Each should have controlled timing and clear visual hierarchy.

## Priority Build Order

If we want the highest-impact sequence, do it in this order:

1. Improve swing and recovery animation states.
2. Improve avatar silhouette and racquet readability.
3. Improve court lighting and depth.
4. Improve hit effects and contact feedback.
5. Improve idle, between-point, and transition motion.
6. Improve outfit/material quality and cosmetic finish.

## First Implementation Pass

The first practical pass should focus on visible wins that change feel quickly:

1. Define 4-6 core gameplay poses:
   - ready
   - forehand clean
   - backhand clean
   - wide stretch
   - defensive block
   - recovery
2. Make recovery visually reflect gameplay penalties already in the engine.
3. Improve racquet-body sync so the racquet does not feel detached from the swing.
4. Add stronger depth separation between player, ball, and court.
5. Replace any placeholder-feeling hit effects with a smaller premium effect family.

## Review Checklist

When reviewing animation or modeling work, ask:

1. Does the player look premium before moving?
2. Can I tell balanced vs. stretched contact instantly?
3. Does the swing have anticipation, contact, and follow-through?
4. Does recovery visually match gameplay consequences?
5. Is the racquet easy to read at full game speed?
6. Does the ball remain clear during the prettiest effects?
7. Does the court feel like part of a branded product, not a default background?
8. Would a short muted gameplay clip look current to a new player?

## Anti-Goals

Do not turn this into:

- a hyper-real tennis sim
- a noisy arcade VFX demo
- a heavy 3D pipeline that the rest of the app cannot support
- animation complexity that hurts responsiveness

The target is premium stylized responsiveness.

## Definition of Done

This lane is working when:

- the avatar silhouette reads clearly at gameplay distance
- swings feel different based on contact state
- recovery and balance are visually honest
- the court has more depth and atmosphere
- hit effects feel authored and consistent
- muted gameplay footage looks current instead of prototype-grade
