# Getting your real proportions in

Right now `reference.py` uses Winter's anthropometric fractions — population
averages for a given stature. They're close enough to be legible and wrong enough
that they aren't *yours*. Two people at 178cm can differ by 4–5cm in femur length,
which changes optimal squat depth, saddle height and stride mechanics.

Two ways to fix that. **The tape measure is more accurate than anything I can
extract from video**, and it takes two minutes.

## Option A — tape measure (better)

Stand barefoot against a wall. Measure in centimetres:

| # | Measurement | How |
|---|---|---|
| 1 | **Height** | floor to top of head, heels against the wall |
| 2 | **Femur** | side of hip (the bony bump — greater trochanter) down to the knee joint crease |
| 3 | **Shank** | knee joint crease down to the floor |
| 4 | **Shoulder width** | across the back, bony point of one shoulder to the other |
| 5 | **Arm upper** | shoulder point to elbow crease |
| 6 | **Arm lower** | elbow crease to wrist crease |
| 7 | **Inseam** | floor to crotch, standing, book pulled up firmly (this is the one bike fit uses) |

Send those seven numbers and the reference figure becomes your skeleton.

## Option B — one photo, no tape

One standing photo, front-on, **filling the frame** (head near the top edge, feet
near the bottom), arms slightly away from your sides, wearing something fitted.
Plus your height. That's enough to solve the segment lengths from pose.

The framing is the whole trick — the same reason your tennis clip couldn't be
measured. At 10% of frame height the landmark error is bigger than the segments.

## What changes once it's in

- The reference animations get your femur:shank ratio, not an average one
- Saddle height gets computed from your inseam rather than a fraction of stature
- Every metric that is normalised "% of leg length" gets a real denominator
- The universal checks stay identical — those are the ones that don't depend on you
