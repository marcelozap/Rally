"""Universal checks — the rules that hold for everyone.

Split from the baseline-relative metrics on purpose. Two 5'10" people have
different femur:tibia ratios, different femoral anteversion, different tendon
insertions — so almost nothing about *optimal joint angles* generalises.

What does generalise is physics and gross anatomy:

  - a foot planted well ahead of the centre of mass applies a braking impulse,
    whoever you are
  - vertical velocity is not horizontal velocity
  - the kinetic chain sequences proximal to distal in every striking and
    throwing action ever measured
  - a hip that collapses under single-leg load is unsupported, not a style

Each check states its threshold and how soft that threshold is. Where there is
no defensible universal — dance technique, most of swimming from above water —
this module says so instead of inventing one.
"""

import numpy as np
from .pose import L

SOFT = "soft"      # useful signal, threshold is a convention
FIRM = "firm"      # mechanics; disagreeing with it means disagreeing with physics


class Check:
    def __init__(self, name, value, unit, verdict, detail, strength):
        self.name, self.value, self.unit = name, value, unit
        self.verdict, self.detail, self.strength = verdict, detail, strength

    def __repr__(self):
        v = "—" if self.value is None or np.isnan(self.value) else f"{self.value:.1f}{self.unit}"
        return f"[{self.verdict.upper():<4}] {self.name:<26} {v:>9}   {self.detail}"


def _series(frames, idx, axis):
    return np.array([f[idx][axis] for f in frames], dtype=float)


def _leg_length(frames):
    hip = np.array([(f[L.L_HIP][:2] + f[L.R_HIP][:2]) / 2 for f in frames])
    ank = np.array([(f[L.L_ANKLE][:2] + f[L.R_ANKLE][:2]) / 2 for f in frames])
    return float(np.median(np.linalg.norm(hip - ank, axis=1)))


# ---------------------------------------------------------------- running

def running(frames, fps):
    out = []
    leg = _leg_length(frames) or 1e-6
    hip_x = (_series(frames, L.L_HIP, 0) + _series(frames, L.R_HIP, 0)) / 2
    hip_y = (_series(frames, L.L_HIP, 1) + _series(frames, L.R_HIP, 1)) / 2

    # overstride: horizontal gap between the landing foot and the hips, at contact.
    # contact ~ the frame where an ankle is at its lowest point.
    gaps = []
    for ank in (L.L_ANKLE, L.R_ANKLE):
        ay = _series(frames, ank, 1)
        ax = _series(frames, ank, 0)
        for i in range(2, len(ay) - 2):
            if ay[i] >= ay[i-1] and ay[i] >= ay[i+1] and ay[i] > np.percentile(ay, 75):
                gaps.append(abs(ax[i] - hip_x[i]) / leg * 100)
    over = float(np.median(gaps)) if gaps else float("nan")
    out.append(Check(
        "overstride at contact", over, "% leg",
        "ok" if over < 18 else "watch" if over < 28 else "off",
        "Foot landing far ahead of the hips brakes you every step. Physics, not style.",
        FIRM))

    # vertical oscillation of the hips
    osc = float(np.percentile(hip_y, 95) - np.percentile(hip_y, 5)) / leg * 100
    out.append(Check(
        "vertical oscillation", osc, "% leg",
        "ok" if osc < 14 else "watch" if osc < 20 else "off",
        "Energy spent going up is energy not going forward.", FIRM))

    # contralateral pelvic drop — hip line tilt during single-leg stance
    tilt = np.degrees(np.arctan2(_series(frames, L.R_HIP, 1) - _series(frames, L.L_HIP, 1),
                                 _series(frames, L.R_HIP, 0) - _series(frames, L.L_HIP, 0)))
    tilt = (tilt + 90) % 180 - 90
    drop = float(np.percentile(np.abs(tilt), 90))
    out.append(Check(
        "pelvic drop", drop, "°",
        "ok" if drop < 8 else "watch" if drop < 12 else "off",
        "The hip collapsing under single-leg load. Associated with ITB and kneecap pain.",
        SOFT))
    return out


# ---------------------------------------------------------------- cycling

