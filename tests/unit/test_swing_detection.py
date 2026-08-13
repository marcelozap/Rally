import math

from rally_coach.core.types import Handedness, Joint, Keypoint, PoseFrame
from rally_coach.events.swing import detect_handedness, detect_swings, wrist_speeds


def _clip(wrist_path: list[tuple[float, float]], fps: float = 60.0) -> list[PoseFrame]:
    frames = []
    for i, (x, y) in enumerate(wrist_path):
        frames.append(PoseFrame(index=i, t=i / fps, joints={
            Joint.R_WRIST: Keypoint(x=x, y=y),
            Joint.L_WRIST: Keypoint(x=0.5, y=0.5),
            Joint.L_HIP: Keypoint(x=0.45, y=0.6),
            Joint.R_HIP: Keypoint(x=0.55, y=0.6),
            Joint.NOSE: Keypoint(x=0.5, y=0.2),
        }))
    return frames


def test_still_clip_has_no_swings():
    poses = _clip([(0.5, 0.5)] * 40)
    assert detect_swings(poses, Handedness.RIGHT) == []


def test_single_burst_detected_once():
    # slow, one fast sweep, slow again
    path = [(0.5, 0.5)] * 10 + [(0.5 + 0.05 * i, 0.5) for i in range(6)] + [(0.8, 0.5)] * 20
    poses = _clip(path)
    swings = detect_swings(poses, Handedness.RIGHT, min_wrist_speed=1.0)
    assert len(swings) == 1
    s = swings[0]
    assert s.start_frame <= s.contact_frame <= s.end_frame


def test_handedness_follows_the_moving_wrist():
    poses = _clip([(0.5 + 0.01 * i, 0.5) for i in range(30)])
    assert detect_handedness(poses) is Handedness.RIGHT


def test_wrist_speed_is_zero_for_first_frame():
    poses = _clip([(0.5, 0.5), (0.6, 0.5)])
    speeds = wrist_speeds(poses, Handedness.RIGHT)
    assert speeds[0] == 0.0
    assert math.isclose(speeds[1], 0.1 * 60.0, rel_tol=1e-6)
