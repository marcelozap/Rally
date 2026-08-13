"""MediaPipe Pose backend.

The ONLY file allowed to import mediapipe. Its 33-landmark output is mapped to
our backend-neutral Joint enum here and nowhere else.
"""
from __future__ import annotations

import numpy as np

from rally_coach.core.types import Joint, Keypoint, PoseFrame

# MediaPipe Pose landmark indices -> our joints.
_LANDMARK_MAP: dict[int, Joint] = {
    0: Joint.NOSE,
    11: Joint.L_SHOULDER,
    12: Joint.R_SHOULDER,
    13: Joint.L_ELBOW,
    14: Joint.R_ELBOW,
    15: Joint.L_WRIST,
    16: Joint.R_WRIST,
    23: Joint.L_HIP,
    24: Joint.R_HIP,
    25: Joint.L_KNEE,
    26: Joint.R_KNEE,
    27: Joint.L_ANKLE,
    28: Joint.R_ANKLE,
}


class MediaPipePose:
    name = "mediapipe"

    def __init__(
        self,
        model_complexity: int = 1,
        min_detection_confidence: float = 0.5,
        min_tracking_confidence: float = 0.5,
    ) -> None:
        import mediapipe as mp  # noqa: PLC0415 — deliberately lazy

        self._mp = mp
        self._pose = mp.solutions.pose.Pose(
            static_image_mode=False,
            model_complexity=model_complexity,
            min_detection_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence,
        )

    def estimate(self, frame: np.ndarray, index: int, t: float) -> PoseFrame | None:
        import cv2  # noqa: PLC0415

        result = self._pose.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        landmarks = getattr(result, "pose_landmarks", None)
        if landmarks is None:
            return None

        joints: dict[Joint, Keypoint] = {}
        for idx, joint in _LANDMARK_MAP.items():
            lm = landmarks.landmark[idx]
            joints[joint] = Keypoint(
                x=lm.x, y=lm.y, z=getattr(lm, "z", 0.0),
                visibility=getattr(lm, "visibility", 1.0),
            )
        return PoseFrame(index=index, t=t, joints=joints)

    def close(self) -> None:
        self._pose.close()