def cycling(frames, fps):
    out = []
    ang = []
    for hip, knee, ank in ((L.L_HIP, L.L_KNEE, L.L_ANKLE), (L.R_HIP, L.R_KNEE, L.R_ANKLE)):
        for f in frames:
            a, b, c = f[hip][:2], f[knee][:2], f[ank][:2]
            v1, v2 = a - b, c - b
            n1, n2 = np.linalg.norm(v1), np.linalg.norm(v2)
            if n1 > 1e-6 and n2 > 1e-6:
                ang.append(np.degrees(np.arccos(np.clip(v1 @ v2 / (n1 * n2), -1, 1))))
    # at bottom dead centre the leg is most extended -> knee angle closest to 180
    ext = float(180 - np.percentile(ang, 97)) if ang else float("nan")
    out.append(Check(
        "knee bend at full extension", ext, "°",
        "ok" if 25 <= ext <= 37 else "watch" if 20 <= ext <= 42 else "off",
        "Saddle height proxy. Under ~20° strains the knee and rocks the hips; "
        "over ~40° wastes power. The 25–35° window is a fitting convention, not a law.",
        SOFT))

    hip_y_l = _series(frames, L.L_HIP, 1); hip_y_r = _series(frames, L.R_HIP, 1)
    rock = float(np.percentile(np.abs(hip_y_l - hip_y_r), 90)) / (_leg_length(frames) or 1) * 100
    out.append(Check(
        "hip rock", rock, "% leg",
        "ok" if rock < 4 else "watch" if rock < 7 else "off",
        "Rocking side to side to reach the pedal usually means the saddle is too high.",
        SOFT))
    return out


# ------------------------------------------------- tennis / golf: sequencing

def _rotation_velocity(frames, a, b, fps):
    ang = np.degrees(np.arctan2(_series(frames, b, 1) - _series(frames, a, 1),
                                _series(frames, b, 0) - _series(frames, a, 0)))
    ang = np.unwrap(np.radians(ang * 2)) / 2      # fold the 180 ambiguity, then unwrap
    return np.gradient(np.degrees(ang)) * fps


def kinematic_sequence(frames, fps, sport):
    """Hips peak before shoulders. The most reproducible finding in striking
    biomechanics, and it is not style-dependent."""
    out = []
    hipv = _rotation_velocity(frames, L.L_HIP, L.R_HIP, fps)
    shov = _rotation_velocity(frames, L.L_SHOULDER, L.R_SHOULDER, fps)

    # cross-correlation, not argmax. argmax of a periodic signal can land on a
    # different cycle and report a nonsense lag; correlation over a bounded
    # window is stable whether the clip holds one swing or ten.
    a = (hipv - hipv.mean()) / (hipv.std() or 1)
    b = (shov - shov.mean()) / (shov.std() or 1)
    max_lag = max(1, min(len(a) - 1, int(0.35 * fps)))       # a swing sequences inside ~350ms
    lags = np.arange(-max_lag, max_lag + 1)
    corr = [float(np.dot(a[:len(a) - k], b[k:]) if k >= 0 else np.dot(a[-k:], b[:len(b) + k]))
            / (len(a) - abs(k)) for k in lags]
    lag = float(lags[int(np.argmax(corr))]) / fps * 1000      # ms, positive = hips lead

    out.append(Check(
        "kinematic sequence", lag, " ms",
        "ok" if lag > 15 else "watch" if lag > -15 else "off",
        "Hips should peak before the shoulders. Positive is correct order; "
        "negative means the arms are leading and the legs are along for the ride.",
        FIRM))

    sep = np.degrees(np.arctan2(_series(frames, L.R_SHOULDER, 1) - _series(frames, L.L_SHOULDER, 1),
                                _series(frames, L.R_SHOULDER, 0) - _series(frames, L.L_SHOULDER, 0))) \
        - np.degrees(np.arctan2(_series(frames, L.R_HIP, 1) - _series(frames, L.L_HIP, 1),
                                _series(frames, L.R_HIP, 0) - _series(frames, L.L_HIP, 0)))
    sep = (sep + 90) % 180 - 90
    peak = float(np.percentile(np.abs(sep), 98))
    floor = 20 if sport == "tennis" else 28
    out.append(Check(
        "peak separation", peak, "°",
        "ok" if peak > floor else "watch",
        f"Some coil has to exist or there is no elastic energy to release. "
        f"The {floor}° floor is a rough one — how much is optimal is individual.",
        SOFT))
    return out


