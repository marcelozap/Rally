"""End-to-end orchestration: video -> pose -> smooth -> events -> metrics -> advice."""
from __future__ import annotations

from pathlib import Path
from typing import Callable


from rally_coach.advice.rules import advise
from rally_coach.core.types import Analysis, PoseFrame
from rally_coach.events.swing import detect_handedness, detect_swings
from rally_coach.metrics.summary import summarize
from rally_coach.tracking.smoothing import OneEuroPoseFilter

DEFAULT_CONFIG = Path(__file__).resolve().parents[2] / "config" / "pipeline.yaml"


def load_config(path: str | Path | None = None) -> dict:
    import yaml  # noqa: PLC0415
    p = Path(path) if path else DEFAULT_CONFIG
    if not p.exists():
        return {}
    return yaml.safe_load(p.read_text(encoding="utf-8")) or {}

def analyze_poses(
    poses: list[PoseFrame],
    fps: float,
    clip: str = "<memory>",
    frame_count: int | None = None,
    config: dict | None = None,
) -> Analysis:
    """Everything after pose detection. Pure — no video, no model, fully testable.

    Split out from analyze() deliberately: this is the half that holds all the
    logic worth testing, and it runs without mediapipe or a video file.
    """
    cfg = config or {}
    swing_cfg = cfg.get("events", {}).get("swing", {})
    advice_cfg = cfg.get("advice", {})

    hand = detect_handedness(poses)
    swings = detect_swings(
        poses,
        hand,
        min_wrist_speed=swing_cfg.get("min_wrist_speed", 2.5),
        min_separation_frames=swing_cfg.get("min_separation_frames", 12),
    )
    n = frame_count if frame_count is not None else len(poses)
    analysis = Analysis(
        clip=clip,
        fps=fps,
        frame_count=n,
        duration_s=(n / fps) if fps else 0.0,
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


def analyze(
    clip: str | Path,
    config: dict | None = None,
    on_frame: Callable[[int, PoseFrame], None] | None = None,
) -> Analysis:
    """Full pipeline: read the video, detect pose, then hand off to analyze_poses."""
    from rally_coach.io.video import VideoSource  # noqa: PLC0415 — keeps cv2 optional
    from rally_coach.pose.base import get_backend  # noqa: PLC0415

    cfg = config or load_config()
    pose_cfg = cfg.get("pose", {})
    smooth_cfg = cfg.get("smoothing", {})

    backend = get_backend(
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
        with VideoSource(clip, max_dimension=cfg.get("video", {}).get("max_dimension", 1280)) as src:
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
        backend.close()

    return analyze_poses(poses, info.fps, str(clip), info.frame_count, cfg)
