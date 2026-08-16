"""Synthetic clip + pose fixtures for the integration tests.

WHY SYNTHETIC. The pipeline needs footage to run, but real footage in the repo
means a committed binary, a mediapipe model download in CI, and landmarks that
drift between library versions. So the rally is scripted in code and replayed
through the `PoseEstimator` protocol from `pose/base.py` — the same seam a real
backend plugs into. The test then exercises every stage after the model
(smoothing -> swing detection -> metrics -> advice -> analysis.v1.json) with
zero model dependency and byte-identical results on every machine.

A real video file IS still written (to a tmp dir, never to the repo) so that
`io/video.py` is exercised for real: open, iterate, resize, report fps and
frame count. The estimator ignores the pixels — they exist so the clip is
inspectable by a human, and they follow the XIV overlay standard: cyan skeleton
on void, magenta at contact.

THE SCRIPT. 3.0s at 60fps: ready stance, one forehand, a recovery step, one
serve, settle. Wrist speed has exactly two peaks, one per swing, with every
other phase held well below them. Each contact pose is unambiguous for the
position-based classifier in `events/swing.py`:
  - forehand contact: wrist right of the hip midline, well below the nose
  - serve contact:    wrist clearly above the nose
Four frames are dropped on purpose (simulated detection loss) so the pipeline's
"no person this frame" path is covered too.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np

from rally_coach.core.types import Joint, Keypoint, PoseFrame

# --- clip shape --------------------------------------------------------------
FPS = 60.0
CLIP_SECONDS = 3.0
FRAME_COUNT = round(FPS * CLIP_SECONDS)               # 180 — under the ~3s cap
FRAME_W = 640
FRAME_H = 360

# Frames where the "detector" reports no person. Idle phase, far from contact.
DROPPED_FRAMES = frozenset(range(20, 24))

# --- neutral stance, normalised frame coords (x right, y DOWN) ---------------
NOSE_X, NOSE_Y = 0.500, 0.180
SHOULDER_Y, SHOULDER_HALF = 0.300, 0.060
ELBOW_Y, ELBOW_HALF = 0.420, 0.090
HIP_Y, HIP_HALF = 0.550, 0.040
KNEE_Y, KNEE_HALF = 0.720, 0.045
ANKLE_Y, ANKLE_HALF = 0.880, 0.050
LEFT_WRIST_X, LEFT_WRIST_Y = 0.400, 0.530

# Knee bend is expressed as extra outward knee offset; larger = more bend.
KNEE_BEND_SCALE = 0.075
# Elbow sits off the shoulder-wrist line by this fraction of its length, so the
# arm has a real interior angle instead of being degenerately straight.
ELBOW_BOW = 0.20

# --- phase boundaries (frame indices) ----------------------------------------
IDLE_END = 36
TAKEBACK_END = 50
FOREHAND_END = 64          # contact lands at the midpoint of the forehand arc
ARM_RECOVER_END = 88
RACKET_UP_END = 118
SERVE_SNAP_END = 126       # contact lands at the midpoint of the snap
PRONATE_END = 158

FOREHAND_CONTACT = (FOREHAND_END + TAKEBACK_END) // 2      # 57
SERVE_CONTACT = (SERVE_SNAP_END + RACKET_UP_END) // 2      # 122

# --- racket-hand (right wrist) path: (start, end, from_xy, to_xy) ------------
# Speeds are engineered, not eyeballed: with smootherstep easing the peak
# per-frame step is 1.875 * distance / duration, so each phase's peak wrist
# speed is a known quantity. Swing phases clear SWING_SPEED_FLOOR; every other
# phase stays under it, which is what makes swing detection here deterministic.
RIGHT_WRIST_PATH = [
    (0, IDLE_END, (0.600, 0.530), (0.615, 0.540)),                # idle sway
    (IDLE_END, TAKEBACK_END, (0.615, 0.540), (0.760, 0.570)),     # take-back
    (TAKEBACK_END, FOREHAND_END, (0.760, 0.570), (0.340, 0.360)), # FOREHAND
    (FOREHAND_END, ARM_RECOVER_END, (0.340, 0.360), (0.560, 0.500)),
    (ARM_RECOVER_END, RACKET_UP_END, (0.560, 0.500), (0.620, 0.190)),  # trophy
    (RACKET_UP_END, SERVE_SNAP_END, (0.620, 0.190), (0.460, 0.010)),   # SERVE
    (SERVE_SNAP_END, PRONATE_END, (0.460, 0.010), (0.560, 0.420)),
    (PRONATE_END, FRAME_COUNT, (0.560, 0.420), (0.600, 0.530)),   # settle
]

# Lateral body travel — a recovery step, so com_lateral_range is non-degenerate.
BODY_X_PATH = [
    (0, FOREHAND_END, 0.000, 0.000),
    (FOREHAND_END, RACKET_UP_END, 0.000, 0.055),
    (PRONATE_END, FRAME_COUNT, 0.055, 0.030),
]

# Vertical body travel — sink to load, drive up through contact, leap on serve.
# Slow enough that it never perturbs the wrist-speed peaks.
BODY_Y_PATH = [
    (0, IDLE_END, 0.000, 0.005),
    (IDLE_END, TAKEBACK_END, 0.005, 0.022),
    (TAKEBACK_END, FOREHAND_END, 0.022, -0.004),
    (FOREHAND_END, ARM_RECOVER_END, -0.004, 0.010),
    (ARM_RECOVER_END, RACKET_UP_END, 0.010, 0.026),
    (RACKET_UP_END, SERVE_SNAP_END, 0.026, -0.020),
    (SERVE_SNAP_END, PRONATE_END, -0.020, 0.012),
    (PRONATE_END, FRAME_COUNT, 0.012, 0.004),
]

# Torso coil. The hips lead the uncoil and the shoulders lag, so the two lines
# are furthest apart AT contact — that gap is the X-factor separation_angle
# measures. Shoulders finish unwinding only after the ball is gone.
SHOULDER_DEG_PATH = [
    (0, IDLE_END, 0.0, 0.0),
    (IDLE_END, TAKEBACK_END, 0.0, -38.0),
    (TAKEBACK_END, FOREHAND_END, -38.0, -26.0),   # still coiled through contact
    (FOREHAND_END, ARM_RECOVER_END, -26.0, 10.0),  # unwind lands after contact
    (ARM_RECOVER_END, RACKET_UP_END, 10.0, 0.0),
    (RACKET_UP_END, SERVE_SNAP_END, 0.0, -30.0),
    (SERVE_SNAP_END, PRONATE_END, -30.0, 0.0),
]
HIP_DEG_PATH = [
    (0, IDLE_END, 0.0, 0.0),
    (IDLE_END, TAKEBACK_END, 0.0, -14.0),
    (TAKEBACK_END, FOREHAND_END, -14.0, 6.0),      # hips already opening
    (FOREHAND_END, ARM_RECOVER_END, 6.0, 2.0),
    (ARM_RECOVER_END, RACKET_UP_END, 2.0, 0.0),
    (RACKET_UP_END, SERVE_SNAP_END, 0.0, 12.0),
    (SERVE_SNAP_END, PRONATE_END, 12.0, 0.0),
]
# 0 = straight leg, 1 = deep bend.
KNEE_BEND_PATH = [
    (0, IDLE_END, 0.25, 0.30),
    (IDLE_END, TAKEBACK_END, 0.30, 0.85),
    (TAKEBACK_END, FOREHAND_END, 0.85, 0.35),
    (FOREHAND_END, RACKET_UP_END, 0.35, 0.70),
    (RACKET_UP_END, SERVE_SNAP_END, 0.70, 0.20),
    (SERVE_SNAP_END, FRAME_COUNT, 0.20, 0.40),
]


def _smootherstep(u: float) -> float:
    return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)


def _lerp(a: float, b: float, u: float) -> float:
    return a + (b - a) * u


def _scalar_track(segments: list[tuple[int, int, float, float]], n: int) -> list[float]:
    """Piecewise smootherstep track; holds the last value outside any segment."""
    out: list[float] = []
    current = segments[0][2]
    for f in range(n):
        for start, end, v0, v1 in segments:
            if start <= f < end:
                current = _lerp(v0, v1, _smootherstep((f - start) / (end - start)))
                break
            if f >= end:
                current = v1
        out.append(current)
    return out


def _point_track(
    segments: list[tuple[int, int, tuple[float, float], tuple[float, float]]], n: int
) -> list[tuple[float, float]]:
    xs = _scalar_track([(s, e, a[0], b[0]) for s, e, a, b in segments], n)
    ys = _scalar_track([(s, e, a[1], b[1]) for s, e, a, b in segments], n)
    return list(zip(xs, ys, strict=True))


def _rotated_pair(cx: float, cy: float, half: float, degrees: float) -> tuple[
    tuple[float, float], tuple[float, float]
]:
    """Left/right endpoints of a body line of half-width `half`, rotated in-plane."""
    rad = np.deg2rad(degrees)
    dx, dy = half * float(np.cos(rad)), half * float(np.sin(rad))
    return (cx - dx, cy - dy), (cx + dx, cy + dy)


def _bowed_midpoint(
    a: tuple[float, float], b: tuple[float, float], bow: float = ELBOW_BOW
) -> tuple[float, float]:
    """Midpoint of a-b pushed perpendicular to it, so a-mid-b is not a straight line."""
    ax, ay = a
    bx, by = b
    mx, my = (ax + bx) / 2.0, (ay + by) / 2.0
    return (mx - (by - ay) * bow, my + (bx - ax) * bow)


def scripted_rally(
    fps: float = FPS,
    n_frames: int = FRAME_COUNT,
    *,
    elbow_bow: float = ELBOW_BOW,
    knee_bend_scale: float = KNEE_BEND_SCALE,
    lateral_travel: bool = True,
) -> list[PoseFrame]:
    """The scripted rally as PoseFrames. Deterministic; no model, no video.

    The three keyword knobs exist so `flawed_rally()` can degrade the technique
    without a second copy of the script. They change posture only — the wrist
    trajectory, and therefore swing detection, is identical either way.
    """
    wrist = _point_track(RIGHT_WRIST_PATH, n_frames)
    body_x = _scalar_track(BODY_X_PATH, n_frames) if lateral_travel else [0.0] * n_frames
    body_y = _scalar_track(BODY_Y_PATH, n_frames)
    shoulder_deg = _scalar_track(SHOULDER_DEG_PATH, n_frames)
    hip_deg = _scalar_track(HIP_DEG_PATH, n_frames)
    knee_bend = _scalar_track(KNEE_BEND_PATH, n_frames)

    frames: list[PoseFrame] = []
    for i in range(n_frames):
        ox, oy = body_x[i], body_y[i]
        cx = NOSE_X + ox
        (lsx, lsy), (rsx, rsy) = _rotated_pair(cx, SHOULDER_Y + oy, SHOULDER_HALF, shoulder_deg[i])
        (lhx, lhy), (rhx, rhy) = _rotated_pair(cx, HIP_Y + oy, HIP_HALF, hip_deg[i])
        bend = knee_bend[i] * knee_bend_scale
        rwx, rwy = wrist[i][0] + ox, wrist[i][1] + oy
        rex, rey = _bowed_midpoint((rsx, rsy), (rwx, rwy), elbow_bow)

        joints = {
            Joint.NOSE: Keypoint(x=cx, y=NOSE_Y + oy),
            Joint.L_SHOULDER: Keypoint(x=lsx, y=lsy),
            Joint.R_SHOULDER: Keypoint(x=rsx, y=rsy),
            # Elbow rides off the shoulder-wrist line — enough for a plausible
            # elbow angle without pretending to model the arm.
            Joint.L_ELBOW: Keypoint(x=cx - ELBOW_HALF, y=ELBOW_Y + oy),
            Joint.R_ELBOW: Keypoint(x=rex, y=rey),
            Joint.L_WRIST: Keypoint(x=LEFT_WRIST_X + ox, y=LEFT_WRIST_Y + oy),
            Joint.R_WRIST: Keypoint(x=rwx, y=rwy),
            Joint.L_HIP: Keypoint(x=lhx, y=lhy),
            Joint.R_HIP: Keypoint(x=rhx, y=rhy),
            Joint.L_KNEE: Keypoint(x=cx - KNEE_HALF - bend, y=KNEE_Y + oy),
            Joint.R_KNEE: Keypoint(x=cx + KNEE_HALF + bend, y=KNEE_Y + oy),
            Joint.L_ANKLE: Keypoint(x=cx - ANKLE_HALF, y=ANKLE_Y),
            Joint.R_ANKLE: Keypoint(x=cx + ANKLE_HALF, y=ANKLE_Y),
        }
        frames.append(PoseFrame(index=i, t=i / fps, joints=joints))
    return frames


# Posture knobs for the deliberately-bad rally: locked-out arm, straight legs,
# feet nailed to the floor. Exists so the advice -> JSON path is exercised at
# all; it says nothing about whether the coaching itself is calibrated.
FLAWED_ELBOW_BOW = 0.02
FLAWED_KNEE_BEND_SCALE = 0.004


def flawed_rally(fps: float = FPS, n_frames: int = FRAME_COUNT) -> list[PoseFrame]:
    """Same two swings, bad technique — enough to trip the rules in advice/rules.py."""
    return scripted_rally(
        fps,
        n_frames,
        elbow_bow=FLAWED_ELBOW_BOW,
        knee_bend_scale=FLAWED_KNEE_BEND_SCALE,
        lateral_travel=False,
    )


class ScriptedPoseEstimator:
    """A `PoseEstimator` that replays scripted frames and ignores the pixels.

    This is the point of the protocol in `pose/base.py`: swapping the model out
    should require nothing but another class with `estimate` and `close`.
    """

    name = "scripted"

    def __init__(
        self,
        poses: list[PoseFrame] | None = None,
        dropped: frozenset[int] = DROPPED_FRAMES,
    ) -> None:
        self._poses = {p.index: p for p in (poses if poses is not None else scripted_rally())}
        self._dropped = dropped
        self.seen = 0
        self.closed = False

    def estimate(self, frame: np.ndarray, index: int, t: float) -> PoseFrame | None:
        self.seen += 1
        if index in self._dropped:
            return None
        return self._poses.get(index)

    def close(self) -> None:
        self.closed = True


# --- clip rendering ----------------------------------------------------------
BONES = [
    (Joint.L_SHOULDER, Joint.R_SHOULDER),
    (Joint.L_HIP, Joint.R_HIP),
    (Joint.L_SHOULDER, Joint.L_HIP),
    (Joint.R_SHOULDER, Joint.R_HIP),
    (Joint.R_SHOULDER, Joint.R_ELBOW),
    (Joint.R_ELBOW, Joint.R_WRIST),
    (Joint.L_SHOULDER, Joint.L_ELBOW),
    (Joint.L_ELBOW, Joint.L_WRIST),
    (Joint.L_HIP, Joint.L_KNEE),
    (Joint.L_KNEE, Joint.L_ANKLE),
    (Joint.R_HIP, Joint.R_KNEE),
    (Joint.R_KNEE, Joint.R_ANKLE),
]
VOID_BGR = (10, 8, 12)
CYAN_BGR = (255, 231, 34)      # XIV cyan, BGR
MAGENTA_BGR = (200, 40, 235)   # XIV magenta, BGR
CONTACT_FRAMES = frozenset({FOREHAND_CONTACT, SERVE_CONTACT})


def render_clip(
    path: str | Path,
    poses: list[PoseFrame] | None = None,
    fps: float = FPS,
    size: tuple[int, int] = (FRAME_W, FRAME_H),
) -> Path:
    """Write the scripted rally to a real video file. Tmp dirs only — never the repo.

    cv2 is imported here rather than at module scope: this is fixture rendering,
    not pipeline code, and the pose-level tests must not need a video stack.
    """
    import cv2

    poses = poses if poses is not None else scripted_rally()
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    w, h = size

    writer = None
    for fourcc in ("mp4v", "MJPG"):
        candidate = cv2.VideoWriter(str(out), cv2.VideoWriter_fourcc(*fourcc), fps, (w, h))
        if candidate.isOpened():
            writer = candidate
            break
        candidate.release()
    if writer is None:  # pragma: no cover - depends on local codec availability
        raise RuntimeError(f"no usable video codec to write {out}")

    def px(kp) -> tuple[int, int]:
        return (round(kp.x * w), round(kp.y * h))

    try:
        for p in poses:
            img = np.full((h, w, 3), VOID_BGR, dtype=np.uint8)
            for a, b in BONES:
                ka, kb = p.get(a), p.get(b)
                if ka and kb:
                    cv2.line(img, px(ka), px(kb), CYAN_BGR, 2, cv2.LINE_AA)
            for kp in p.joints.values():
                cv2.circle(img, px(kp), 3, CYAN_BGR, -1, cv2.LINE_AA)
            if p.index in CONTACT_FRAMES and (rw := p.get(Joint.R_WRIST)):
                cv2.circle(img, px(rw), 9, MAGENTA_BGR, 2, cv2.LINE_AA)
            writer.write(img)
    finally:
        writer.release()
    return out
