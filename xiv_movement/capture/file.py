"""Capture adapter: a video file. Device-specific, deliberately thin."""

import cv2


def from_video(path):
    """Yields (timestamp_seconds, frame_bgr)."""
    cap = cv2.VideoCapture(str(path))
    if not cap.isOpened():
        raise SystemExit(f"Could not open {path}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
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
