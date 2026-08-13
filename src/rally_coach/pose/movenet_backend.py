"""MoveNet backend — STUB.

Implement the PoseEstimator protocol from pose/base.py, map MoveNet's 17
COCO keypoints to our Joint enum, and register it in get_backend().

MoveNet's keypoint order (COCO):
  0 nose, 1 l_eye, 2 r_eye, 3 l_ear, 4 r_ear, 5 l_shoulder, 6 r_shoulder,
  7 l_elbow, 8 r_elbow, 9 l_wrist, 10 r_wrist, 11 l_hip, 12 r_hip,
  13 l_knee, 14 r_knee, 15 l_ankle, 16 r_ankle

Note MoveNet returns (y, x) normalised, NOT (x, y). Swap them on the way in or
every angle downstream will be mirrored — this is the single most common bug
when adding this backend.
"""
from __future__ import annotations

import numpy as np

from rally_coach.core.types import Joint, PoseFrame

_LANDMARK_MAP: dict[int, Joint] = {
    0: Joint.NOSE,
    5: Joint.L_SHOULDER, 6: Joint.R_SHOULDER,
    7: Joint.L_ELBOW, 8: Joint.R_ELBOW,
    9: Joint.L_WRIST, 10: Joint.R_WRIST,
    11: Joint.L_HIP, 12: Joint.R_HIP,
    13: Joint.L_KNEE, 14: Joint.R_KNEE,
    15: Joint.L_ANKLE, 16: Joint.R_ANKLE,
}


class MoveNetPose:
    name = "movenet"

    def __init__(self, **kwargs: object) -> None:
        raise NotImplementedError(
            "MoveNet backend is a stub. Implement estimate() against the map above, "
            "remember MoveNet returns (y, x) not (x, y), then register this class "
            "in rally_coach.pose.base.get_backend()."
        )

    def estimate(self, frame: np.ndarray, index: int, t: float) -> PoseFrame | None:
        raise NotImplementedError

    def close(self) -> None:
        pass