# Sequence is invariant across strokes and clubs — that's what makes it universal.
# What changes with the implement is how much coil and how fast, not the order.
# Ranges below are indicative for skilled players, not gospel; use them as context,
# and use the subject's own history as the real comparison.
VARIANTS = {
    "running": {
        "sprint":   (240, 280, "cadence, steps/min. contact must be under you — at speed "
                               "an overstride is the biggest brake there is"),
        "tempo":    (175, 190, "cadence, steps/min"),
        "easy":     (165, 182, "cadence, steps/min"),
        "uphill":   (170, 190, "cadence, steps/min. stride shortens — that is correct, not a fault"),
        "downhill": (175, 195, "cadence, steps/min. overstride risk is highest here; "
                               "braking forces are what wreck quads on descents"),
    },
    "cycling": {
        "road":     (25, 35, "knee bend at bottom dead centre"),
        "climbing": (25, 35, "same fit, lower cadence. do not raise the saddle for hills"),
        "tt":       (25, 33, "aero position moves the saddle forward, not up"),
        "mtb":      (22, 33, "often a touch lower for control on descents"),
    },
    "swimming": {
        "freestyle":    (0, 0, "alternating. above water you get roll and arm recovery, "
                               "nothing of the catch"),
        "backstroke":   (0, 0, "the best case for a poolside camera — the whole recovery is "
                               "above the surface"),
        "breaststroke": (0, 0, "symmetric by definition, so left/right asymmetry is a real "
                               "finding rather than an artefact"),
        "butterfly":    (0, 0, "symmetric, and the body undulation is partly visible above water"),
    },
    "dance": {
        "house":     (118, 130, "BPM"),
        "techno":    (130, 150, "BPM"),
        "afrobeats": (100, 115, "BPM"),
        "hip-hop":   (85, 100,  "BPM"),
        "dancehall": (90, 105,  "BPM"),
    },
    "golf": {
        "driver":    (45, 62, "longest lever, most coil, slowest tempo"),
        "long iron": (42, 56, ""),
        "mid iron":  (38, 52, ""),
        "wedge":     (30, 45, "shortest swing — less coil is correct here, not a fault"),
        "putt":      (0, 12,  "no coil at all. sequencing does not apply."),
    },
    "tennis": {
        "serve":     (35, 55, "largest trunk rotation of any stroke"),
        "forehand":  (25, 45, ""),
        "backhand 1h": (20, 40, ""),
        "backhand 2h": (25, 45, ""),
        "volley":    (0, 15,  "a block, not a swing. no coil expected."),
    },
}


def variant_context(sport, variant, measured_peak):
    """Put a measured separation next to what that implement usually asks for."""
    table = VARIANTS.get(sport, {})
    if variant not in table:
        return None
    lo, hi, note = table[variant]
    if lo == 0 and hi <= 15:
        verdict, detail = "n/a", note or "sequencing does not apply to this stroke."
    elif measured_peak < lo:
        verdict, detail = "watch", f"below the {lo}–{hi}° usually seen with a {variant}."
    elif measured_peak > hi:
        verdict, detail = "watch", f"above the {lo}–{hi}° usual range — check it isn't a tracking artefact."
    else:
        verdict, detail = "ok", f"inside the {lo}–{hi}° usually seen with a {variant}."
    if note and verdict != "n/a":
        detail += f" ({note})"
    return Check(f"coil for {variant}", measured_peak, "°", verdict, detail, SOFT)


def tennis(frames, fps, variant=None):
    out = kinematic_sequence(frames, fps, "tennis")
    if variant:
        c = variant_context("tennis", variant, out[1].value)
        if c: out.append(c)
    return out


def golf(frames, fps, variant=None):
    out = kinematic_sequence(frames, fps, "golf")
    if variant:
        c = variant_context("golf", variant, out[1].value)
        if c: out.append(c)
    return out


# ---------------------------------------------------------------- swimming

def swimming(frames, fps):
    out = []
    roll = np.degrees(np.arctan2(_series(frames, L.R_SHOULDER, 1) - _series(frames, L.L_SHOULDER, 1),
                                 _series(frames, L.R_SHOULDER, 0) - _series(frames, L.L_SHOULDER, 0)))
    roll = (roll + 90) % 180 - 90
    left = float(np.percentile(roll[roll < 0], 5)) if (roll < 0).any() else 0.0
    right = float(np.percentile(roll[roll > 0], 95)) if (roll > 0).any() else 0.0
    asym = abs(abs(left) - abs(right))
    out.append(Check(
        "roll symmetry", asym, "°",
        "ok" if asym < 8 else "watch",
        "Body roll should be about even both ways. Lopsided roll usually means "
        "one arm is doing more.", SOFT))
    out.append(Check(
        "stroke mechanics", float("nan"), "",
        "n/a",
        "Not measurable from an above-water camera. The catch, the pull path and the "
        "kick are all underwater. Film from above the lane or use a housing.", FIRM))
    return out


