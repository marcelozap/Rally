# Next session

**Update, 2026-09-05:** `analyze_poses()` is now implemented in the live pipeline,
the contact-spike regression passes with the already-shipped `2.0 / 0.5`
smoothing defaults, and the complete check passes (59 tests). The missing
function and obsolete strict-xfail notes below describe the earlier state.
See `VERIFICATION.md` for the real MediaPipe smoke check and remaining limits.

Written 2026-08-13 by a session that had repo access while you were out. Nothing
here was tuned, nothing was deleted, and `analysis.v1.json` was not touched.

> **The bigger picture is in `docs/PLAN.md`** — the six phases from here to a
> coach calibrated on your own footage. This file is just the next two coding
> sessions. Phase 1 of the plan is *filming*, needs no code, and blocks almost
> everything else: do that before the next session and the work has something
> real to run against.

## What landed

- **Integration test** (was priority 2). `tests/integration/` drives the real
  `analyze()` end to end. It needs no mediapipe and no committed footage: the
  rally is scripted in `tests/fixtures/synthetic.py` and replayed through the
  `PoseEstimator` protocol, and a real 3s clip is rendered to a tmp dir at test
  time so `io/video.py` is exercised for real. 51 tests, ~1s, deterministic.
- **Two changes to `src/`**: `analyze()` takes an optional `estimator=` (the
  seam `pose/base.py` already implied), and the pure half of the pipeline is now
  `analyze_poses()` — see the concurrent-writer note below for why.
- **A real defect, found by the fixture** — see below.
- **Repo hygiene**: pinned ruff rule set (its defaults drift between releases),
  a mypy config that silences the unstubbed-import noise, `.\tasks.ps1 check`,
  pre-commit, `.editorconfig`, and a movenet stub with its joint map filled in
  and a docstring saying exactly what to write.

## Read this first: something else was writing to the repo at the same time

`tests/integration/test_pipeline_contract.py` appeared at 10:42, mid-session,
and is not mine — Codex, Gemini or another Claude lane wrote it while I worked.
I have left it **exactly as it was written**. Two things about it:

1. It called `analyze_poses(poses, fps, clip=...)`, which did not exist, so the
   whole file errored on import. I implemented it in `pipeline.py` — it is the
   pure half of the pipeline (handedness -> swings -> metrics -> advice, no
   video, no model) split out of `analyze()`, which now delegates to it. Good
   idea, and it composes with the `estimator=` seam rather than competing.
   **6 of its 7 tests now pass.**
2. The 7th fails — and it is *right* to fail. It asserts the contact spike
   survives smoothing and gets `swing_count: 0.0` with the message *"smoothing
   destroyed the contact spike entirely."* That is the same defect described
   below, found independently, from a different fixture:

   | fixture | raw peak | after shipped smoothing | retained | vs floor 2.5 |
   |---|---|---|---|---|
   | mine (smootherstep arc) | 3.82 | 1.66 | 44% | detects nothing |
   | theirs (linear ramp) | 2.69 | 1.52 | 56% | detects nothing |

**So the suite is currently 57 pass / 1 fail / 1 xfail, and the one failure is a
true positive.** I did not mark it xfail — it is not my file, and a red suite
pointing at the highest-priority defect is a better forcing function than a
green one that hides it. Both go green together when Phase 0 is done.

Decide whether to keep both test files. They overlap: theirs covers the pure
analytical half via `analyze_poses`, mine covers the full chain including
`io/video.py` and the pose seam. Keeping both is defensible; merging theirs into
`tests/unit/` as pure-logic tests is tidier. Your call — I did not delete it.
It also carries 6 ruff findings (semicolons) that I left untouched.

## The defect, in one paragraph

The shipped smoothing constants and the shipped swing threshold contradict each
other. `min_cutoff: 1.0` / `beta: 0.007` retains **44%** of peak wrist speed at
60fps. A swing peaking at 3.8 normalised units/s reaches `detect_swings` as 1.7,
under `min_wrist_speed: 2.5` — so on the shipped defaults **the detector returns
zero swings and the pipeline silently produces nothing**. `beta` is the adaptive
term and at 0.007 it is inert: `beta * |dx|` is ~0.03 even mid-swing, so the
cutoff never lifts off its 1.0Hz floor and One Euro degenerates into a heavy
fixed lowpass — the exact thing the README says it was chosen to avoid.

