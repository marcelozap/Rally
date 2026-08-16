# Development plan — coaching, calibrated on one player

Scope decision, stated up front so it does not get lost: **v1 is a coach for you
and nobody else.** Thresholds calibrated on your footage, your camera position,
your body. That is not a limitation to apologise for — it is what makes the
thing achievable, and it is the only honest way to ship advice at n=1. When a
threshold in `advice/rules.py` is tuned, the comment next to it says whose
footage tuned it and how many clips. Anything calibrated on you is not
generalisable to another player until it has been re-measured on them.

The bottleneck is **not code**. Every remaining item — thresholds, swing
classification, court calibration — is blocked on footage that does not exist
yet. Phase 1 is filming, and you can do it without a coding session. Do it first
and the rest has something to run against.

---

## Phase 0 — unblock the detector · half a session

`config/pipeline.yaml` currently smooths away 56% of peak wrist speed and then
thresholds against a floor that assumes raw speed, so `detect_swings` returns
nothing. Details and numbers: `docs/TUNING.md`. Procedure: `docs/NEXT_SESSION.md`.

**Done when:** `test_shipped_smoothing_preserves_the_contact_spike` passes and
its `xfail` marker is deleted. Nothing downstream is worth doing before this.

---

## Phase 1 — capture protocol · one afternoon on court, no coding

This phase decides how good everything after it can be. `docs/TUNING.md` already
says camera angle dominates every measurement; the way you beat that is not
cleverness later, it is **filming the same way every single time**.

### The rig

| | | why |
|---|---|---|
| **Position** | Side-on, perpendicular to your hitting direction | Elbow and knee angles are only meaningful in the camera plane. Shot from behind, the same swing measures differently. |
| **Height** | Net-post height (~1.07m), on a tripod | A phone on the ground looking up compresses vertical relationships and wrecks the "wrist above nose" serve test. |
| **Distance** | 6–8m back, landscape | Far enough that your racket hand at full extension and both feet stay in frame through the follow-through. |
| **Framing** | You fill ~60–70% of frame height | Bigger is better for landmark precision, right up until a limb leaves the frame. |
| **Frame rate** | 60fps minimum, 120fps if your phone offers it | At 30fps contact is 2–3 frames and peak wrist speed is badly undersampled — you would be tuning against an artefact. |
| **Light** | Bright, sun behind the camera | Short exposure means less motion blur on the wrist. Dusk footage loses the racket hand at exactly the frame that matters. |
| **Background** | Nobody moving behind you | The pose backend tracks one person and will happily jump to a passerby mid-swing. |
| **Clothing** | Contrasting with the court, short sleeves | Sleeve over the elbow is a real landmark killer. |

**Mark the tripod spot.** Chalk, a bag, a court line — anything you can
reproduce. Every future session films from that spot. The moment the camera
moves, the thresholds calibrated before it stop meaning what they meant.
`config/cameras.yaml` is stubbed for recording this; fill it in with the spot,
height, and phone model the day you first film.

### What to shoot

One shot per clip, 3–8 seconds. Not rallies — a rally clip makes labelling
ambiguous, and ambiguous labels are worse than no labels.

| shot | good | deliberately bad | total |
|---|---|---|---|
| forehand | 20 | 20 | 40 |
| backhand | 20 | 20 | 40 |
| serve | 15 | 15 | 30 |

That is roughly 30–45 minutes of court time and it is the whole dataset for the
first calibration pass. `docs/TUNING.md` suggests 10–15 clips; that is enough to
see whether a metric separates at all, not enough to place a threshold with any
confidence. 20 per class per shot is still thin — it gives you a defensible
first cut, not a validated one. Say so in the threshold comments.

**The bad clips are not optional and they are not filler.** They carry the
entire signal. Hit each fault deliberately and one at a time: arm-only forehand
with no legs, no torso coil, feet planted, locking the elbow at contact. It
feels ridiculous on court. It is the only thing that tells you where a threshold
belongs, because a threshold is a boundary and you cannot see a boundary from
one side of it.

### Naming

`YYYYMMDD_<shot>_<nnn>_<label>.mp4` — e.g. `20260815_fh_007_bad-noLegs.mp4`

Into `data/raw/`, which is gitignored. Label from the `<label>` field, not from
memory, and **write the label before you run anything.** `docs/TUNING.md` step 2
exists because once you have seen the tool's output you cannot un-see it, and
your labels quietly start agreeing with it.

**Done when:** ~110 clips in `data/raw/`, every one self-labelled in its
filename, all shot from one marked position at ≥60fps.

