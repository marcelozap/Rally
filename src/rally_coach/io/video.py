"""Video reading. The only place cv2.VideoCapture is allowed to appear."""
from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np


@dataclass(frozen=True)
class ClipInfo:
    path: Path
    fps: float
    frame_count: int
    width: int
    height: int

    @property
    def duration_s(self) -> float:
        return self.frame_count / self.fps if self.fps else 0.0


class VideoSource:
    """Iterate frames from a video file, optionally downscaled.

    Usage:
        with VideoSource("clip.mp4", max_dimension=1280) as src:
            for i, t, frame in src:
                ...
    """

    def __init__(self, path: str | Path, max_dimension: int | None = 1280) -> None:
        self.path = Path(path)
        if not self.path.exists():
            raise FileNotFoundError(self.path)
        self.max_dimension = max_dimension
        self._cap: cv2.VideoCapture | None = None

    def __enter__(self) -> VideoSource:
        self._cap = cv2.VideoCapture(str(self.path))
        if not self._cap.isOpened():
            raise RuntimeError(f"could not open video: {self.path}")
        return self

    def __exit__(self, *exc: object) -> None:
        if self._cap is not None:
            self._cap.release()
            self._cap = None

    @property
    def info(self) -> ClipInfo:
        if self._cap is None:
            raise RuntimeError("VideoSource must be used as a context manager")
        return ClipInfo(
            path=self.path,
            fps=self._cap.get(cv2.CAP_PROP_FPS) or 30.0,
            frame_count=int(self._cap.get(cv2.CAP_PROP_FRAME_COUNT)),
            width=int(self._cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
            height=int(self._cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
        )

    def _resize(self, frame: np.ndarray) -> np.ndarray:
        if self.max_dimension is None:
            return frame
        h, w = frame.shape[:2]
        longest = max(h, w)
        if longest <= self.max_dimension:
            return frame
        scale = self.max_dimension / longest
        return cv2.resize(frame, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)

    def __iter__(self) -> Iterator[tuple[int, float, np.ndarray]]:
        if self._cap is None:
            raise RuntimeError("VideoSource must be used as a context manager")
        fps = self.info.fps
        i = 0
        while True:
            ok, frame = self._cap.read()
            if not ok:
                break
            yield i, i / fps, self._resize(frame)
            i += 1
