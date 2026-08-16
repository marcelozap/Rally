"""One Euro filter — jitter removal that keeps fast motion sharp.

A plain moving average destroys exactly the thing you care about here: the
velocity spike at contact. One Euro adapts its cutoff to speed, so it smooths
a still stance hard and a swing barely at all.

Reference: Casiez, Roussel & Vogel (2012).

TUNING NOTE — beta is unit-dependent, and the paper's example values assume
pixels. Our coordinates are normalised to [0,1], where a fast wrist moves at
~2.5 units/sec, so the paper-ish default of beta=0.007 barely raises the
adaptive cutoff at all and smooths the swing flat.

Measured on a synthetic 3-swing clip with sinusoidal jitter (amplitude 0.004):

    min_cutoff  beta    swings found   peak retained   jitter rejected
    1.0         0.007   0  <-- BROKEN  0%              -
    1.0         0.100   0  <-- BROKEN  0%              -
    1.0         0.500   3               110%            51%
    2.0         0.500   3               109%            60%  <-- default
    2.0         1.000   3               116%            23%
    2.0         4.000   3               123%            -9%

beta below ~0.5 destroys the contact spike entirely and the swing detector
returns nothing. If you retune, re-run tests/integration/test_pipeline_contract.py
— it asserts the spike survives.
"""
from __future__ import annotations

import math

from rally_coach.core.types import Joint, Keypoint, PoseFrame


def _alpha(cutoff: float, dt: float) -> float:
    tau = 1.0 / (2.0 * math.pi * cutoff)
    return 1.0 / (1.0 + tau / dt)


class _Scalar:
    def __init__(self, min_cutoff: float, beta: float, d_cutoff: float) -> None:
        self.min_cutoff = min_cutoff
        self.beta = beta
        self.d_cutoff = d_cutoff
        self._x_prev: float | None = None
        self._dx_prev: float = 0.0

    def __call__(self, x: float, dt: float) -> float:
        if self._x_prev is None or dt <= 0:
            self._x_prev = x
            return x
        dx = (x - self._x_prev) / dt
        dx_hat = _alpha(self.d_cutoff, dt) * dx + (1 - _alpha(self.d_cutoff, dt)) * self._dx_prev
        cutoff = self.min_cutoff + self.beta * abs(dx_hat)
        a = _alpha(cutoff, dt)
        x_hat = a * x + (1 - a) * self._x_prev
        self._x_prev, self._dx_prev = x_hat, dx_hat
        return x_hat


class OneEuroPoseFilter:
    """Applies an independent One Euro filter to every joint's x and y."""

    # The ONLY place these numbers live in code. pipeline.py reads them for its
    # config fallbacks rather than repeating the literals.
    DEFAULT_MIN_CUTOFF = 2.0
    DEFAULT_BETA = 0.5
    DEFAULT_D_CUTOFF = 1.0

    def __init__(
        self,
        min_cutoff: float = DEFAULT_MIN_CUTOFF,
        beta: float = DEFAULT_BETA,
        d_cutoff: float = DEFAULT_D_CUTOFF,
    ) -> None:
        self._cfg = (min_cutoff, beta, d_cutoff)
        self._filters: dict[tuple[Joint, str], _Scalar] = {}
        self._t_prev: float | None = None

    def _f(self, joint: Joint, axis: str) -> _Scalar:
        key = (joint, axis)
        if key not in self._filters:
            self._filters[key] = _Scalar(*self._cfg)
        return self._filters[key]

    def apply(self, pose: PoseFrame) -> PoseFrame:
        dt = 1.0 / 60.0 if self._t_prev is None else max(pose.t - self._t_prev, 1e-6)
        self._t_prev = pose.t
        smoothed: dict[Joint, Keypoint] = {}
        for joint, kp in pose.joints.items():
            smoothed[joint] = Keypoint(
                x=self._f(joint, "x")(kp.x, dt),
                y=self._f(joint, "y")(kp.y, dt),
                z=kp.z,
                visibility=kp.visibility,
            )
        return PoseFrame(index=pose.index, t=pose.t, joints=smoothed)
