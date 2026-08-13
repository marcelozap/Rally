"""The pose backend interface.

Everything downstream depends on THIS, never on mediapipe or movenet directly.
Adding a backend means implementing one class; nothing else changes.
"""
from __future__ import annotations

from typing import Protocol, runtime_checkable

import numpy as np

from rally_coach.core.types import PoseFrame


@runtime_checkable
class PoseEstimator(Protocol):
    """Detect one person's pose per frame."""

    name: str

    def estimate(self, frame: np.ndarray, index: int, t: float) -> PoseFrame | None:
        """Return a PoseFrame, or None when no person is confidently detected."""
        ...

    def close(self) -> None: ...


def get_backend(name: str, **kwargs: object) -> PoseEstimator:
    """Factory. Keeps backend imports lazy so an unused backend never has to install."""
    if name == "mediapipe":
        from rally_coach.pose.mediapipe_backend import MediaPipePose

        return MediaPipePose(**kwargs)  # type: ignore[arg-type]
    if name == "movenet":
        raise NotImplementedError(
            "movenet backend not implemented yet — implement PoseEstimator in "
            "rally_coach/pose/movenet_backend.py and register it here"
        )
    raise ValueError(f"unknown pose backend: {name!r}")
