"""Swing segmentation.

Approach: wrist speed over time has a clear peak at contact. Find peaks above a
floor, enforce a refractory period so one swing isn't counted twice, then walk
outwards to the speed minima that bookend the motion.

Deliberately simple and inspectable. Replace with a learned segmenter later if
the rule-based version proves insufficient — the interface stays the same.
"""
from __future__ import annotations

import math

from rally_coach.core.types import Handedness, Joint, PoseFrame, Swing, SwingType


def wrist_speeds(poses: list[PoseFrame], hand: Handedness) -> list[float]:
    """Per-frame wrist speed in normalised units/sec."""
    joint = Joint.R_WRIST if hand is not Handedness.LEFT else Joint.L_WRIST
    speeds = [0.0] * len(poses)
    for i in range(1, len(poses)):
        a, b = poses[i - 1].get(joint), poses[i].get(joint)
        dt = poses[i].t - poses[i - 1].t
        if a is None or b is None or dt <= 0:
            continue
        speeds[i] = math.hypot(b.x - a.x, b.y - a.y) / dt
    return speeds


def detect_handedness(poses: list[PoseFrame]) -> Handedness:
    """Whichever wrist moves more over the clip is the racket hand."""
    def travel(joint: Joint) -> float:
        total = 0.0
        for i in range(1, len(poses)):
            a, b = poses[i - 1].get(joint), poses[i].get(joint)
            if a and b:
                total += math.hypot(b.x - a.x, b.y - a.y)
        return total

    r, l = travel(Joint.R_WRIST), travel(Joint.L_WRIST)
    if max(r, l) < 1e-6:
        return Handedness.UNKNOWN
    return Handedness.RIGHT if r >= l else Handedness.LEFT


def _local_minimum(speeds: list[float], start: int, step: int, limit: int = 45) -> int:
    """Walk from `start` in `step` direction to the first speed trough."""
    i = start
    for _ in range(limit):
        j = i + step
        if j < 0 or j >= len(speeds):
            break
        if speeds[j] > speeds[i]:
            break
        i = j
    return i


def detect_swings(
    poses: list[PoseFrame],
    hand: Handedness,
    min_wrist_speed: float = 2.5,
    min_separation_frames: int = 12,
) -> list[Swing]:
    if len(poses) < 3:
        return []

    speeds = wrist_speeds(poses, hand)
    peaks: list[int] = []
    for i in range(1, len(speeds) - 1):
        if speeds[i] < min_wrist_speed:
            continue
        if speeds[i] >= speeds[i - 1] and speeds[i] >= speeds[i + 1]:
            if peaks and i - peaks[-1] < min_separation_frames:
                if speeds[i] > speeds[peaks[-1]]:
                    peaks[-1] = i          # keep the stronger of two close peaks
                continue
            peaks.append(i)

    peak_max = max(speeds) if speeds else 1.0
    swings: list[Swing] = []
    for n, p in enumerate(peaks):
        start = _local_minimum(speeds, p, -1)
        end = _local_minimum(speeds, p, +1)
        swings.append(
            Swing(
                id=n,
                type=classify_swing(poses[p], hand),
                start_frame=poses[start].index,
                contact_frame=poses[p].index,
                end_frame=poses[end].index,
                start_t=poses[start].t,
                contact_t=poses[p].t,
                end_t=poses[end].t,
                peak_wrist_speed=speeds[p],
                confidence=min(1.0, speeds[p] / peak_max) if peak_max else 0.0,
            )
        )
    return swings


def classify_swing(pose: PoseFrame, hand: Handedness) -> SwingType:
    """Coarse forehand/backhand/serve from wrist position at contact.

    Serve: wrist clearly above the head. Otherwise, which side of the body
    midline the wrist is on decides forehand vs backhand.
    """
    wrist_joint = Joint.R_WRIST if hand is not Handedness.LEFT else Joint.L_WRIST
    wrist, nose = pose.get(wrist_joint), pose.get(Joint.NOSE)
    com_l, com_r = pose.get(Joint.L_HIP), pose.get(Joint.R_HIP)
    if wrist is None:
        return SwingType.UNKNOWN

    if nose is not None and wrist.y < nose.y - 0.05:   # y grows downward
        return SwingType.SERVE
    if com_l is None or com_r is None:
        return SwingType.UNKNOWN

    midline = (com_l.x + com_r.x) / 2
    on_dominant_side = wrist.x > midline if hand is not Handedness.LEFT else wrist.x < midline
    return SwingType.FOREHAND if on_dominant_side else SwingType.BACKHAND
