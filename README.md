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

MediaPipe needs Python 3.11 or 3.12 — it does not yet ship wheels for 3.13.

## Run

```bash
rally-coach analyze data/raw/practice.mp4
rally-coach analyze data/raw/practice.mp4 -o artifacts/runs/practice.json
rally-coach show artifacts/runs/practice.json
```

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

## Status: scaffold, 17 tests passing

Pipeline wired end to end. `analyze_poses()` is split out from `analyze()` so all
the logic is testable without a video file, cv2, or mediapipe — that split is
what let the contract tests find the bug below.

**A real bug the tests caught, already fixed:** the One Euro filter shipped with
`beta=0.007`, a value borrowed from the paper's pixel-space examples. On
normalised `[0,1]` coordinates that smooths the swing completely flat and the
detector finds **zero** swings. Measured sweep is in `tracking/smoothing.py`;
defaults are now `min_cutoff=2.0, beta=0.5` (all swings found, 60% of jitter
rejected). `tests/integration/test_pipeline_contract.py` guards the regression.

What is still **not** done:

- **Thresholds in `advice/rules.py` are untuned guesses.** They need calibrating
  against real footage before anyone acts on the advice. See `docs/TUNING.md`.
  This is the top of the list.
- Swing classification is position-based, not trajectory-based. A two-handed
  backhand confuses handedness; a high volley trips serve detection.
- `geometry/court.py` exists but no calibration is wired in, so metrics are
  normalised units, not metres — only compare clips shot from the same position.
- `pose/movenet_backend.py` is a stub with the keypoint map filled in.
- No test uses real footage. Drop a 2–3 second clip in `tests/fixtures/` and
  write one integration test against it.

## Migrating the existing code

There are ~696 `.py` files in `Documents\ChatGPT\Rally`. This scaffold is
deliberately **not** a port of them — it's the target shape. Move code in one
module at a time, adapting it to `core/types.py`. Anything that doesn't fit a
module here probably belongs in `notebooks/` or shouldn't survive the move.
