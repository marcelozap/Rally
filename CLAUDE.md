# rally-coach — XIV workspace rules

## What this repo is
Computer vision and pose estimation for tennis: movement recognition, swing
analytics, and coaching advice. **This is the Windows PC's project.**

## Boundary
- `rally-app` (Swift, on the MacBook) is a SEPARATE repo. This repo contains
  **zero** `.swift` files, and that repo contains zero `.py`.
- The only link between them is `src/rally_coach/export/schema/analysis.v1.json`.
  This repo WRITES it. `rally-app` READS it. Neither imports the other.
- `analysis.v1` is frozen. Breaking changes become `analysis.v2` with a new
  schema file. Never edit a shipped schema in place.

## Architecture rules
- `core/types.py` is pure data. No I/O, no cv2, no mediapipe.
- `pose/mediapipe_backend.py` is the ONLY file that may import mediapipe.
  Everything else depends on the `PoseEstimator` protocol in `pose/base.py`.
  Adding a backend = one new file + one line in `get_backend`.
- `io/video.py` is the only place `cv2.VideoCapture` appears.
- Thresholds live in `config/pipeline.yaml` or as named constants in
  `advice/rules.py`. Never inline a magic number in a function body.
- `notebooks/` may import from `src/`. `src/` may never import from `notebooks/`.

## Never commit
Virtualenvs · model weights (`.tflite`/`.pth`/`.onnx`) · raw video · frame dumps ·
rendered overlays · anything in `artifacts/` or `data/`.
Test fixtures cap at ~3 seconds of footage.

## Visual
Overlays and any UI follow `06_XIV_VISUAL_STANDARD.md`: cyan skeleton on void,
magenta at contact, dark only.

## Banned
Fantasy-village / agent-world framing. Creating new projects — six lanes exist.
Deleting anything without showing the list first.

## Handoff
End every session with the block in `02_ROUTING_MAP.md`, including BOUNDARY CHECK.
