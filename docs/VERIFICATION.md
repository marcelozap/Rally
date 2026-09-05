# Movement pipeline verification — 2026-09-05

The `rally-coach` branch runs MediaPipe pose estimation and deterministic
movement/coaching rules. It does not contain a language model or an LLM service.

## Repairs

- Restored `analyze_poses()` and made video analysis delegate to it. The existing
  integration suite previously failed during collection because it imported
  this missing function. Source frame count and duration still survive dropped
  pose detections.
- Removed the obsolete strict-xfail marker from the contact-spike regression.
  The existing `2.0 / 0.5` smoothing defaults pass it; no threshold was retuned.
- Resolved six existing lint findings. Mypy now checks using the environment's
  Python version, matching its installed dependency stubs.
- Declared the Python 3.11–3.12 constraint required by the pinned MediaPipe
  0.10.14 release. Updated the stale README status.

## Validation

Fresh isolated Windows environment: Python 3.12.4, MediaPipe 0.10.14,
NumPy 2.5.2, OpenCV 5.0.0.93, Pydantic 2.13.5.

`./tasks.ps1 check` passes: Ruff clean, Mypy clean across 26 source files,
59 tests passing in under one second. These tests use synthetic poses.

Real model checks were run separately using the actual `MediaPipePose` backend:

1. A black frame returns no detection without a crash.
2. Google's [MediaPipe pose sample](https://storage.googleapis.com/mediapipe-assets/pose.jpg)
   returns all 13 mapped joints; minimum visibility was 0.98747. This is the
   sample referenced by Google's
   [pose test](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/python/solutions/pose_test.py).
3. A temporary MP4 made from 12 repeated sample frames at 30 fps passes through
   the full video pipeline: 12 source frames, 12 detected poses, zero swings,
   and an `analysis.v1` JSON export. A still person should not produce swings.
4. Google's [dynamic pose demonstration](https://mediapipe.dev/images/mobile/pose_world_landmarks.mp4)
   passes through the real pipeline with 149/149 detected pose frames, source
   rate 25.1689189 fps, duration 5.92 seconds, and a schema-valid `analysis.v1`
   export. Across those smoothed poses, right-elbow angle changes from 26.71
   to 179.10 degrees and right-knee angle from 50.81 to 179.49 degrees.
   Aggregate normalized center-of-mass travel is 0.0442 laterally and 0.2349
   vertically. This is an annotated general movement demonstration, not tennis:
   zero swings were reported, and these measurements have no ground-truth
   comparison. They establish changing output from actual moving-person input.

The source image, generated still-person clip and JSON stayed in the Windows
temporary directory. The dynamic demonstration was read from the sibling
movement worktree's ignored verification artifacts. No footage or model weights
were added to the repository.

## Remaining limits

The model loads and the complete inference pipeline executes. This does not
establish tennis-specific detection or coaching accuracy: representative
tennis footage with known swings is still needed for calibration. Stroke
classification remains a coarse position rule; advice thresholds remain
uncalibrated. MoveNet is still an explicit unsupported backend. No iOS build
or app integration was tested by these checks.

## Boundary check

No Swift files, schema changes, model weights, committed videos or new project
lanes. The existing `analysis.v1` contract tests pass.
