"""Smoothing.

Every metric that matters is a derivative — angles change, velocities, timing.
Differentiating raw keypoints amplifies noise into garbage, so filtering is
required rather than optional.

Constant-velocity Kalman per coordinate. Output is a position estimate AND a
variance: the model never returns a point, it returns a point plus how sure it is.
"""

import numpy as np


class _Scalar1D:
    """Constant-velocity Kalman filter on one scalar coordinate."""

    def __init__(self, q=1.0, r=8.0):
        self.x = None                     # [position, velocity]
        self.P = np.eye(2) * 100.0
        self.q, self.r = q, r

    def update(self, z, dt, meas_var=None):
        if self.x is None:
            self.x = np.array([z, 0.0])
            return self.x[0], self.P[0, 0]

        F = np.array([[1.0, dt], [0.0, 1.0]])
        G = np.array([0.5 * dt * dt, dt])
        Q = np.outer(G, G) * self.q

        self.x = F @ self.x
        self.P = F @ self.P @ F.T + Q

        R = self.r if meas_var is None else meas_var
        H = np.array([1.0, 0.0])
        S = H @ self.P @ H + R
        K = (self.P @ H) / S
        self.x = self.x + K * (z - H @ self.x)
        self.P = (np.eye(2) - np.outer(K, H)) @ self.P
        return self.x[0], self.P[0, 0]

    @property
    def velocity(self):
        return 0.0 if self.x is None else self.x[1]


class KeypointFilter:
    """One Kalman per (landmark, axis). Low confidence -> high measurement noise,
    so an unsure keypoint moves the estimate less instead of jerking it."""

    def __init__(self, n_landmarks=33, axes=2, q=1.0, r=8.0):
        self.axes = axes
        self._f = [[_Scalar1D(q, r) for _ in range(axes)] for _ in range(n_landmarks)]

    def __call__(self, pts, dt):
        """pts: (33, 4) raw. Returns (33, axes) smoothed positions."""
        out = np.zeros((len(self._f), self.axes))
        for i, row in enumerate(pts):
            vis = max(row[3], 1e-3)
            meas_var = 8.0 / (vis ** 2)        # confidence -> measurement noise
            for a in range(self.axes):
                out[i, a], _ = self._f[i][a].update(row[a], dt, meas_var)
        return out

    def velocities(self):
        return np.array([[f.velocity for f in row] for row in self._f])
