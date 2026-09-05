"""Regression checks; scripted poses isolate processing from model accuracy."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

import cv2
import numpy as np

from xiv_movement.capture.file import _fps, from_video, video_fps
from xiv_movement.core import session
from xiv_movement.core.pose import PoseExtractor


def landmarks():
    points = np.zeros((33, 4), dtype=float)
    points[:, 3] = 1
    for a, b, y in [(11, 12, 60), (13, 14, 90), (15, 16, 120),
                    (23, 24, 140), (25, 26, 190), (27, 28, 240)]:
        points[a, :2] = (80, y)
        points[b, :2] = (160, y)
    return points


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.pose_patch = patch.object(session, "PoseExtractor")
        self.pose = self.pose_patch.start().return_value.__enter__.return_value
        self.addCleanup(self.pose_patch.stop)
        self.frame = np.zeros((320, 240, 3), dtype=np.uint8)

    def test_hidden_wrist_is_not_reported_as_measured(self):
        points = landmarks()
        points[15, 3] = 0.1
        self.pose.return_value = (points, None)
        rows = session.analyze_source([(0, self.frame)])
        self.assertTrue(np.isnan(rows[0]["l_elbow_angle"]))
        self.assertTrue(np.isnan(rows[0]["elbow_asymmetry"]))
        self.assertAlmostEqual(rows[0]["r_elbow_angle"], 180)
        self.assertAlmostEqual(rows[0]["trunk_lean"], 0)

    def test_hidden_torso_rejects_entire_frame(self):
        points = landmarks()
        points[23, 3] = 0.2
        self.pose.return_value = (points, None)
        self.assertEqual(session.analyze_source([(0, self.frame)]), [])

    def test_lost_tracking_does_not_show_previous_measurements(self):
        self.pose.side_effect = [(landmarks(), None), (None, None)]
        with patch.object(session.cv2, "VideoWriter") as writer, \
             patch.object(session, "_hud") as hud, \
             patch.object(session.cv2, "putText") as text:
            rows = session.analyze_source(
                [(0, self.frame), (1 / 60, self.frame)],
                overlay_path="test.mp4", overlay_fps=60,
            )
        self.assertEqual(len(rows), 1)
        self.assertEqual(hud.call_count, 1)
        self.assertEqual(text.call_args.args[1], "Tracking unavailable")
        self.assertEqual(writer.call_args.args[2], 60)
        writer.return_value.release.assert_called_once()

    def test_failure_releases_encoder_and_frame_source(self):
        self.pose.return_value = (landmarks(), None)
        closed = []

        def frames():
            try:
                yield 0, self.frame
                raise RuntimeError("frame read failed")
            finally:
                closed.append(True)

        with patch.object(session.cv2, "VideoWriter") as writer:
            with self.assertRaisesRegex(RuntimeError, "frame read failed"):
                session.analyze_source(frames(), overlay_path="test.mp4")
        self.assertEqual(closed, [True])
        writer.return_value.release.assert_called_once()

    def test_encoder_failure_is_reported(self):
        self.pose.return_value = (landmarks(), None)
        with patch.object(session.cv2, "VideoWriter") as writer:
            writer.return_value.isOpened.return_value = False
            with self.assertRaisesRegex(RuntimeError, "Could not write overlay"):
                session.analyze_source([(0, self.frame)], overlay_path="test.mp4")
        writer.return_value.release.assert_called_once()

    def test_invalid_overlay_rates_are_rejected(self):
        for fps in [0, -1, float("nan"), float("inf")]:
            with self.subTest(fps=fps), self.assertRaises(ValueError):
                session.analyze_source([], overlay_fps=fps)


class CaptureTests(unittest.TestCase):
    def test_invalid_metadata_uses_finite_fallback(self):
        cap = MagicMock()
        for value in [0, -1, float("nan"), float("inf")]:
            cap.get.return_value = value
            self.assertEqual(_fps(cap), 30)

    def test_real_video_timestamps_match_24_and_60_fps(self):
        with tempfile.TemporaryDirectory() as tmp:
            for fps in [24, 60]:
                with self.subTest(fps=fps):
                    path = Path(tmp) / f"source-{fps}.mp4"
                    writer = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"),
                                             fps, (64, 64))
                    self.assertTrue(writer.isOpened())
                    for _ in range(12):
                        writer.write(np.zeros((64, 64, 3), dtype=np.uint8))
                    writer.release()
                    source = list(from_video(path))
                    self.assertEqual(len(source), 12)
                    self.assertAlmostEqual(video_fps(path), fps)
                    self.assertAlmostEqual(source[-1][0], 11 / fps)

    def test_missing_input_fails_clearly(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(SystemExit, "Could not open"):
                video_fps(Path(tmp) / "missing.mp4")

    def test_incompatible_mediapipe_has_actionable_error(self):
        with patch("xiv_movement.core.pose.mp", new=object()):
            with self.assertRaisesRegex(RuntimeError, "requirements.txt"):
                PoseExtractor()


if __name__ == "__main__":
    unittest.main()
