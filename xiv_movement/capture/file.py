"""Capture adapter: a video file. Device-specific, deliberately thin."""

import cv2
import math


def _fps(cap):
    value = cap.get(cv2.CAP_PROP_FPS)
    return value if math.isfinite(value) and value > 0 else 30.0


def video_fps(path):
    """Read the source rate used for timestamps and encoded overlays."""
    cap = cv2.VideoCapture(str(path))
    try:
        if not cap.isOpened():
            raise SystemExit(f"Could not open {path}")
        return _fps(cap)
    finally:
        cap.release()


def from_video(path):
    """Yields (timestamp_seconds, frame_bgr)."""
    cap = cv2.VideoCapture(str(path))
    if not cap.isOpened():
        cap.release()
        raise SystemExit(f"Could not open {path}")
    fps = _fps(cap)
    i = 0
    try:
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            yield i / fps, frame
            i += 1
    finally:
        cap.release()
