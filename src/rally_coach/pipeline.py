"""End-to-end orchestration: video -> pose -> smooth -> events -> metrics -> advice."""
from __future__ import annotations

import logging
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

log = logging.getLogger(__name__)

# NOTE: this resolves against the source checkout. Installed as a wheel there is
# no `config/` two directories up from the package, so this path does not exist
# and load_config() returns {} — see the warning it emits.
DEFAULT_CONFIG = Path(__file__).resolve().parents[2] / "config" / "pipeline.yaml"


def load_config(path: str | Path | None = None) -> dict:
    """Load pipeline config, or return {} — loudly — if it isn't there.

    A missing config is not fatal: every caller falls back to the in-code
    defaults. But it must never be silent. The defaults it falls back to decide
    whether the swing detector finds anything at all, and a config that quietly
    failed to load looks identical, from the outside, to a clip with no swings
    in it.
    """
    p = Path(path) if path else DEFAULT_CONFIG
    if not p.exists():
        log.warning(
            "pipeline config not found at %s — falling back to in-code defaults. "
            "(DEFAULT_CONFIG resolves relative to the source tree, so this is expected "
            "when running from an installed wheel; pass config= or a path explicitly.)",
            p,
        )
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
    cfg = load_config() if config is None else config
    pose_cfg = cfg.get("pose", {})
    smooth_cfg = cfg.get("smoothing", {})

    owns_backend = estimator is None
    backend = estimator or get_backend(
        pose_cfg.get("backend", "mediapipe"),
        model_complexity=pose_cfg.get("model_complexity", 1),
        min_detection_confidence=pose_cfg.get("min_detection_confidence", 0.5),
        min_tracking_confidence=pose_cfg.get("min_tracking_confidence", 0.5),
    )
    # One source of truth: the fallbacks ARE the class defaults. Literals here
    # were how the pre-tuning values (min_cutoff=1.0, beta=0.007) survived the
    # fix in smoothing.py and came back whenever the config failed to load —
    # which silently returns zero swings. Do not re-inline them.
    smoother = OneEuroPoseFilter(
        min_cutoff=smooth_cfg.get("min_cutoff", OneEuroPoseFilter.DEFAULT_MIN_CUTOFF),
        beta=smooth_cfg.get("beta", OneEuroPoseFilter.DEFAULT_BETA),
        d_cutoff=smooth_cfg.get("d_cutoff", OneEuroPoseFilter.DEFAULT_D_CUTOFF),
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
    """Analyze an existing pose sequence without opening a video or model.

    Poses are used as supplied; callers that want smoothing apply it first.
    Pass source metadata when detection gaps would otherwise shorten the clip.
    """
    cfg = load_config() if config is None else config
    swing_cfg = cfg.get("events", {}).get("swing", {})
    advice_cfg = cfg.get("advice", {})
    if frame_count is None:
        frame_count = max((p.index for p in poses), default=-1) + 1
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
