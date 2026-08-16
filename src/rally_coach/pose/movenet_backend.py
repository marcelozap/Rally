"""MoveNet pose backend — NOT IMPLEMENTED.

This file exists so `get_backend("movenet")` fails in the right place with the
right message, and so implementing the backend is a matter of filling in two
methods rather than working out the shape from scratch.

WHAT TO IMPLEMENT
  1. `__init__`  — lazily import the runtime (tensorflow / tflite-runtime) the
     same way `mediapipe_backend.py` does. This file and that one are the ONLY
     files allowed to import a model runtime; keep it inside the method so an
     unused backend never has to be installed.
  2. `estimate`  — MoveNet returns 17 COCO keypoints as (y, x, score) in
     NORMALISED coordinates, in that order. Note the axis order: it is (y, x),
     not (x, y). Map them through `_LANDMARK_MAP` below, and pass `score`
     through as `Keypoint.visibility` so `PoseFrame.has()` keeps working.
     Return None when the person score is below the detection threshold.
  3. `close`     — release the interpreter.

WHAT NOT TO DO
  - Do not import numpy/tf at module scope beyond what is already here.
  - Do not add MoveNet-specific joint names. Everything downstream speaks
    `core.types.Joint`; that mapping is this file's entire job.
  - Do not commit the weights. `.gitignore` already excludes `models/**`;
    fetch them in `scripts/` and keep a pointer.

MoveNet has no torso-visibility notion the way MediaPipe does, so `visibility`
will be a keypoint confidence rather than an occlusion estimate. That is fine
for the current thresholds but worth remembering when tuning.
"""
from __future__ import annotations

import numpy as np

from rally_coach.core.types import Joint, PoseFrame

# MoveNet / COCO keypoint indices -> our backend-neutral joints.
# COCO has no direct NOSE equivalent problem — index 0 IS the nose — but it also
# has eyes and ears (1-4) that we deliberately drop.
_LANDMARK_MAP: dict[int, Joint] = {
    0: Joint.NOSE,
    5: Joint.L_SHOULDER,
    6: Joint.R_SHOULDER,
    7: Joint.L_ELBOW,
    8: Joint.R_ELBOW,
    9: Joint.L_WRIST,
    10: Joint.R_WRIST,
    11: Joint.L_HIP,
    12: Joint.R_HIP,
    13: Joint.L_KNEE,
    14: Joint.R_KNEE,
    15: Joint.L_ANKLE,
    16: Joint.R_ANKLE,
}

_NOT_IMPLEMENTED = (
    "movenet backend is a stub. Implement MoveNetPose.estimate() in "
    "rally_coach/pose/movenet_backend.py — the joint mapping and the notes on "
    "MoveNet's (y, x, score) axis order are already in that file's docstring. "
    "Until then use backend: mediapipe in config/pipeline.yaml."
)


class MoveNetPose:
    """Placeholder that satisfies the `PoseEstimator` protocol but refuses to run.

    It fails at construction rather than on the first frame, so a misconfigured
    `config/pipeline.yaml` is caught before a clip is opened instead of halfway
    through one.
    """

    name = "movenet"

    def __init__(self, **kwargs: object) -> None:
        raise NotImplementedError(_NOT_IMPLEMENTED)

    def estimate(self, frame: np.ndarray, index: int, t: float) -> PoseFrame | None:
        raise NotImplementedError(_NOT_IMPLEMENTED)  # pragma: no cover

    def close(self) -> None:  # pragma: no cover
        return None
