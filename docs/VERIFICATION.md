# Movement verification — 2026-09-05

Base: `xiv-movement`, `af68168` in `marcelozap/Rally`.
Fix branch: `codex/verify-movement`.

## Outcome

The Python pipeline loads and executes the actual MediaPipe Pose model, generates
finite torso measurements and writes readable CSV/MP4 outputs on Windows with
Python 3.12.4. This is a standalone movement prototype. It is not integrated into
the iOS game, and it contains no language-model endpoint or LLM inference.

## Reproduced and repaired

- A clean install of the original requirements resolved MediaPipe 1.0.1 and failed
  at `PoseExtractor()` with `AttributeError: module 'mediapipe' has no attribute
  'solutions'`. The compatible runtime now uses MediaPipe 0.10.14, NumPy 1.26.4
  and OpenCV contrib 4.11.0.86. Removed the overlapping OpenCV base wheel.
- Recorded videos were always encoded at 30 fps, changing playback duration for
  24/60 fps input. The CLI now forwards the source frame rate to the encoder.
- Lost pose tracking kept displaying the previous frame's measurements. The
  overlay now says tracking is unavailable; hidden limb angles become NaN.
- Encoder failures were silent and exceptions could leave resources open. The
  pipeline checks encoder initialization and releases the writer/source/window.

## Executed checks

```powershell
.venv\Scripts\python -m unittest discover -s tests -v
.venv\Scripts\python -m compileall -q cli.py xiv_movement scripts tests
.venv\Scripts\python scripts/verify_movement.py --image artifacts/verification/pose.jpg
.venv\Scripts\python cli.py analyze artifacts/verification/repeated-photo-60fps.mp4
.venv\Scripts\python scripts/verify_movement.py --video artifacts/verification/movement-demo.mp4 --output artifacts/dynamic-verification
```

- All 10 regression tests pass, including actual 24/60 fps video decoding,
  tracking loss, hidden joints, invalid frame-rate metadata and resource cleanup.
- Actual model smoke: 30/30 usable frames, finite hip/shoulder measurements,
  30 overlay frames at 60 fps, readable output video and CSV.
- The image was Google's public [MediaPipe pose test asset](https://storage.googleapis.com/mediapipe-assets/pose.jpg).
  It is repeated into a 0.5-second video by the verification script. This is real
  model inference on a photograph, not a mock and not a tennis-motion benchmark.
- A real moving-person sequence from Google's [MediaPipe pose demonstration](https://mediapipe.dev/images/mobile/pose_world_landmarks.mp4)
  produced 149/149 usable frames and a readable 149-frame overlay at 25.169 fps,
  preserving the source rate (25.1689189 fps). The measured separation range was
  13.09 degrees and trunk-lean range 24.96 degrees: the pipeline responds to a
  changing sequence. This six-second demo already has landmark graphics and is
  not a tennis accuracy benchmark or independent ground truth.
- A real 12-frame blank-video inference run correctly failed with status 1 and
  `No usable frames`; it did not report successful tracking or write a result.
- All downloaded/generated media and the virtual environment stay ignored in
  `artifacts/` and `.venv/`; no personal clip was uploaded or changed.

## Remaining validation

Run `scripts/verify_movement.py --video <real-practice-clip>` to exercise an actual
practice recording, then inspect landmarks and metric timestamps against known
movements. Rule thresholds, 2D accuracy, timing checks on clips with tracking gaps
and coaching usefulness have not been validated on real tennis here. The browser
camera prototype and live webcam path were not exercised. Xcode/iOS validation
is unavailable on this Windows host, and no Swift code was changed.

The compatible MediaPipe pin is intentional stabilization of the current code.
A migration to MediaPipe Tasks should be a separate change with equivalent real
inference and metric validation; upgrading the package alone is insufficient.
