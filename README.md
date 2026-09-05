# rally-coach

Computer vision and pose estimation for tennis movement analysis. Reads a clip,
finds the swings, measures the mechanics, and returns coaching notes.

Part of the **rally** lane. Its sibling `rally-app` (Swift, MacBook) consumes this
repo's output. This repo runs on the Windows PC.

## Install

```bash
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -e ".[dev]"
```

Use Python 3.11 or 3.12. This project pins MediaPipe 0.10.14 for its legacy
Solutions API; that pinned release has no Python 3.13 wheels.

## Run

```bash
rally-coach analyze data/raw/practice.mp4
rally-coach analyze data/raw/practice.mp4 -o artifacts/runs/practice.json
rally-coach show artifacts/runs/practice.json
```

## Develop

```powershell
.\tasks.ps1 check      # lint + types + tests — everything that must be green
.\tasks.ps1 fix        # let ruff fix what it safely can
.\tasks.ps1 int        # just the integration tests
pre-commit install     # once, so lint runs on every commit
```

59 tests, ~1 second for the deterministic suite.

The integration tests need neither mediapipe nor a video file on disk: the rally
is scripted in `tests/fixtures/synthetic.py` and replayed through the
`PoseEstimator` protocol, and the clip they run against is rendered to a tmp dir
at test time. That is why the suite is deterministic and finishes in a second.

## How it works

```
video ──► pose ──► smooth ──► events ──► metrics ──► advice ──► analysis.v1.json
 io/    pose/    tracking/   events/    metrics/    advice/      export/
```

1. **`io/video.py`** — frames out of the file, downscaled to `max_dimension`.
2. **`pose/`** — MediaPipe's 33 landmarks mapped to 13 backend-neutral joints.
   Swap the backend by implementing one protocol.
3. **`tracking/smoothing.py`** — One Euro filter. Chosen over a moving average
   because it preserves the velocity spike at contact, which is the whole signal.
4. **`events/swing.py`** — wrist-speed peaks with a refractory period, then walk
   out to the troughs that bookend each swing. Coarse forehand/backhand/serve
   classification from wrist position at contact.
5. **`metrics/summary.py`** — elbow angle at contact, knee load, shoulder-hip
   separation ("X-factor"), centre-of-mass travel.
6. **`advice/rules.py`** — rule-based notes, each naming the metric and threshold
   that fired it. Capped at 3 — a list of twelve corrections is not coaching.
7. **`export/`** — `analysis.v1.json`, the frozen contract with `rally-app`.

## Status: scaffold

The pipeline is wired end to end, unit tested, and covered by an integration test
that drives the whole chain. What is **not** done, worst first:

- The shipped smoothing defaults (`min_cutoff: 2.0` / `beta: 0.5`) preserve the
  contact spike in the synthetic regression fixtures. The earlier smoothing
  defect is fixed; these settings still need validation on real tennis footage.
- **Thresholds in `advice/rules.py` are untuned guesses.** They need calibrating
  against real footage before anyone should act on the advice. See `docs/TUNING.md`.
- Swing classification is coarse — position-based, not trajectory-based. A
  two-handed backhand confuses handedness; a high volley trips serve detection.
  Design for the fix is in `docs/NEXT_SESSION.md`.
- No court calibration, so all metrics are in normalised units, not metres.
- `movenet` backend is a stub — `pose/movenet_backend.py` has the joint map and
  the implementation notes, and fails loudly at construction until it is filled in.

## Migrating the existing code

There are ~696 `.py` files in `Documents\ChatGPT\Rally`. This scaffold is
deliberately **not** a port of them — it's the target shape. Move code in one
module at a time, adapting it to `core/types.py`. Anything that doesn't fit a
module here probably belongs in `notebooks/` or shouldn't survive the move.
