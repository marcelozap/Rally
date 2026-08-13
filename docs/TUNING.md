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

## Known weaknesses

- **Camera angle dominates everything.** Elbow angle from side-on and from behind
  are different measurements. Until `config/cameras.yaml` calibration is
  implemented, only compare clips shot from the same position.
- **Normalised units are not metres.** `com_lateral_range` of 0.03 means 3% of
  frame width — that changes meaning when you step closer to the camera.
- **Handedness detection is total wrist travel.** A two-handed backhand will
  confuse it.
- **Serve detection is "wrist above nose."** A high forehand volley trips it.
