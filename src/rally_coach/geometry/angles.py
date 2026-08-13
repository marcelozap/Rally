"""Joint geometry. Pure math on normalised coordinates — no video, no model."""
from __future__ import annotations

import math

from rally_coach.core.types import Joint, PoseFrame


def angle_at(pose: PoseFrame, a: Joint, vertex: Joint, c: Joint) -> float | None:
    """Interior angle in degrees at `vertex`, formed by a-vertex-c."""
    ka, kv, kc = pose.get(a), pose.get(vertex), pose.get(c)
    if ka is None or kv is None or kc is None:
        return None
    v1 = (ka.x - kv.x, ka.y - kv.y)
    v2 = (kc.x - kv.x, kc.y - kv.y)
    n1 = math.hypot(*v1)
    n2 = math.hypot(*v2)
    if n1 < 1e-9 or n2 < 1e-9:
        return None
    cos = max(-1.0, min(1.0, (v1[0] * v2[0] + v1[1] * v2[1]) / (n1 * n2)))
    return math.degrees(math.acos(cos))


def elbow_angle(pose: PoseFrame, side: str = "right") -> float | None:
    if side == "right":
        return angle_at(pose, Joint.R_SHOULDER, Joint.R_ELBOW, Joint.R_WRIST)
    return angle_at(pose, Joint.L_SHOULDER, Joint.L_ELBOW, Joint.L_WRIST)


def knee_angle(pose: PoseFrame, side: str = "right") -> float | None:
    if side == "right":
        return angle_at(pose, Joint.R_HIP, Joint.R_KNEE, Joint.R_ANKLE)
    return angle_at(pose, Joint.L_HIP, Joint.L_KNEE, Joint.L_ANKLE)


def shoulder_rotation(pose: PoseFrame) -> float | None:
    """Shoulder-line angle vs horizontal, degrees. Proxy for torso coil."""
    ls, rs = pose.get(Joint.L_SHOULDER), pose.get(Joint.R_SHOULDER)
    if ls is None or rs is None:
        return None
    return math.degrees(math.atan2(rs.y - ls.y, rs.x - ls.x))


def hip_rotation(pose: PoseFrame) -> float | None:
    lh, rh = pose.get(Joint.L_HIP), pose.get(Joint.R_HIP)
    if lh is None or rh is None:
        return None
    return math.degrees(math.atan2(rh.y - lh.y, rh.x - lh.x))


def separation_angle(pose: PoseFrame) -> float | None:
    """Shoulder-hip separation ("X-factor") — the classic power indicator."""
    s, h = shoulder_rotation(pose), hip_rotation(pose)
    if s is None or h is None:
        return None
    return abs(s - h)


def center_of_mass(pose: PoseFrame) -> tuple[float, float] | None:
    """Crude COM proxy: hip midpoint."""
    lh, rh = pose.get(Joint.L_HIP), pose.get(Joint.R_HIP)
    if lh is None or rh is None:
        return None
    return ((lh.x + rh.x) / 2, (lh.y + rh.y) / 2)
