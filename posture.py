#!/usr/bin/env python3
"""
xiv-posture — a baseline-relative posture monitor.

It does NOT compare you to a template of "correct" posture. It learns *your*
good posture once, then tells you when you've drifted off it. Same principle
you want in the tennis/golf work: deviation from your own baseline, not from
an ideal that doesn't exist.

Pipeline is the same one everything else uses:
    pixels -> keypoints + confidence -> smooth -> angles -> metric -> alert

Install:
    pip install mediapipe opencv-python numpy matplotlib

Use:
    python posture.py calibrate     # sit the way you want to sit, 15 seconds
    python posture.py monitor       # runs in the background, alerts + logs
    python posture.py plot          # chart your week
"""

import csv
import json
import os
import sys
import time
from collections import deque

import cv2
import numpy as np

try:
    import mediapipe as mp
except ImportError:
    sys.exit("pip install mediapipe opencv-python numpy matplotlib")

BASELINE_PATH = "posture_baseline.json"
LOG_PATH = "posture_log.csv"

NOSE, L_EYE, R_EYE, L_SHOULDER, R_SHOULDER = 0, 2, 5, 11, 12
MIN_VISIBILITY = 0.6           # drop frames where the model isn't confident
CALIBRATION_SECONDS = 15
ALERT_SUSTAIN_SECONDS = 8.0    # how long you must be off before it nags
ALERT_COOLDOWN_SECONDS = 60.0
EMA_ALPHA = 0.15               # smoothing. differentiating raw keypoints is noise.

# how far off baseline counts as "off", in the units of each metric
THRESHOLDS = {
    "slump":        0.055,   # nose-to-shoulder gap, normalised by shoulder width
    "lean_in":      0.18,    # shoulder width vs baseline, as a ratio
    "shoulder_tilt": 6.0,    # degrees
    "head_tilt":     7.0,    # degrees
}


# ---------------------------------------------------------------- core

def metrics_from_landmarks(lm, w, h):
    """Raw landmarks -> four scale-invariant posture metrics. None if unreliable."""
    pts = {}
    for idx in (NOSE, L_EYE, R_EYE, L_SHOULDER, R_SHOULDER):
        p = lm[idx]
        if p.visibility < MIN_VISIBILITY:
            return None
        pts[idx] = np.array([p.x * w, p.y * h])

    ls, rs = pts[L_SHOULDER], pts[R_SHOULDER]
    shoulder_vec = rs - ls
    shoulder_width = np.linalg.norm(shoulder_vec)
    if shoulder_width < 1e-6:
        return None

    mid_shoulder = (ls + rs) / 2.0
    eye_vec = pts[R_EYE] - pts[L_EYE]

    return {
        # vertical gap nose->shoulders, normalised by shoulder width so it does
        # not change when you move closer to the screen. Smaller = slumping.
        "slump": float((mid_shoulder[1] - pts[NOSE][1]) / shoulder_width),
        # raw pixel width. Bigger than baseline = you've crept toward the screen.
        "lean_in": float(shoulder_width),
        "shoulder_tilt": float(np.degrees(np.arctan2(shoulder_vec[1], shoulder_vec[0]))),
        "head_tilt": float(np.degrees(np.arctan2(eye_vec[1], eye_vec[0]))),
    }


def frame_stream(callback, window_title=None):
    """Open the webcam, run pose, hand metrics to callback(metrics, frame)."""
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        sys.exit("No camera at index 0. Try 1, or close whatever else is using it.")

    pose = mp.solutions.pose.Pose(
        model_complexity=1, min_detection_confidence=0.5, min_tracking_confidence=0.5
    )
    try:
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            frame = cv2.flip(frame, 1)
            h, w = frame.shape[:2]
            res = pose.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))

            m = None
            if res.pose_landmarks:
                m = metrics_from_landmarks(res.pose_landmarks.landmark, w, h)
                mp.solutions.drawing_utils.draw_landmarks(
                    frame, res.pose_landmarks, mp.solutions.pose.POSE_CONNECTIONS
                )

            if callback(m, frame) is False:
                break

            if window_title:
                cv2.imshow(window_title, frame)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
    finally:
        cap.release()
        cv2.destroyAllWindows()
        pose.close()


def smooth(prev, new, alpha=EMA_ALPHA):
    if prev is None:
        return dict(new)
    return {k: (1 - alpha) * prev[k] + alpha * new[k] for k in new}


# ---------------------------------------------------------------- commands

