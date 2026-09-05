"""pixels -> keypoints + confidence. The only part of the stack that sees an image."""

import numpy as np
import mediapipe as mp


class L:
    """MediaPipe Pose landmark indices, named."""
    NOSE = 0
    L_SHOULDER, R_SHOULDER = 11, 12
    L_ELBOW, R_ELBOW = 13, 14
    L_WRIST, R_WRIST = 15, 16
    L_HIP, R_HIP = 23, 24
    L_KNEE, R_KNEE = 25, 26
    L_ANKLE, R_ANKLE = 27, 28


class PoseExtractor:
    """Wraps MediaPipe. Returns an (33, 4) array: x, y, z, visibility.

    x and y are in pixels. z is model-estimated depth and is the weakest axis —
    treat it as suggestive, not measured.
    """

    def __init__(self, complexity=1, min_det=0.5, min_track=0.5):
        if not hasattr(mp, "solutions"):
            raise RuntimeError(
                "This pipeline requires MediaPipe's legacy Pose API. "
                "Use Python 3.11 or 3.12 and install requirements.txt in a clean "
                "virtual environment (mediapipe==0.10.14)."
            )
        self._pose = mp.solutions.pose.Pose(
            model_complexity=complexity,
            min_detection_confidence=min_det,
            min_tracking_confidence=min_track,
        )

    def __call__(self, frame_bgr):
        import cv2
        h, w = frame_bgr.shape[:2]
        res = self._pose.process(cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB))
        if not res.pose_landmarks:
            return None, None
        pts = np.array(
            [[p.x * w, p.y * h, p.z * w, p.visibility] for p in res.pose_landmarks.landmark],
            dtype=np.float64,
        )
        return pts, res.pose_landmarks

    def draw(self, frame_bgr, landmarks):
        if landmarks is not None:
            mp.solutions.drawing_utils.draw_landmarks(
                frame_bgr, landmarks, mp.solutions.pose.POSE_CONNECTIONS
            )
        return frame_bgr

    def close(self):
        self._pose.close()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
