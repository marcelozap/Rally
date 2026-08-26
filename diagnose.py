#!/usr/bin/env python3
"""Tracking-quality report for a clip.

Before trusting any metric, know where the model actually saw the body. On hard
footage — swimming especially — the useful output is often "it held the arms and
lost the legs", not a number.

    python diagnose.py clip.mp4
"""
import sys
from collections import defaultdict

import cv2
import numpy as np
import mediapipe as mp

NAMES = {0:"nose", 11:"L shoulder", 12:"R shoulder", 13:"L elbow", 14:"R elbow",
         15:"L wrist", 16:"R wrist", 23:"L hip", 24:"R hip",
         25:"L knee", 26:"R knee", 27:"L ankle", 28:"R ankle"}
GOOD = 0.5

def main(path, stride=1):
    cap = cv2.VideoCapture(path)
    if not cap.isOpened():
        sys.exit(f"could not open {path}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    n_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)); h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    print(f"{path}\n  {w}x{h}  {fps:.1f} fps  {n_frames} frames  {n_frames/fps:.1f}s\n")

    pose = mp.solutions.pose.Pose(model_complexity=1,
                                  min_detection_confidence=0.4, min_tracking_confidence=0.4)
    vis = defaultdict(list); detected = 0; total = 0
    heights = []; torso_ok = 0; torso_n = 0
    while True:
        ok, frame = cap.read()
        if not ok: break
        total += 1
        if total % stride: continue
        res = pose.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        if not res.pose_landmarks:
            for i in NAMES: vis[i].append(0.0)
            continue
        detected += 1
        lm = res.pose_landmarks.landmark
        for i in NAMES: vis[i].append(lm[i].visibility)
        ys = [p.y for p in lm]
        heights.append((max(ys) - min(ys)) * h)
        ms = (lm[11].y + lm[12].y) / 2; mh = (lm[23].y + lm[24].y) / 2
        torso_n += 1
        if ms < mh: torso_ok += 1          # shoulders must sit above hips
    cap.release(); pose.close()

    scored = total // stride or 1
    print(f"  body found in {detected}/{scored} sampled frames  ({100*detected/scored:.0f}%)\n")
    print("  landmark      tracked   median conf")
    print("  " + "-"*40)
    for i, name in NAMES.items():
        v = np.array(vis[i]) if vis[i] else np.array([0.0])
        pct = 100 * float((v >= GOOD).mean())
        bar = "#" * int(pct/5) + "." * (20 - int(pct/5))
        print(f"  {name:<13} {bar} {pct:5.0f}%   {np.median(v):.2f}")

    core = [11,12,23,24]
    usable = np.mean([[vis[i][k] >= GOOD for i in core] for k in range(len(vis[11]))], axis=1)
    print(f"\n  frames with all four torso points: {100*float((usable==1).mean()):.0f}%")

    if heights:
        med_h = float(np.median(heights))
        pct = 100 * med_h / h
        print(f"\n  SUBJECT SIZE   {med_h:.0f} px tall  ({pct:.1f}% of frame)")
        if pct < 25:
            print("                 TOO SMALL. Torso landmarks will be less precise than")
            print("                 the torso itself. Stand closer or zoom in.")
        elif pct < 45:
            print("                 Workable, but closer would measure better.")
        else:
            print("                 Good framing.")
    if torso_n:
        good = 100 * torso_ok / torso_n
        print(f"\n  TORSO SANITY   shoulders above hips in {good:.0f}% of frames")
        if good < 90:
            print("                 FAILING. The shoulder and hip midpoints are inverting,")
            print("                 which means every torso metric from this clip is noise —")
            print("                 separation, tilt and trunk lean included.")
        else:
            print("                 Passing. Torso metrics are trustworthy.")

if __name__ == "__main__":
    if len(sys.argv) < 2: sys.exit(__doc__)
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 1)
