"""Orchestration. Source of frames -> rows of metrics.

    frames -> keypoints + confidence -> smooth -> metrics

The source is any iterable of (timestamp, frame). A file and a webcam are
interchangeable here, which is the whole point of the capture/core split.
"""

import csv
import numpy as np
import cv2

from .pose import PoseExtractor
from .filters import KeypointFilter
from .metrics import compute_metrics, METRIC_NAMES

MIN_VISIBILITY = 0.5


def analyze_source(source, show=False, overlay_path=None, on_row=None, window="xiv-movement"):
    """Run the pipeline over a frame source. Returns a list of metric dicts."""
    rows = []
    writer = None
    prev_t = None

    with PoseExtractor() as pose:
        kf = KeypointFilter()
        for t, frame in source:
            pts, landmarks = pose(frame)

            if pts is not None:
                core = [11, 12, 23, 24]
                if np.min(pts[core, 3]) >= MIN_VISIBILITY:
                    dt = 1 / 30.0 if prev_t is None else max(t - prev_t, 1e-3)
                    prev_t = t
                    smoothed = kf(pts, dt)
                    row = {"t": round(t, 4), **compute_metrics(smoothed)}
                    rows.append(row)
                    if on_row:
                        on_row(row, frame)

            if show or overlay_path:
                pose.draw(frame, landmarks)
                if rows:
                    _hud(frame, rows[-1])
            if overlay_path:
                if writer is None:
                    h, w = frame.shape[:2]
                    writer = cv2.VideoWriter(
                        str(overlay_path), cv2.VideoWriter_fourcc(*"mp4v"), 30, (w, h)
                    )
                writer.write(frame)
            if show:
                cv2.imshow(window, frame)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break

    if writer:
        writer.release()
    if show:
        cv2.destroyAllWindows()
    return rows


def _hud(frame, row):
    for i, k in enumerate(("hip_shoulder_separation", "trunk_lean", "elbow_asymmetry")):
        cv2.putText(frame, f"{k:<26}{row[k]:7.1f}", (12, 30 + i * 26),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 120), 2)


def write_csv(rows, path):
    if not rows:
        raise SystemExit("No usable frames — check framing, light, and that the whole body is visible.")
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["t"] + METRIC_NAMES)
        w.writeheader()
        w.writerows(rows)
    return path