Encoded as `test_shipped_smoothing_preserves_the_contact_spike`, marked
`xfail(strict=True)`. It goes green when you fix the constants, and strict mode
then fails the suite so you remember to delete the marker. Numbers and a
starting point are in `docs/TUNING.md`. **Do this before any threshold work** —
every floor you calibrate against raw footage will otherwise be ~2x too high.

## Then: trajectory-based classification (the priority-3 item)

`classify_swing()` looks at ONE frame and asks where the wrist is. That is why a
high volley reads as a serve and a two-handed backhand breaks handedness. Both
failures are the same bug: a single frame cannot express a trajectory.

The shape of the fix — all four signals come from the swing window that
`detect_swings` already computes (`start_frame -> contact_frame -> end_frame`),
so no new data is needed:

1. **Serve needs duration, not an instant.** Require the wrist above the nose
   for N consecutive frames in the window, not just at contact. A volley pops
   above the head for 1-3 frames; a serve stays there. Kills the false positive.
2. **Forehand vs backhand from the take-back, not contact.** Look at which side
   of the hip midline the wrist occupies over `start -> contact`. At contact
   alone the two are only a few hundredths apart; across the window they are not.
3. **Detect the two-hander directly.** Measure `|L_WRIST - R_WRIST|` across the
   window. Both hands on the grip = a small, stable gap. That is a *feature*,
   not a failure — a joined grip on the non-dominant side is a two-handed
   backhand with high confidence.
4. **Then fix handedness.** `detect_handedness` compares total wrist travel,
   which is meaningless when both hands are on the grip. Compute it only over
   frames where the wrists are NOT joined — the serve is always one-handed, so
   there is always signal to use.

New constants (`two_hand_max_wrist_gap`, `serve_min_frames_above_head`,
`serve_min_upward_fraction`) belong in `config/pipeline.yaml` under
`events.swing`, not inline. Signature becomes something like
`classify_swing(poses, start, contact, end, hand) -> tuple[SwingType, float]`,
returning a confidence you can actually put in `Swing.confidence` instead of the
current speed ratio.

**Write the fixtures first.** `tests/fixtures/synthetic.py` is built for this:
add `two_handed_backhand_rally()` and `high_volley_rally()` alongside
`flawed_rally()`, assert the classification you want, watch them fail against
the current one-frame classifier, then make them pass. The knobs and the
trajectory-segment format are already there.

## Not touched, on purpose

- Every threshold in `advice/rules.py`. Untuned is untuned; a test that pinned
  them would just freeze the guesses.
- `export/schema/analysis.v1.json`. Frozen. There are now canary tests that fail
  if anyone edits it in place instead of writing a v2.
- Nothing was deleted. There was nothing in the repo worth deleting — the only
  gap was `notebooks/` being empty enough to vanish on a clone, which a
  `.gitkeep` now handles.

## Boundary check

Zero `.swift` files. No new project or lane. No model weights, video, frame
dumps or overlays added; the integration clip is rendered to a tmp dir and never
written into the repo. `core/types.py` still imports no I/O. `mediapipe` is still
imported in exactly one file. `cv2.VideoCapture` still appears in exactly one
file — `tests/fixtures/synthetic.py` imports cv2 for `VideoWriter` only, inside
the function, and it is test scaffolding, not pipeline code.

## Prompt to start from

> Read docs/NEXT_SESSION.md and docs/TUNING.md, then work in this order.
>
> **1. Fix the smoothing/threshold contradiction.** Use
> `tests/fixtures/synthetic.py` as the measuring instrument: report peak-wrist-
> speed retention for a grid of `min_cutoff` x `beta`, pick the pair that keeps
> the contact spike while still killing idle jitter, and set `min_wrist_speed`
> from the retained values — not from raw ones. Show me the grid before you
> change `config/pipeline.yaml`. Then delete the `xfail` marker on
> `test_shipped_smoothing_preserves_the_contact_spike` and confirm it passes.
> Do not touch anything in `advice/rules.py` — those need real footage.
>
> **2. Make swing classification trajectory-based**, following the four signals
> in docs/NEXT_SESSION.md. Fixtures first: add `two_handed_backhand_rally()` and
> `high_volley_rally()` to `tests/fixtures/synthetic.py`, write the assertions
> you want, watch them fail, then change `classify_swing` to take the swing
> window instead of a single frame. New constants go in `config/pipeline.yaml`
> under `events.swing`. `analysis.v1.json` stays frozen — if the output shape has
> to change, stop and tell me instead.
>
> Run `.\tasks.ps1 check` before you tell me you are done, and end with the
> handoff block from 02_ROUTING_MAP.md including BOUNDARY CHECK.
