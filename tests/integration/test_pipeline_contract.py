"""End-to-end contract test using a synthetic pose sequence.

Deliberately does NOT need a video file, cv2, or mediapipe. It drives the half
of the pipeline that holds all the logic — smoothing, swing detection, metrics,
advice, and the analysis.v1 round trip — which is the half that can silently
break without anyone noticing.
"""
from __future__ import annotations

import math

from rally_coach.core.types import Handedness, Joint, Keypoint, PoseFrame, SwingType
from rally_coach.export.writer import read, write
from rally_coach.pipeline import analyze_poses
from rally_coach.tracking.smoothing import OneEuroPoseFilter

FPS = 60.0


READY = (0.45, 0.55)
FINISH = (0.80, 0.47)


def synthetic_rally(n_swings: int = 3, fps: float = FPS) -> list[PoseFrame]:
    """A stick figure that swings n times.

    Ready -> fast sweep -> hold -> SLOW recovery back to ready. The recovery
    matters: an earlier version of this fixture teleported the wrist back to
    the start position in one frame, which is a bigger velocity spike than the
    swing itself and made the detector report 5 swings for 3. Real footage
    never teleports.
    """
    poses: list[PoseFrame] = []
    i = 0
    for _ in range(n_swings):
        for _ in range(18):                       # ready stance
            poses.append(_frame(i, i / fps, READY)); i += 1
        for k in range(1, 9):                     # fast sweep to contact
            f = k / 8
            poses.append(_frame(i, i / fps, _lerp(READY, FINISH, f))); i += 1
        for _ in range(10):                       # hold the finish
            poses.append(_frame(i, i / fps, FINISH)); i += 1
        for k in range(1, 25):                    # slow recovery, 3x the swing duration
            f = k / 24
            poses.append(_frame(i, i / fps, _lerp(FINISH, READY, f))); i += 1
    return poses


def _lerp(a: tuple[float, float], b: tuple[float, float], f: float) -> tuple[float, float]:
    return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)


def _frame(index: int, t: float, wrist: tuple[float, float]) -> PoseFrame:
    return PoseFrame(index=index, t=t, joints={
        Joint.NOSE: Keypoint(x=0.50, y=0.20),
        Joint.L_SHOULDER: Keypoint(x=0.44, y=0.35),
        Joint.R_SHOULDER: Keypoint(x=0.56, y=0.35),
        Joint.R_ELBOW: Keypoint(x=0.60, y=0.46),
        Joint.R_WRIST: Keypoint(x=wrist[0], y=wrist[1]),
        Joint.L_WRIST: Keypoint(x=0.40, y=0.55),
        Joint.L_HIP: Keypoint(x=0.46, y=0.60),
        Joint.R_HIP: Keypoint(x=0.54, y=0.60),
        Joint.L_KNEE: Keypoint(x=0.46, y=0.75),
        Joint.R_KNEE: Keypoint(x=0.54, y=0.75),
        Joint.L_ANKLE: Keypoint(x=0.46, y=0.90),
        Joint.R_ANKLE: Keypoint(x=0.54, y=0.90),
    })


def test_finds_every_swing():
    result = analyze_poses(synthetic_rally(3), FPS, clip="synthetic.mp4")
    assert len(result.swings) == 3
    assert result.handedness is Handedness.RIGHT


def test_swings_are_ordered_and_well_formed():
    result = analyze_poses(synthetic_rally(3), FPS, clip="synthetic.mp4")
    for s in result.swings:
        assert s.start_frame <= s.contact_frame <= s.end_frame
        assert s.start_t <= s.contact_t <= s.end_t
        assert 0.0 <= s.confidence <= 1.0
        assert s.type is not SwingType.UNKNOWN
    contacts = [s.contact_frame for s in result.swings]
    assert contacts == sorted(contacts)


def test_metrics_are_populated():
    result = analyze_poses(synthetic_rally(3), FPS, clip="synthetic.mp4")
    assert result.metrics["swing_count"] == 3.0
    assert result.metrics["max_peak_wrist_speed"] > 0
    assert "mean_knee_angle" in result.metrics


def test_still_clip_produces_no_swings():
    poses = [_frame(i, i / FPS, READY) for i in range(60)]
    result = analyze_poses(poses, FPS, clip="still.mp4")
    assert result.swings == []
    assert result.metrics["swing_count"] == 0.0


def test_analysis_v1_round_trips(tmp_path):
    result = analyze_poses(synthetic_rally(2), FPS, clip="synthetic.mp4")
    path = write(result, tmp_path / "out.json")
    back = read(path)
    assert back.schema_version == "analysis.v1"
    assert len(back.swings) == len(result.swings)
    assert back.metrics == result.metrics
    assert [n.code for n in back.notes] == [n.code for n in result.notes]


def test_rejects_wrong_schema_version(tmp_path):
    import json
    p = tmp_path / "bad.json"
    p.write_text(json.dumps({"schema_version": "analysis.v99", "clip": "x",
                             "fps": 60, "frame_count": 1, "duration_s": 1,
                             "swings": [], "metrics": {}, "notes": []}))
    try:
        read(p)
    except ValueError as e:
        assert "analysis.v99" in str(e)
    else:
        raise AssertionError("should have rejected an unknown schema version")


def test_smoothing_reduces_jitter_but_keeps_the_spike():
    """The reason One Euro is here rather than a moving average."""
    clean = synthetic_rally(1)
    jittered = []
    for i, p in enumerate(clean):
        w = p.joints[Joint.R_WRIST]
        noise = 0.004 * math.sin(i * 2.7)
        j = dict(p.joints)
        j[Joint.R_WRIST] = Keypoint(x=w.x + noise, y=w.y - noise)
        jittered.append(PoseFrame(index=p.index, t=p.t, joints=j))

    f = OneEuroPoseFilter()
    smoothed = [f.apply(p) for p in jittered]

    peak_clean = analyze_poses(clean, FPS).metrics["max_peak_wrist_speed"]
    m = analyze_poses(smoothed, FPS).metrics
    assert "max_peak_wrist_speed" in m, "smoothing destroyed the contact spike entirely"
    peak_smooth = m["max_peak_wrist_speed"]
    # The contact spike must survive smoothing. With the pre-tuning defaults
    # (beta=0.007) this returned zero swings — that is the regression this guards.
    assert peak_smooth > peak_clean * 0.65
    assert len(analyze_poses(smoothed, FPS).swings) == 1  # synthetic_rally(1)
