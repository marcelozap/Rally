"""The session store.

One record per analysed clip. This is the file that answers "how do we know it
works" — not a claim, a log with dates on it.

Note: recording more clips grows the *dataset*. The model improves when you
retrain on it. Those are two steps, and this module is the first one.
"""

import json
import statistics as st
from pathlib import Path

STORE = Path("sessions.json")


def _summarise(rows):
    def col(k):
        return [r[k] for r in rows if r.get(k) == r.get(k)]  # drop NaN

    sep = col("hip_shoulder_separation")
    return {
        "frames": len(rows),
        "peak_separation": round(max(abs(min(sep)), abs(max(sep))), 2) if sep else None,
        "separation_range": round(max(sep) - min(sep), 2) if sep else None,
        "elbow_asymmetry": round(st.median(col("elbow_asymmetry")), 2) if col("elbow_asymmetry") else None,
        "knee_asymmetry": round(st.median(col("knee_asymmetry")), 2) if col("knee_asymmetry") else None,
        "trunk_lean": round(st.median(col("trunk_lean")), 2) if col("trunk_lean") else None,
    }


def load(path=STORE):
    p = Path(path)
    return json.loads(p.read_text()) if p.exists() else []


def log_session(rows, activity, date, label="", subject="me", outcomes=None, path=STORE):
    """Append one analysed clip to the store. date is 'YYYY-MM-DD' — passed in,
    never guessed, so a re-run of an old clip files under the day it was shot.

    `outcomes` is the layer that makes the form numbers mean anything:
    {"50m_time_s": 41.2, "stroke_count": 22, "pain_0_10": 4}. Form is the input,
    outcome is the result. Nobody is convinced by separation going up 9 degrees;
    they are convinced when the 50 drops 3 seconds at the same time.
    """
    sessions = load(path)
    sessions.append({
        "date": date,
        "activity": activity,
        "subject": subject,
        "label": label,
        "outcomes": outcomes or {},
        **_summarise(rows),
    })
    sessions.sort(key=lambda s: (s["date"], s["activity"]))
    Path(path).write_text(json.dumps(sessions, indent=2))
    return sessions


def add_outcome(date, activity, key, value, path=STORE):
    """Attach a result to an already-logged session — times and pain scores
    usually arrive after the video does."""
    sessions = load(path)
    for s in sessions:
        if s["date"] == date and s["activity"] == activity:
            s.setdefault("outcomes", {})[key] = value
            Path(path).write_text(json.dumps(sessions, indent=2))
            return s
    raise SystemExit(f"No session found for {date} / {activity}")


# lower is better for these; everything else assumed higher-is-better.
# substrings must be specific — a greedy token like "_s" also matches
# "serve_speed_mph" and silently inverts the verdict.
LOWER_IS_BETTER_CONTAINS = ("time", "pain", "stroke_count", "swolf", "soreness", "latency")
LOWER_IS_BETTER_SUFFIX = ("_s", "_sec", "_secs", "_seconds", "_ms")


def better_direction(key):
    """+1 if a higher value is a better outcome, -1 if lower is better."""
    k = key.lower()
    if any(t in k for t in LOWER_IS_BETTER_CONTAINS):
        return -1
    if any(k.endswith(t) for t in LOWER_IS_BETTER_SUFFIX):
        return -1
    return 1


def pearson(xs, ys):
    pairs = [(a, b) for a, b in zip(xs, ys) if a is not None and b is not None]
    n = len(pairs)
    if n < 3:
        return None, n
    mx = sum(a for a, _ in pairs) / n
    my = sum(b for _, b in pairs) / n
    num = sum((a - mx) * (b - my) for a, b in pairs)
    dx = sum((a - mx) ** 2 for a, _ in pairs) ** 0.5
    dy = sum((b - my) ** 2 for _, b in pairs) ** 0.5
    if dx == 0 or dy == 0:
        return None, n
    return num / (dx * dy), n
