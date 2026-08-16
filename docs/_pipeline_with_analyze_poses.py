# ============================================================================
# NOT IMPORTABLE FROM HERE. This is a copy of src/rally_coach/pipeline.py as it
# should be, parked in docs/ because Windows had the real file locked (another
# process — probably the lane that wrote tests/integration/test_pipeline_contract.py
# — had it open) and I would not clobber someone else's in-flight edit.
#
# The only difference from what is on disk: the pure half of the pipeline is
# split out as analyze_poses(), which test_pipeline_contract.py imports and
# which does not otherwise exist. Without it, that test file errors on import.
#
# BEFORE COPYING THIS OVER: check whether the other lane already added
# analyze_poses(). If it did, keep theirs and delete this file.
# ============================================================================

"""End-to-end orchestration: video -> pose -> smooth -> events -> metrics -> advice."""
from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

import yaml

from rally_coach.advice.rules import advise
from rally_coach.core.types import Analysis, PoseFrame
from rally_coach.events.swing import detect_handedness, detect_swings
from rally_coach.io.video import VideoSource
from rally_coach.metrics.summary import summarize
from rally_coach.pose.base import PoseEstimator, get_backend
from rally_coach.tracking.smoothing import OneEuroPoseFilter

DEFAULT_CONFIG = Path(__file__).resolve().parents[2] / "config" / "pipeline.yaml"


def load_config(path: str | Path | None = None) -> dict:
    p = Path(path) if path else DEFAULT_CONFIG
    if not p.exists():
        return {}
    return yaml.safe_load(p.read_text(encoding="utf-8")) or {}


def analyze(
    clip: str | Path,
    config: dict | None = None,
    on_frame: Callable[[int, PoseFrame], None] | None = None,
    *,
    estimator: PoseEstimator | None = None,
) -> Analysis:
    """Run the whole pipeline over `clip`.

    `estimator` overrides the configured backend with an already-constructed
    one. That is the seam `pose/base.PoseEstimator` exists for: it lets the
    integration tests drive every stage after the model with scripted poses,
    and it is how a caller supplies a warm backend instead of paying model
    startup per clip. An injected estimator is owned by the caller, so this
    function does not close it.
    """
    cfg = config or load_config()
    pose_cfg = cfg.get("pose", {})
    smooth_cfg = cfg.get("smoothing", {})
    # events/advice config is read by analyze_poses(), which this delegates to.

    owns_backend = estimator is None
    backend = estimator or get_backend(
        pose_cfg.get("backend", "mediapipe"),
        model_complexity=pose_cfg.get("model_complexity", 1),
        min_detection_confidence=pose_cfg.get("min_detection_confidence", 0.5),
        min_tracking_confidence=pose_cfg.get("min_tracking_confidence", 0.5),
    )
    smoother = OneEuroPoseFilter(
        min_cutoff=smooth_cfg.get("min_cutoff", 1.0),
        beta=smooth_cfg.get("beta", 0.007),
        d_cutoff=smooth_cfg.get("d_cutoff", 1.0),
    )

    poses: list[PoseFrame] = []
    try:
        max_dimension = cfg.get("video", {}).get("max_dimension", 1280)
        with VideoSource(clip, max_dimension=max_dimension) as src:
            info = src.info
            for i, t, frame in src:
                raw = backend.estimate(frame, i, t)
                if raw is None:
                    continue
                p = smoother.apply(raw)
                poses.append(p)
                if on_frame:
                    on_frame(i, p)
    finally:
        if owns_backend:
            backend.close()

    return analyze_poses(
        poses,
        info.fps,
        clip=str(clip),
        config=cfg,
        frame_count=info.frame_count,
        duration_s=info.duration_s,
    )


def analyze_poses(
    poses: list[PoseFrame],
    fps: float,
    clip: str | Path = "",
    config: dict | None = None,
    frame_count: int | None = None,
    duration_s: float | None = None,
) -> Analysis:
    """The pipeline from poses onward: handedness -> swings -> metrics -> advice.

    Split out from `analyze()` because everything here is pure: no video, no
    model, no I/O. That makes the analytical half testable on scripted poses,
    and it is the entry point to use when the poses came from somewhere other
    than a file on disk.

    `poses` are taken as given — smoothing happens during capture, not here, so
    a caller can measure the filter's effect by passing raw and smoothed
    sequences through the same function.

    `frame_count` and `duration_s` default to what the poses imply. Pass them
    explicitly when the clip is longer than the poses that survived detection.
    """
    cfg = config or load_config()
    swing_cfg = cfg.get("events", {}).get("swing", {})
    advice_cfg = cfg.get("advice", {})

    if frame_count is None:
        frame_count = (max(p.index for p in poses) + 1) if poses else 0
    if duration_s is None:
        duration_s = frame_count / fps if fps else 0.0

    hand = detect_handedness(poses)
    swings = detect_swings(
        poses,
        hand,
        min_wrist_speed=swing_cfg.get("min_wrist_speed", 2.5),
        min_separation_frames=swing_cfg.get("min_separation_frames", 12),
    )
    analysis = Analysis(
        clip=str(clip),
        fps=fps,
        frame_count=frame_count,
        duration_s=duration_s,
        handedness=hand,
        swings=swings,
        metrics=summarize(poses, swings, hand),
    )
    analysis.notes = advise(
        analysis,
        max_notes=advice_cfg.get("max_notes", 3),
        min_confidence=advice_cfg.get("min_confidence", 0.6),
    )
    return analysis
