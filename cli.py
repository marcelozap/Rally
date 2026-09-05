#!/usr/bin/env python3
"""
xiv-movement

    python cli.py analyze serve.mp4 --activity "tennis serve" \
                  --result serve_speed_mph=91 --result pain_0_10=2
    python cli.py live                     # webcam, live HUD
    python cli.py plot serve_metrics.csv   # chart one clip
    python cli.py report                   # progress report across all sessions
    python cli.py check serve.mp4 --activity golf --variant driver

`analyze` logs the clip to sessions.json. `report` turns that log into a
self-contained HTML page — the thing that answers "how do we know it works".

The camera is the only device-specific part. Everything after is numbers.
"""

import sys
from pathlib import Path

from xiv_movement.capture import from_video, from_webcam
from xiv_movement.capture.file import video_fps
from xiv_movement.core.session import analyze_source, write_csv
from xiv_movement.core.metrics import METRIC_NAMES


def analyze(path, activity=None, date=None, label="", outcomes=None):
    src = Path(path)
    rows = analyze_source(
        from_video(src), overlay_path=src.with_name(src.stem + "_overlay.mp4"),
        overlay_fps=video_fps(src),
    )
    csv_path = write_csv(rows, src.with_name(src.stem + "_metrics.csv"))

    import numpy as np
    sep = np.array([r["hip_shoulder_separation"] for r in rows])
    print(f"{len(rows)} frames analysed")
    print(f"  overlay : {src.with_name(src.stem + '_overlay.mp4')}")
    print(f"  metrics : {csv_path}")
    print(f"  hip-shoulder separation  peak {np.nanmax(np.abs(sep)):6.1f}deg"
          f"   range {np.nanmax(sep) - np.nanmin(sep):6.1f}deg")
    if activity:
        from xiv_movement.core.progress import log_session
        import datetime
        d = date or datetime.date.today().isoformat()
        n = len(log_session(rows, activity, d, label, outcomes=outcomes or {}))
        print(f"  logged  : sessions.json  ({n} sessions, {activity}, {d})")
        print(f"\n  next: python cli.py report")
    else:
        print(f"\n  next: python cli.py analyze {src.name} --activity \"tennis serve\"")


def live():
    print("Live. 'q' in the window to stop.")
    analyze_source(from_webcam(), show=True)


def plot(csv_path):
    import csv as _csv
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np

    rows = list(_csv.DictReader(open(csv_path)))
    t = np.array([float(r["t"]) for r in rows])
    keys = ["hip_shoulder_separation", "shoulder_tilt", "hip_tilt", "trunk_lean"]

    fig, ax = plt.subplots(figsize=(11, 5))
    for k in keys:
        ax.plot(t, [float(r[k]) for r in rows], lw=1.4, label=k.replace("_", " "))
    ax.set_xlabel("seconds")
    ax.set_ylabel("degrees")
    ax.set_title("separation and orientation through the movement")
    ax.grid(alpha=0.25)
    ax.legend(frameon=False, fontsize=9)
    fig.tight_layout()
    out = Path(csv_path).with_suffix(".png")
    fig.savefig(out, dpi=140)
    print(f"wrote {out}")


def check(path, activity):
    """Universal checks — the rules that hold for everyone, unlike joint angles.

    Gated on footage quality: if the clip can't support a measurement, it says so
    rather than producing a confident number from noise.
    """
    import numpy as np
    from xiv_movement.core.pose import PoseExtractor, L
    from xiv_movement.core.filters import KeypointFilter
    from xiv_movement.core.universal import run_checks
    from xiv_movement.capture import from_video

    frames, heights, torso_ok = [], [], 0
    kf = KeypointFilter()
    prev = None
    with PoseExtractor() as pose:
        for t, frame in from_video(path):
            pts, _ = pose(frame)
            if pts is None:
                continue
            if np.min(pts[[11, 12, 23, 24], 3]) < 0.5:
                continue
            dt = 1/30 if prev is None else max(t - prev, 1e-3); prev = t
            frames.append(kf(pts, dt))
            heights.append(pts[:, 1].max() - pts[:, 1].min())
            if (pts[11, 1] + pts[12, 1]) / 2 < (pts[23, 1] + pts[24, 1]) / 2:
                torso_ok += 1

    if len(frames) < 30:
        raise SystemExit(f"Only {len(frames)} usable frames. Not enough to check anything.")

    import cv2
    cap = cv2.VideoCapture(path); fps = cap.get(cv2.CAP_PROP_FPS) or 30
    fh = cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 1; cap.release()

    pct = 100 * float(np.median(heights)) / fh
    sane = 100 * torso_ok / len(frames)
    print(f"\n{path}  ·  {len(frames)} usable frames  ·  subject {pct:.1f}% of frame\n")

    if pct < 20 or sane < 90:
        print("  FOOTAGE NOT USABLE")
        if pct < 20:  print(f"    subject is {pct:.1f}% of frame height — needs ~45%. Get closer.")
        if sane < 90: print(f"    shoulders sit above hips in only {sane:.0f}% of frames — torso is noise.")
        print("\n  Not reporting numbers from this clip. They would be made up.")
        return

    for c in run_checks(frames, fps, activity, _flag("--variant")):
        print("  " + repr(c))
    print()


def report():
    from xiv_movement.core.progress import load
    from xiv_movement.report import build
    out = build(load())
    print(f"wrote {out} — open it, screenshot it, post it")


def _flag(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def _results():
    """--result key=value, repeatable. Values parse as float when they can."""
    out = {}
    for i, a in enumerate(sys.argv):
        if a == "--result" and i + 1 < len(sys.argv) and "=" in sys.argv[i + 1]:
            k, v = sys.argv[i + 1].split("=", 1)
            try:
                out[k] = float(v)
            except ValueError:
                out[k] = v
    return out


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    if cmd == "report":
        report()
    elif cmd == "check" and len(sys.argv) > 2:
        check(sys.argv[2], _flag("--activity", "running"))
    elif cmd == "analyze" and len(sys.argv) > 2:
        analyze(sys.argv[2], _flag("--activity"), _flag("--date"),
                _flag("--label", ""), _results())
    elif cmd == "live":
        live()
    elif cmd == "plot" and len(sys.argv) > 2:
        plot(sys.argv[2])
    else:
        print(__doc__)
