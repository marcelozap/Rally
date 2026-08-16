"""The backend factory contract.

These run without mediapipe or tensorflow installed, on purpose: the point of
`PoseEstimator` is that nothing outside `pose/` needs a model runtime.
"""
from __future__ import annotations

import pytest

from fixtures.synthetic import ScriptedPoseEstimator
from rally_coach.pose.base import PoseEstimator, get_backend


def test_a_plain_class_satisfies_the_protocol():
    """No base class, no registration — implement two methods and you are a backend."""
    assert isinstance(ScriptedPoseEstimator(), PoseEstimator)


def test_unknown_backend_names_are_rejected():
    with pytest.raises(ValueError, match="unknown pose backend"):
        get_backend("mediapipe-lite")


def test_movenet_fails_at_construction_not_mid_clip():
    """A bad backend in config must surface before a video is ever opened."""
    with pytest.raises(NotImplementedError, match="movenet backend is a stub"):
        get_backend("movenet")


def test_movenet_maps_every_joint_the_rest_of_the_code_expects():
    """The stub's landmark map is the part worth getting right up front."""
    from rally_coach.core.types import Joint
    from rally_coach.pose.movenet_backend import _LANDMARK_MAP

    assert set(_LANDMARK_MAP.values()) == set(Joint)
    assert len(_LANDMARK_MAP) == len(Joint), "a COCO index is mapped twice"