# ---------------------------------------------------------------- dance

def beat_lock(frames, fps, bpm):
    """Is the movement locked to the tempo?

    Style is not measurable. *Timing* is — and in house that is the whole point.
    Take the vertical bounce of the hips, find its dominant frequency, and compare
    it to the beat. Dancers pulse on the beat or on the half; both count as locked.
    """
    hip_y = np.array([(f[L.L_HIP][1] + f[L.R_HIP][1]) / 2 for f in frames], dtype=float)
    if len(hip_y) < int(fps * 2):
        return Check("beat lock", float("nan"), "", "n/a",
                     "Need at least two seconds of movement to read the tempo.", SOFT)
    x = hip_y - hip_y.mean()
    x *= np.hanning(len(x))
    mag = np.abs(np.fft.rfft(x))
    freqs = np.fft.rfftfreq(len(x), 1 / fps)
    band = (freqs > 0.5) & (freqs < 5.0)                # 30–300 movements per minute
    if not band.any():
        return Check("beat lock", float("nan"), "", "n/a", "Clip too short.", SOFT)
    dom_hz = float(freqs[band][int(np.argmax(mag[band]))])
    moves_per_min = dom_hz * 60
    beat = bpm / 60.0
    ratio = dom_hz / beat
    # locked if pulsing on the beat, the half, the double, or the quarter
    best = min((abs(ratio - r), r) for r in (0.25, 0.5, 1.0, 2.0))
    err_pct = best[0] / best[1] * 100
    names = {0.25: "every 4th beat", 0.5: "every other beat", 1.0: "on the beat", 2.0: "double time"}
    return Check(
        "beat lock", moves_per_min, " /min",
        "ok" if err_pct < 6 else "watch" if err_pct < 14 else "off",
        f"Pulsing at {moves_per_min:.0f}/min against {bpm:.0f} BPM — closest to "
        f"{names[best[1]]}, off by {err_pct:.0f}%. Timing is measurable; style is not.",
        SOFT)


def dance(frames, fps, bpm=None):
    """There is no universal correct way to dance — but there is a universal
    correct way to be on time."""
    out = []
    if bpm:
        out.append(beat_lock(frames, fps, bpm))
    out.append(Check(
        "technique", float("nan"), "", "n/a",
        "No universal standard exists — dance is aesthetic and style-specific. "
        "Use the baseline-relative metrics (smoothness, range, level change) instead.",
        FIRM))
    knee = []
    for hip, kn, ank in ((L.L_HIP, L.L_KNEE, L.L_ANKLE), (L.R_HIP, L.R_KNEE, L.R_ANKLE)):
        for f in frames:
            knee.append(abs(f[kn][0] - (f[hip][0] + f[ank][0]) / 2))
    dev = float(np.percentile(knee, 95)) / (_leg_length(frames) or 1) * 100
    out.append(Check(
        "knee tracking on load", dev, "% leg",
        "ok" if dev < 12 else "watch",
        "A knee collapsing inward under load is a landing-injury pattern in any style. "
        "This one is safety, not aesthetics.", SOFT))
    return out


ACTIVITIES = {"running": running, "cycling": cycling, "tennis": tennis,
              "golf": golf, "swimming": swimming, "dance": dance}


def run_checks(frames, fps, activity, variant=None):
    fn = ACTIVITIES.get(activity)
    if fn is None:
        raise SystemExit(f"no universal checks for '{activity}'. have: {', '.join(ACTIVITIES)}")
    if activity in ("tennis", "golf"):
        return fn(frames, fps, variant)
    if activity == "dance":
        table = VARIANTS["dance"]
        bpm = None
        if variant in table:
            lo, hi, _ = table[variant]
            bpm = (lo + hi) / 2
        elif variant:
            try: bpm = float(variant)          # a raw BPM is also fine
            except ValueError: bpm = None
        return fn(frames, fps, bpm)
    out = fn(frames, fps)
    if variant and activity in VARIANTS and variant in VARIANTS[activity]:
        lo, hi, note = VARIANTS[activity][variant]
        if lo or hi:
            out.append(Check(f"{variant} target", float("nan"), "", "info",
                             f"expected {lo}–{hi} · {note}", SOFT))
        else:
            out.append(Check(f"{variant}", float("nan"), "", "info", note, SOFT))
    return out
