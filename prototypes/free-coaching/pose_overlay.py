import argparse
import json
import time
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run MediaPipe pose detection on a video and save an annotated copy."
    )
    parser.add_argument("--input", required=True, help="Path to a phone video file.")
    parser.add_argument(
        "--output",
        default="data/processed-videos/pose-overlay.mp4",
        help="Path for the annotated output video.",
    )
    parser.add_argument(
        "--summary",
        default="data/processed-videos/pose-summary.json",
        help="Path for the JSON diagnostics summary.",
    )
    parser.add_argument(
        "--max-frames",
        type=int,
        default=0,
        help="Optional frame limit for quick tests. 0 means process the full video.",
    )
    return parser.parse_args()


def mean_visibility(landmarks):
    if not landmarks:
        return 0.0
    return float(np.mean([landmark.visibility for landmark in landmarks]))


def main():
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)
    summary_path = Path(args.summary)

    if not input_path.exists():
        raise FileNotFoundError(f"Input video not found: {input_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.parent.mkdir(parents=True, exist_ok=True)

    cap = cv2.VideoCapture(str(input_path))
    if not cap.isOpened():
        raise RuntimeError(f"Could not open video: {input_path}")

    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(output_path), fourcc, fps, (width, height))

    mp_pose = mp.solutions.pose
    mp_drawing = mp.solutions.drawing_utils
    mp_styles = mp.solutions.drawing_styles

    processed = 0
    detected = 0
    visibility_values = []
    start = time.perf_counter()

    with mp_pose.Pose(
        static_image_mode=False,
        model_complexity=1,
        smooth_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    ) as pose:
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            if args.max_frames and processed >= args.max_frames:
                break

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            rgb.flags.writeable = False
            result = pose.process(rgb)

            if result.pose_landmarks:
                detected += 1
                visibility = mean_visibility(result.pose_landmarks.landmark)
                visibility_values.append(visibility)
                mp_drawing.draw_landmarks(
                    frame,
                    result.pose_landmarks,
                    mp_pose.POSE_CONNECTIONS,
                    landmark_drawing_spec=mp_styles.get_default_pose_landmarks_style(),
                )
                cv2.putText(
                    frame,
                    f"Pose visibility: {visibility:.2f}",
                    (24, 72),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.8,
                    (40, 220, 40),
                    2,
                    cv2.LINE_AA,
                )
            else:
                cv2.putText(
                    frame,
                    "Pose not detected",
                    (24, 72),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.8,
                    (40, 40, 220),
                    2,
                    cv2.LINE_AA,
                )

            elapsed = max(time.perf_counter() - start, 1e-6)
            live_fps = (processed + 1) / elapsed
            cv2.putText(
                frame,
                f"FPS: {live_fps:.1f}",
                (24, 36),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.8,
                (255, 255, 255),
                2,
                cv2.LINE_AA,
            )

            writer.write(frame)
            processed += 1

    cap.release()
    writer.release()

    total_elapsed = max(time.perf_counter() - start, 1e-6)
    summary = {
        "input": str(input_path),
        "output": str(output_path),
        "source_fps": fps,
        "width": width,
        "height": height,
        "source_frame_count": frame_count,
        "processed_frames": processed,
        "pose_detected_frames": detected,
        "pose_detection_rate": detected / processed if processed else 0.0,
        "mean_landmark_visibility": float(np.mean(visibility_values))
        if visibility_values
        else 0.0,
        "processing_fps": processed / total_elapsed,
    }

    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
