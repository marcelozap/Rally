"""Capture adapter: a live camera. Same output shape as from_video, so the core
never learns where frames came from."""

import time
import cv2


def from_webcam(index=0, mirror=True):
    """Yields (timestamp_seconds, frame_bgr)."""
    cap = cv2.VideoCapture(index)
    if not cap.isOpened():
        raise SystemExit(f"No camera at index {index}")
    t0 = time.time()
    try:
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            if mirror:
                frame = cv2.flip(frame, 1)
            yield time.time() - t0, frame
    finally:
        cap.release()
