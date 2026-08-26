"""Keypoints -> the numbers you actually care about.

Nearly all of this is trigonometry, not machine learning. Worth knowing before
you go looking for a model to train.

Everything here is measured in 2D from a consistent camera angle. Depth from a
single camera is weakly constrained; these metrics survive without it.
"""

import numpy as np
from .pose import L

WINDOW_METRIC_NAMES = ["smooth_score", "cadence_spm", "vertical_travel", "range_of_motion"]

METRIC_NAMES = [
    "hip_shoulder_separation",
    "shoulder_tilt",
    "hip_tilt",
    "trunk_lean",
    "l_elbow_angle",
    "r_elbow_angle",
    "l_knee_angle",
    "r_knee_angle",
    "elbow_asymmetry",
    "knee_asymmetry",
]


def _seg_angle(p1, p2):
    """Angle of the line p1->p2, in degrees."""
    d = np.asarray(p2) - np.asarray(p1)
    return float(np.degrees(np.arctan2(d[1], d[0])))


def _angle_3pt(a, b, c):
    """Interior angle at b, in degrees."""
    v1, v2 = np.asarray(a) - np.asarray(b), np.asarray(c) - np.asarray(b)
    n1, n2 = np.linalg.norm(v1), np.linalg.norm(v2)
    if n1 < 1e-9 or n2 < 1e-9:
        return float("nan")
    return float(np.degrees(np.arccos(np.clip(np.dot(v1, v2) / (n1 * n2), -1.0, 1.0))))


def _wrap(deg):
    """Fold an angle difference into [-90, 90] so left/right flips don't jump."""
    return (deg + 90.0) % 180.0 - 90.0


def window_metrics(frames, fps):
    """Rhythm, smoothness and range don't exist in a single frame — they are
    properties of a few seconds. `frames` is a list of (33, 2+) keypoint arrays.

    smooth_score is a relative index (0-100, higher = smoother), not a standard
    unit. It is only meaningful compared against the same subject.
    """
    if len(frames) < 12 or fps <= 0:
        return {k: float("nan") for k in WINDOW_METRIC_NAMES}

    arr = np.asarray([f[:, :2] for f in frames])                 # (T, 33, 2)
    sw = np.linalg.norm(arr[:, L.R_SHOULDER] - arr[:, L.L_SHOULDER], axis=1)
    sw = np.where(sw < 1e-6, 1e-6, sw)
    hip_y = (arr[:, L.L_HIP, 1] + arr[:, L.R_HIP, 1]) / 2 / sw

    dt = 1.0 / fps
    jerk = np.diff(hip_y, n=3) / dt ** 3
    smooth = 100.0 * float(np.exp(-np.mean(np.abs(jerk)) / 900.0)) if jerk.size else float("nan")

    sig = (arr[:, L.L_ANKLE, 1] - arr[:, L.R_ANKLE, 1]) / sw
    sig = sig - sig.mean()
    crossings = int(np.sum(sig[:-1] * sig[1:] < 0))
    span = len(frames) * dt
    cadence = (crossings / 2) * (60 / span) * 2 if span > 0.5 else float("nan")

    def ptp(a):
        return float(a.max() - a.min())

    wl, wr = arr[:, L.L_WRIST], arr[:, L.R_WRIST]
    rom = (ptp(wl[:, 0]) + ptp(wr[:, 0]) + ptp(wl[:, 1]) + ptp(wr[:, 1])) / (4 * sw[-1]) * 100

    return {
        "smooth_score": round(smooth, 1),
        "cadence_spm": round(cadence, 1),
        "vertical_travel": round(ptp(hip_y) * 100, 1),
        "range_of_motion": round(rom, 1),
    }


def compute_metrics(p):
    """p: (33, 2+) smoothed keypoints. Returns a dict of METRIC_NAMES -> float."""
    ls, rs = p[L.L_SHOULDER][:2], p[L.R_SHOULDER][:2]
    lh, rh = p[L.L_HIP][:2], p[L.R_HIP][:2]

    shoulder_line = _seg_angle(ls, rs)
    hip_line = _seg_angle(lh, rh)

    mid_sh = (ls + rs) / 2.0
    mid_hip = (lh + rh) / 2.0

    l_elbow = _angle_3pt(p[L.L_SHOULDER][:2], p[L.L_ELBOW][:2], p[L.L_WRIST][:2])
    r_elbow = _angle_3pt(p[L.R_SHOULDER][:2], p[L.R_ELBOW][:2], p[L.R_WRIST][:2])
    l_knee = _angle_3pt(p[L.L_HIP][:2], p[L.L_KNEE][:2], p[L.L_ANKLE][:2])
    r_knee = _angle_3pt(p[L.R_HIP][:2], p[L.R_KNEE][:2], p[L.R_ANKLE][:2])

    return {
        # the X-factor proxy: how far the shoulders have rotated ahead of the hips.
        # this is the primitive shared by a golf swing, a serve, and a pitch.
        "hip_shoulder_separation": _wrap(shoulder_line - hip_line),
        "shoulder_tilt": _wrap(shoulder_line),
        "hip_tilt": _wrap(hip_line),
        "trunk_lean": _wrap(_seg_angle(mid_hip, mid_sh) + 90.0),
        "l_elbow_angle": l_elbow,
        "r_elbow_angle": r_elbow,
        "l_knee_angle": l_knee,
        "r_knee_angle": r_knee,
        "elbow_asymmetry": abs(l_elbow - r_elbow),
        "knee_asymmetry": abs(l_knee - r_knee),
    }
