"""Debug overlays. XIV palette — cyan skeleton on void, magenta at contact."""
from __future__ import annotations

import cv2
import numpy as np

from rally_coach.core.types import Joint, PoseFrame

# BGR (OpenCV order) from 06_XIV_VISUAL_STANDARD
CYAN = (238, 211, 34)
MAGENTA = (149, 45, 255)
MIST = (184, 162, 148)

SKELETON: list[tuple[Joint, Joint]] = [
    (Joint.L_SHOULDER, Joint.R_SHOULDER),
    (Joint.L_SHOULDER, Joint.L_ELBOW), (Joint.L_ELBOW, Joint.L_WRIST),
    (Joint.R_SHOULDER, Joint.R_ELBOW), (Joint.R_ELBOW, Joint.R_WRIST),
    (Joint.L_SHOULDER, Joint.L_HIP), (Joint.R_SHOULDER, Joint.R_HIP),
    (Joint.L_HIP, Joint.R_HIP),
    (Joint.L_HIP, Joint.L_KNEE), (Joint.L_KNEE, Joint.L_ANKLE),
    (Joint.R_HIP, Joint.R_KNEE), (Joint.R_KNEE, Joint.R_ANKLE),
]


def draw_pose(frame: np.ndarray, pose: PoseFrame, is_contact: bool = False) -> np.ndarray:
    out = frame.copy()
    h, w = out.shape[:2]
    color = MAGENTA if is_contact else CYAN

    def px(j: Joint) -> tuple[int, int] | None:
        kp = pose.get(j)
        return (int(kp.x * w), int(kp.y * h)) if kp else None

    for a, b in SKELETON:
        pa, pb = px(a), px(b)
        if pa and pb:
            cv2.line(out, pa, pb, color, 2, cv2.LINE_AA)
    for j in pose.joints:
        if (p := px(j)) is not None:
            cv2.circle(out, p, 4, color, -1, cv2.LINE_AA)

    label = f"f{pose.index}  t={pose.t:.2f}s" + ("  CONTACT" if is_contact else "")
    cv2.putText(out, label, (12, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.6, MIST, 1, cv2.LINE_AA)
    return out