---

## Phase 2 — does the pipeline survive real footage · one session

First contact between the scaffold and reality. Expect this to be messier than
it sounds — it is the phase where you find out what the synthetic fixture was
too polite to model.

1. Run every clip. Record, per clip: did pose detection hold, how many frames
   dropped, how many swings were found vs how many you actually hit.
2. The failure to watch for: **dropped landmarks during the fast part of the
   swing.** Motion blur costs you the wrist at exactly the frames the whole
   pipeline is built on. If it is bad, the fix is capture (faster shutter,
   more light, 120fps), not code.
3. Second failure to watch for: swing count off by one or two per clip. Peaks
   at the very first or very last frame are missed by construction —
   `detect_swings` scans `range(1, len(speeds) - 1)`.
4. Anything systematic becomes a new fixture variant in
   `tests/fixtures/synthetic.py`, so it can never silently come back.

**Done when:** swing count matches your own count on ≥90% of clips, and you know
the name of every failure mode in the other 10%.

---

## Phase 3 — calibrate the thresholds · one session

Now `docs/TUNING.md` step 3 onward becomes possible, with real distributions
instead of guesses.

1. Dump every metric for every clip into one table — clip, self-label, all nine
   metrics. A notebook in `notebooks/` is the right home.
2. Per metric, plot good vs bad as two distributions. **The question is not
   "what is a good elbow angle." It is "does this metric separate my good clips
   from my bad ones at all?"** Some will not. A metric that does not separate
   must not drive a rule — delete the rule or leave it unreachable, and say
   which in the comment.
3. For metrics that do separate: the threshold goes where they separate, and the
   comment next to the constant records the value, n, the date, and that it was
   calibrated on you.
4. Set each rule's `confidence` from how cleanly its metric separated. A rule
   whose distributions overlap heavily should be emitting 0.4, not 0.7 — and
   `min_confidence` will then correctly suppress it.

**Done when:** every constant in `advice/rules.py` carries a value, an n, a
date, and a name. Any rule that could not be calibrated is disabled rather than
left at its guess. **This is the gate on showing the advice to anyone, including
yourself in a serious way.**

---

## Phase 4 — trajectory-based classification · one session

Design is written up in `docs/NEXT_SESSION.md`: serve detection needs duration
above the head rather than an instant, forehand/backhand should read the
take-back rather than the contact frame, the two-handed grip is detectable
directly from wrist separation, and handedness should be computed only over
frames where the hands are apart.

Do this after Phase 3, not before — you will have 110 clips by then, including
your own backhand, which is the case that breaks the current classifier.

**Done when:** classification agrees with your filename labels on ≥95% of clips,
with the two-handed backhand and the high volley both handled.

---

## Phase 5 — real units · one session

`config/cameras.yaml` exists and is empty. Court lines are the calibration
target you already have: the singles court is 8.23m wide and the service box is
6.40m deep, both visible in a side-on frame. A homography from four court points
converts normalised units to metres, and at that point `com_lateral_range` stops
being "3% of frame width" and becomes "you moved 24cm," which is a sentence a
human can act on.

This is also what makes clips from different distances comparable, which is what
makes Phase 6 possible.

**Done when:** metrics are reported in metres and two clips filmed from
different distances give the same measurement for the same movement.

---

## Phase 6 — the actual coach · ongoing

Everything above produces per-clip advice. That is the less interesting half. A
coach for one player, filmed from one marked spot, week after week, can answer
the question a single clip never can: **is this getting better?**

- Same drill, same spot, same 10 clips, once a week.
- Track the distribution of each metric over sessions, not the value in one clip.
- The note that matters is not "your elbow was straight in this shot" — it is
  "your mean separation at contact has gone from 19° to 27° over six weeks."
- This is where `analysis.v1.json` accumulating in `artifacts/runs/` pays off,
  and where `rally-app` on the MacBook has something worth displaying.

At this point the honest version of the product exists: not a coach that tells
you what is wrong from one video, but an instrument that tells you whether what
you are working on is moving.

---

## Order, and what blocks what

```
Phase 0  fix smoothing ─────────────┐
                                    ├──► Phase 2  real footage ──► Phase 3  thresholds ──┐
Phase 1  film ~110 clips ───────────┘                                  │                 │
                                                                       ▼                 ▼
                                                     Phase 4  trajectory classification   │
                                                                       │                 │
                                                                       └──► Phase 5  metres ──► Phase 6  longitudinal
```

Phase 1 needs no code and blocks almost everything. **Film first.**
