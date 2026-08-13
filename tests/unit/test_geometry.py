import math

from rally_coach.core.types import Joint, Keypoint, PoseFrame
from rally_coach.geometry.angles import angle_at, separation_angle


def _pose(**joints: tuple[float, float]) -> PoseFrame:
    return PoseFrame(
        index=0, t=0.0,
        joints={Joint(k.replace("__", "_")): Keypoint(x=v[0], y=v[1]) for k, v in joints.items()},
    )


def test_right_angle():
    p = PoseFrame(index=0, t=0.0, joints={
        Joint.R_SHOULDER: Keypoint(x=0.0, y=0.0),
        Joint.R_ELBOW: Keypoint(x=0.0, y=1.0),
        Joint.R_WRIST: Keypoint(x=1.0, y=1.0),
    })
    assert math.isclose(angle_at(p, Joint.R_SHOULDER, Joint.R_ELBOW, Joint.R_WRIST), 90.0, abs_tol=1e-6)


def test_straight_arm_is_180():
    p = PoseFrame(index=0, t=0.0, joints={
        Joint.R_SHOULDER: Keypoint(x=0.0, y=0.0),
        Joint.R_ELBOW: Keypoint(x=0.0, y=1.0),
        Joint.R_WRIST: Keypoint(x=0.0, y=2.0),
    })
    assert math.isclose(angle_at(p, Joint.R_SHOULDER, Joint.R_ELBOW, Joint.R_WRIST), 180.0, abs_tol=1e-6)


def test_missing_joint_returns_none():
    p = PoseFrame(index=0, t=0.0, joints={Joint.R_SHOULDER: Keypoint(x=0.0, y=0.0)})
    assert angle_at(p, Joint.R_SHOULDER, Joint.R_ELBOW, Joint.R_WRIST) is None
    assert separation_angle(p) is None
