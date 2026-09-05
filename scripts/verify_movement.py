"""Exercise the real MediaPipe model and CSV/overlay pipeline without a camera.

An image produces a repeated-photo video: this tests inference and plumbing,
not movement/biomechanical accuracy. Use --video for an actual practice clip.
No input is uploaded; artifacts are written to the selected local directory.
"""

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from xiv_movement.capture.file import from_video, video_fps
from xiv_movement.core.session import analyze_source, write_csv


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    inputs = parser.add_mutually_exclusive_group(required=True)
    inputs.add_argument("--image", type=Path)
    inputs.add_argument("--video", type=Path)
    parser.add_argument("--output", type=Path, default=Path("artifacts/verification"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    source = args.video
    if args.image:
        frame = cv2.imread(str(args.image))
        if frame is None:
            parser.error(f"Could not read image: {args.image}")
        # Codecs require even dimensions.
        h, w = frame.shape[:2]
        frame = frame[:h - h % 2, :w - w % 2]
        source = args.output / "repeated-photo-60fps.mp4"
        writer = cv2.VideoWriter(str(source), cv2.VideoWriter_fourcc(*"mp4v"),
                                 60, (frame.shape[1], frame.shape[0]))
        if not writer.isOpened():
            raise SystemExit(f"Could not create {source}")
        try:
            for _ in range(30):
                writer.write(frame)
        finally:
            writer.release()

    fps = video_fps(source)
    overlay = args.output / "overlay.mp4"
    csv_path = args.output / "metrics.csv"
    rows = analyze_source(from_video(source), overlay_path=overlay, overlay_fps=fps)
    write_csv(rows, csv_path)
    if not all(np.isfinite(row["hip_shoulder_separation"]) for row in rows):
        raise SystemExit("Torso measurements were not finite")
    captured = cv2.VideoCapture(str(overlay))
    try:
        overlay_frames = int(captured.get(cv2.CAP_PROP_FRAME_COUNT))
        overlay_rate = captured.get(cv2.CAP_PROP_FPS)
        readable, _ = captured.read()
    finally:
        captured.release()
    if not readable or abs(overlay_rate - fps) > 0.01:
        raise SystemExit("Overlay is unreadable or its playback rate changed")
    result = {
        "model": "MediaPipe Pose (real inference)",
        "input_kind": "repeated photo; not a movement validation" if args.image else "video",
        "usable_frames": len(rows),
        "overlay_frames": overlay_frames,
        "source_fps": fps,
        "overlay_fps": overlay_rate,
        "csv": str(csv_path),
        "overlay": str(overlay),
    }
    (args.output / "result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
