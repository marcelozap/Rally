"""Court calibration — maps normalised image coordinates to court metres.

Until this is wired up, every metric in the system is in normalised units
(fractions of frame size), which means metrics are only comparable BETWEEN
clips shot from the same camera position. Calibrating is what makes
"moved 0.03 laterally" become "moved 12 cm".

Singles court: 8.23 m wide x 23.77 m long. Doubles: 10.97 m wide.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np

SINGLES_WIDTH_M = 8.23
DOUBLES_WIDTH_M = 10.97
COURT_LENGTH_M = 23.77


@dataclass(frozen=True)
class CourtCalibration:
    """Homography from image space to court plane.

    image_points: 4 court corners in normalised image coords, clockwise from
                  the near-left corner.
    court_points: the same 4 corners in metres.
    """

    homography: np.ndarray

    @classmethod
    def from_points(
        cls,
        image_points: list[tuple[float, float]],
        court_points: list[tuple[float, float]] | None = None,
        doubles: bool = False,
    ) -> "CourtCalibration":
        import cv2  # noqa: PLC0415

        if len(image_points) != 4:
            raise ValueError("need exactly 4 image points, clockwise from near-left")
        if court_points is None:
            w = DOUBLES_WIDTH_M if doubles else SINGLES_WIDTH_M
            court_points = [(0.0, 0.0), (w, 0.0), (w, COURT_LENGTH_M), (0.0, COURT_LENGTH_M)]
        h, _ = cv2.findHomography(
            np.array(image_points, dtype=np.float32),
            np.array(court_points, dtype=np.float32),
        )
        if h is None:
            raise ValueError("homography failed — are the 4 points collinear or mis-ordered?")
        return cls(homography=h)

    def to_court(self, x: float, y: float) -> tuple[float, float]:
        """Normalised image point -> court metres."""
        v = self.homography @ np.array([x, y, 1.0])
        if abs(v[2]) < 1e-12:
            raise ValueError("degenerate projection")
        return (float(v[0] / v[2]), float(v[1] / v[2]))

    def distance_m(self, p1: tuple[float, float], p2: tuple[float, float]) -> float:
        a, b = self.to_court(*p1), self.to_court(*p2)
        return float(np.hypot(b[0] - a[0], b[1] - a[1]))
