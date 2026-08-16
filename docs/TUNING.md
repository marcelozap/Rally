# Tuning the advice thresholds

Every threshold in `advice/rules.py` is a first-draft guess. Nothing here has
been calibrated against real footage. Publishing untuned coaching advice is
worse than publishing none — it teaches people the wrong thing confidently.

## Procedure

1. Record 10–15 clips: a mix of shots you know are good and shots you know are bad.
2. Label each one yourself first — write down what's actually wrong, before running anything.
3. `rally-coach analyze` each clip and dump the metrics.
4. Build the distribution per metric across good vs bad. The threshold goes where
   the two separate, not at a round number that looks tidy.
5. Record the sample size and date next to each constant when you change it.

## Calibrate smoothing BEFORE thresholds

The order matters and it is not obvious. `tracking/smoothing.py` runs before
`events/swing.py`, so every speed the detector sees has already been attenuated.
Tune a speed floor against raw footage and it will be roughly twice too high.
Measure the retention first (see the first known weakness below), fix the
smoothing constants, and only then start step 1.

## Known weaknesses

- **The smoothing eats the signal the detector thresholds against.** Measured
  2026-08-13 on the synthetic fixture (`tests/fixtures/synthetic.py`, 60fps,
  n=1 scripted clip): the shipped One Euro constants (`min_cutoff: 1.0`,
  `beta: 0.007`) retain only **44%** of peak wrist speed. A swing peaking at
  3.8 normalised units/s arrives at `detect_swings` as 1.7 — under the shipped
  `min_wrist_speed: 2.5` — so **zero swings are detected and the whole pipeline
  silently returns nothing**. The adaptive term is inert at this beta:
  `beta * |dx|` is ~0.03 even mid-swing, so the cutoff never lifts off its 1.0Hz
  floor and the filter behaves like a fixed, very heavy lowpass. For reference,
  `min_cutoff: 6.0` / `beta: 0.05` retained 89% on the same fixture — a starting
  point, not a recommendation; confirm against real footage.
  Regression test: `test_shipped_smoothing_preserves_the_contact_spike`
  (xfail-strict today — delete the marker once it passes).
- **Camera angle dominates everything.** Elbow angle from side-on and from behind
  are different measurements. Until `config/cameras.yaml` calibration is
  implemented, only compare clips shot from the same position.
- **Normalised units are not metres.** `com_lateral_range` of 0.03 means 3% of
  frame width — that changes meaning when you step closer to the camera.
- **Handedness detection is total wrist travel.** A two-handed backhand will
  confuse it.
- **Serve detection is "wrist above nose."** A high forehand volley trips it.