def calibrate():
    print(f"Sit how you want to sit. Holding for {CALIBRATION_SECONDS}s. 'q' to abort.")
    samples, start = [], time.time()

    def on_frame(m, frame):
        elapsed = time.time() - start
        left = max(0, CALIBRATION_SECONDS - elapsed)
        cv2.putText(frame, f"calibrating  {left:4.1f}s   n={len(samples)}",
                    (12, 34), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        if m:
            samples.append(m)
        return elapsed < CALIBRATION_SECONDS

    frame_stream(on_frame, "xiv-posture · calibrate")

    if len(samples) < 30:
        sys.exit("Not enough clean frames. Better light, and stay in shot.")

    # median, not mean — one bad frame shouldn't move your baseline
    baseline = {k: float(np.median([s[k] for s in samples])) for k in samples[0]}
    with open(BASELINE_PATH, "w") as f:
        json.dump(baseline, f, indent=2)
    print(f"\nBaseline saved from {len(samples)} frames:")
    for k, v in baseline.items():
        print(f"  {k:<14} {v:8.3f}")


def deviations(m, baseline):
    """Signed deviation per metric, in the same units as THRESHOLDS."""
    return {
        "slump": baseline["slump"] - m["slump"],                       # +ve = slumping
        "lean_in": (m["lean_in"] - baseline["lean_in"]) / baseline["lean_in"],
        "shoulder_tilt": abs(m["shoulder_tilt"] - baseline["shoulder_tilt"]),
        "head_tilt": abs(m["head_tilt"] - baseline["head_tilt"]),
    }


def monitor():
    if not os.path.exists(BASELINE_PATH):
        sys.exit("Run `python posture.py calibrate` first.")
    with open(BASELINE_PATH) as f:
        baseline = json.load(f)

    state = {"ema": None, "bad_since": None, "last_alert": 0.0}
    new_log = not os.path.exists(LOG_PATH)
    log = open(LOG_PATH, "a", newline="")
    writer = csv.writer(log)
    if new_log:
        writer.writerow(["ts", "slump", "lean_in", "shoulder_tilt", "head_tilt", "off"])

    print("Monitoring. 'q' in the window to stop.")

    def on_frame(m, frame):
        now = time.time()
        if m is None:
            return True

        state["ema"] = smooth(state["ema"], m)
        dev = deviations(state["ema"], baseline)
        offenders = [k for k, v in dev.items() if v > THRESHOLDS[k]]

        if offenders:
            state["bad_since"] = state["bad_since"] or now
            held = now - state["bad_since"]
            if held > ALERT_SUSTAIN_SECONDS and now - state["last_alert"] > ALERT_COOLDOWN_SECONDS:
                print(f"\a[{time.strftime('%H:%M:%S')}] posture: {', '.join(offenders)}")
                state["last_alert"] = now
        else:
            state["bad_since"] = None

        writer.writerow([f"{now:.1f}"] + [f"{dev[k]:.4f}" for k in
                        ("slump", "lean_in", "shoulder_tilt", "head_tilt")]
                        + ["|".join(offenders)])
        log.flush()

        colour = (0, 0, 255) if offenders else (0, 200, 0)
        cv2.putText(frame, ", ".join(offenders) if offenders else "ok",
                    (12, 34), cv2.FONT_HERSHEY_SIMPLEX, 0.9, colour, 2)
        for i, k in enumerate(("slump", "lean_in", "shoulder_tilt", "head_tilt")):
            cv2.putText(frame, f"{k:<14}{dev[k]:+7.3f} / {THRESHOLDS[k]:.3f}",
                        (12, 70 + i * 26), cv2.FONT_HERSHEY_SIMPLEX, 0.55,
                        (0, 0, 255) if dev[k] > THRESHOLDS[k] else (200, 200, 200), 1)
        return True

    try:
        frame_stream(on_frame, "xiv-posture · monitor")
    finally:
        log.close()


def plot():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    if not os.path.exists(LOG_PATH):
        sys.exit("No log yet. Run monitor first.")

    rows = list(csv.DictReader(open(LOG_PATH)))
    if not rows:
        sys.exit("Log is empty.")

    ts = np.array([float(r["ts"]) for r in rows])
    hours = (ts - ts[0]) / 3600.0
    keys = ("slump", "lean_in", "shoulder_tilt", "head_tilt")

    fig, axes = plt.subplots(len(keys), 1, figsize=(11, 8), sharex=True)
    for ax, k in zip(axes, keys):
        v = np.array([float(r[k]) for r in rows])
        ax.plot(hours, v, lw=0.8)
        ax.axhline(THRESHOLDS[k], ls="--", lw=0.9, color="crimson")
        ax.fill_between(hours, THRESHOLDS[k], v, where=v > THRESHOLDS[k],
                        color="crimson", alpha=0.18)
        ax.set_ylabel(k, fontsize=9)
        ax.grid(alpha=0.2)
    axes[-1].set_xlabel("hours since first session")
    axes[0].set_title("deviation from your own baseline — above the dashed line is off")
    fig.tight_layout()
    fig.savefig("posture_report.png", dpi=140)

    pct = 100.0 * sum(1 for r in rows if r["off"]) / len(rows)
    print(f"posture_report.png written · {len(rows)} frames · {pct:.1f}% off baseline")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    {"calibrate": calibrate, "monitor": monitor, "plot": plot}.get(
        cmd, lambda: print(__doc__)
    )()
