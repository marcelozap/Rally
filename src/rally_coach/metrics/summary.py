"""Derived movement metrics, aggregated across the clip."""
from __future__ import annotations

import statistics
from collections.abc import Iterable

from rally_coach.core.types import Handedness, PoseFrame, Swing
from rally_coach.geometry.angles import (
    center_of_mass,
    elbow_angle,
    knee_angle,
    separation_angle,
)


def _mean(values: Iterable[float | None]) -> float | None:
    clean = [v for v in values if v is not None]
    return statistics.fmean(clean) if clean else None


def summarize(
    poses: list[PoseFrame], swings: list[Swing], hand: Handedness
) -> dict[str, float]:
    by_index = {p.index: p for p in poses}
    side = "right" if hand is not Handedness.LEFT else "left"
    contacts = [by_index[s.contact_frame] for s in swings if s.contact_frame in by_index]

    out: dict[str, float] = {"swing_count": float(len(swings))}

    if swings:
        out["mean_peak_wrist_speed"] = statistics.fmean(s.peak_wrist_speed for s in swings)
        out["max_peak_wrist_speed"] = max(s.peak_wrist_speed for s in swings)
        out["mean_swing_duration_s"] = statistics.fmean(s.end_t - s.start_t for s in swings)

    if contacts:
        if (v := _mean(elbow_angle(p, side) for p in contacts)) is not None:
            out["mean_elbow_angle_at_contact"] = v
        if (v := _mean(separation_angle(p) for p in contacts)) is not None:
            out["mean_separation_at_contact"] = v

    if (v := _mean(knee_angle(p, side) for p in poses)) is not None:
        out["mean_knee_angle"] = v

    coms = [c for p in poses if (c := center_of_mass(p)) is not None]
    if len(coms) > 1:
        out["com_lateral_range"] = max(c[0] for c in coms) - min(c[0] for c in coms)
        out["com_vertical_range"] = max(c[1] for c in coms) - min(c[1] for c in coms)

    return {k: round(v, 4) for k, v in out.items()}
