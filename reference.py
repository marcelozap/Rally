#!/usr/bin/env python3
"""Reference animations — the principle, drawn.

Important framing: these do NOT show "correct form for someone your height".
No such thing exists — two people of the same height have different femur:tibia
ratios and different hip geometry. What these show is the *universal principle*
in isolation, on a figure scaled to your proportions so it's legible to you.

Segment lengths use Winter's standard anthropometric fractions of stature. They
are population averages and are meant to be replaced by your own measured
proportions once you have footage the pipeline can actually measure.

    python reference.py --height 178
"""

import argparse
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter

BG, PANEL, INK, MUTED, GRID = "#0d0d0d", "#101014", "#ffffff", "#898781", "#2c2c2a"
GOOD, BAD, ACCENT = "#0ca30c", "#d03b3b", "#3987e5"

# Winter, fractions of stature H
F = dict(head=1.00, shoulder=0.818, elbow=0.630, wrist=0.485,
         hip=0.530, knee=0.285, ankle=0.039,
         shoulder_w=0.259, hip_w=0.191)


class Body:
    """Segment lengths from stature. Replace with measured proportions when available."""
    def __init__(self, height_cm=178.0):
        self.H = height_cm
        for k, v in F.items():
            setattr(self, k, v * height_cm)
        self.thigh = self.hip - self.knee
        self.shank = self.knee - self.ankle
        self.torso = self.shoulder - self.hip


def _style(ax, title, sub, colour):
    ax.set_facecolor(PANEL)
    ax.set_xticks([]); ax.set_yticks([])
    for s in ax.spines.values(): s.set_color(GRID)
    ax.set_title(title, color=colour, fontsize=12, pad=14, weight="bold")
    ax.text(0.5, -0.06, sub, transform=ax.transAxes, ha="center",
            color=MUTED, fontsize=8.5)


# ------------------------------------------------------- 1. kinematic sequence

def gif_sequence(body, out, sport="golf"):
    """The full proximal-to-distal chain, not just two links.

    Hips -> shoulders -> arms -> implement. Each link peaks after the one inside
    it and faster than it. That cascade is the kinematic sequence, and the trace
    underneath is the standard way it's read in golf biomechanics.
    """
    implement = "club" if sport == "golf" else "racket"
    fig = plt.figure(figsize=(10.4, 7.2), facecolor=BG)
    gs = fig.add_gridspec(2, 2, height_ratios=[1.9, 1.15], hspace=0.34, wspace=0.13,
                          left=0.05, right=0.975, top=0.815, bottom=0.10)
    fig.suptitle(f"{sport.title()} — the kinematic sequence",
                 color=INK, fontsize=15, weight="bold", y=0.965)
    fig.text(0.5, 0.905, f"hips → shoulders → arms → {implement}. each link peaks after the one "
             f"inside it, and faster.", ha="center", color=MUTED, fontsize=9.5)

    STEP, frames = 0.055, 96                    # lag between links, as a fraction of the cycle
    ph_all = np.linspace(0, 2*np.pi, frames, endpoint=False)
    AMP = dict(hips=42, shoulders=58, arms=72, imp=118)
    COL = dict(hips=ACCENT, shoulders="#d55181", arms="#c98500", imp="#199e70")
    panels = []

    for ci, (order, title, sub, col) in enumerate((
            (1,  "CORRECT", f"hips fire first, the {implement} last and fastest", GOOD),
            (-1, "OUT OF SEQUENCE", f"the {implement} leads — arms only, no chain", BAD))):
        ax = fig.add_subplot(gs[0, ci]); _style(ax, title, sub, col)
        ax.set_xlim(-body.H*0.62, body.H*0.62); ax.set_ylim(-body.H*0.10, body.H*1.12)
        seg = {}
        for n, w, c, al in (("hips",3.2,COL["hips"],1), ("shoulders",3.2,COL["shoulders"],1),
                            ("spine",2.2,INK,.45), ("legL",2.2,INK,.35), ("legR",2.2,INK,.35),
                            ("arms",3.0,COL["arms"],1), ("imp",3.0,COL["imp"],1)):
            seg[n], = ax.plot([], [], lw=w, color=c, alpha=al, solid_capstyle="round")
        seg["trail"], = ax.plot([], [], lw=1.3, color=COL["imp"], alpha=.30)
        seg["head"], = ax.plot([0], [body.head*0.955], "o", ms=16, color=INK, alpha=.45)

        tr = fig.add_subplot(gs[1, ci]); tr.set_facecolor(PANEL)
        for sp in tr.spines.values(): sp.set_color(GRID)
        tr.set_xticks([]); tr.set_yticks([]); tr.axhline(0, color=GRID, lw=1)
        lags = {k: order * i * STEP for i, k in enumerate(("hips","shoulders","arms","imp"))}
        peaks = []
        for k in ("hips","shoulders","arms","imp"):
            v = AMP[k]*np.cos(ph_all - 2*np.pi*lags[k])
            tr.plot(ph_all, v, lw=1.9, color=COL[k],
                    label=implement if k == "imp" else k)
            i_p = int(np.argmax(v)); x = ph_all[i_p]
            for sh in (-2*np.pi, 0, 2*np.pi):
                if abs(ph_all[i_p]+sh - np.pi/2) < abs(x - np.pi/2): x = ph_all[i_p]+sh
            tr.plot(x, v[i_p], "o", ms=6, color=COL[k], mec=PANEL, mew=1.6, clip_on=False)
            peaks.append(x)
        tr.set_xlim(min(peaks)-0.45, max(ph_all.max(), max(peaks))+0.25)
        tr.annotate("", xy=(peaks[-1], 0), xytext=(peaks[0], 0),
                    arrowprops=dict(arrowstyle="-|>", color=col, lw=1.8))
        tr.legend(frameon=False, fontsize=7.5, labelcolor=MUTED, loc="upper right", ncol=4,
                  handlelength=1.1, columnspacing=0.9)
        tr.text(0.5, -0.19, "rotation speed of each link  ·  peaks should step left to right",
                transform=tr.transAxes, ha="center", color=MUTED, fontsize=8)
        panels.append((seg, lags, []))

    def draw(i):
        ph = 2*np.pi*i/frames
        for seg, lags, trail in panels:
            ang = {k: np.radians(AMP[k]*np.sin(ph - 2*np.pi*lags[k]))
                   for k in ("hips","shoulders","arms","imp")}
            hw, sw = body.hip_w/2, body.shoulder_w/2
            hL = (-hw*np.cos(ang["hips"]), body.hip - hw*np.sin(ang["hips"])*0.30)
            hR = ( hw*np.cos(ang["hips"]), body.hip + hw*np.sin(ang["hips"])*0.30)
            sL = (-sw*np.cos(ang["shoulders"]), body.shoulder - sw*np.sin(ang["shoulders"])*0.30)
            sR = ( sw*np.cos(ang["shoulders"]), body.shoulder + sw*np.sin(ang["shoulders"])*0.30)
            seg["hips"].set_data([hL[0], hR[0]], [hL[1], hR[1]])
            seg["shoulders"].set_data([sL[0], sR[0]], [sL[1], sR[1]])
            seg["spine"].set_data([0, 0], [body.hip, body.shoulder])
            for side, h in (("legL", hL), ("legR", hR)):
                seg[side].set_data([h[0], h[0]*0.72, h[0]*0.5], [body.hip, body.knee, body.ankle])

            # arms: one unit swinging from mid-chest, then the implement off the hands
            cx, cy = 0.0, body.shoulder*0.99
            arm_len = (body.shoulder - body.wrist)*0.92
            hx = cx + arm_len*np.sin(ang["arms"])
            hy = cy - arm_len*np.cos(ang["arms"])
            # both arms converge on the hands — reads as a grip
            seg["arms"].set_data([sL[0], hx, sR[0]], [sL[1], hy, sR[1]])
            imp_len = body.H*0.30
            ix = hx + imp_len*np.sin(ang["imp"])
            iy = hy - imp_len*np.cos(ang["imp"])
            seg["imp"].set_data([hx, ix], [hy, iy])
            trail.append((ix, iy))
            if len(trail) > 26: trail.pop(0)
            seg["trail"].set_data([p[0] for p in trail], [p[1] for p in trail])
        return []

    FuncAnimation(fig, draw, frames=frames, interval=38, blit=False).save(
        out, writer=PillowWriter(fps=26), savefig_kwargs={"facecolor": BG})
    plt.close(fig); return out


# ------------------------------------------------------------- 2. overstride

def gif_overstride(body, out):
    """Foot landing under the hips vs well ahead of them. Side view."""
    fig, axes = plt.subplots(1, 2, figsize=(9, 5.8), facecolor=BG)
    fig.subplots_adjust(top=0.80, bottom=0.10)
    fig.suptitle("Running — where the foot lands", color=INK, fontsize=15, weight="bold", y=0.955)
    fig.text(0.5, 0.885, "a foot planted ahead of your centre of mass is a brake. every step.",
             ha="center", color=MUTED, fontsize=9)

    frames = 60
    panels = []
    for ax, reach, title, sub, col in (
        (axes[0], 0.10, "UNDER THE HIPS", "contact close to the body — no braking impulse", GOOD),
        (axes[1], 0.52, "OVERSTRIDING",  "heel lands far in front — you brake, then re-accelerate", BAD)):
        _style(ax, title, sub, col)
        ax.set_xlim(-body.H*0.45, body.H*0.45); ax.set_ylim(0, body.H*1.08)
        ax.plot([-body.H*0.45, body.H*0.45], [0, 0], color=GRID, lw=1.4)
        parts = {}
        for n, w, c, a in (("torso",2.4,INK,.8),("legF",2.6,col,1),("legB",2.2,INK,.45),
                           ("armF",1.8,INK,.45),("armB",1.8,INK,.45)):
            parts[n], = ax.plot([], [], lw=w, color=c, alpha=a, solid_capstyle="round")
        head, = ax.plot([0], [body.head*0.965], "o", ms=17, color=INK, alpha=.8)
        mark = ax.axvline(0, color=ACCENT, lw=1, ls=(0,(4,4)), alpha=.55)
        txt = ax.text(0, body.H*1.0, "", color=col, fontsize=9, ha="center")
        panels.append((parts, reach, head, mark, txt, col))

    def leg(hx, hy, ang, thigh, shank):
        kx, ky = hx + thigh*np.sin(ang), hy - thigh*np.cos(ang)
        ax_, ay_ = kx + shank*np.sin(ang*0.35), ky - shank*np.cos(ang*0.35)
        return [hx, kx, ax_], [hy, ky, ay_]

    def draw(i):
        ph = 2*np.pi*i/frames
        for parts, reach, head, mark, txt, col in panels:
            bob = body.H*0.012*np.cos(2*ph)
            hy = body.hip + bob; sy = body.shoulder + bob
            fa = reach*np.sin(ph) + 0.16; ba = -reach*np.sin(ph) - 0.16
            fx, fy = leg(0, hy, fa, body.thigh, body.shank)
            bx, by = leg(0, hy, ba, body.thigh, body.shank)
            parts["legF"].set_data(fx, fy); parts["legB"].set_data(bx, by)
            parts["torso"].set_data([0, 0], [hy, sy])
            parts["armF"].set_data([0, -body.H*0.06*np.sin(ph), -body.H*0.10*np.sin(ph)],
                                   [sy, body.elbow+bob, body.wrist+bob])
            parts["armB"].set_data([0, body.H*0.06*np.sin(ph), body.H*0.10*np.sin(ph)],
                                   [sy, body.elbow+bob, body.wrist+bob])
            head.set_data([0], [body.head*0.965 + bob])
            contact = fy[2] < body.H*0.06
            mark.set_xdata([fx[2], fx[2]])
            gap = abs(fx[2]) / (body.hip - body.ankle) * 100
            txt.set_text(f"foot {gap:.0f}% of leg ahead of hips" if contact else "")
        return []

    FuncAnimation(fig, draw, frames=frames, interval=45, blit=False).save(
        out, writer=PillowWriter(fps=22), savefig_kwargs={"facecolor": BG})
    plt.close(fig); return out


# --------------------------------------------------------------- 3. saddle height

def gif_saddle(body, out):
    """Knee angle at bottom dead centre. Three saddle heights."""
    fig, axes = plt.subplots(1, 3, figsize=(11, 5.2), facecolor=BG)
    fig.subplots_adjust(top=0.78, bottom=0.11)
    fig.suptitle("Cycling — saddle height, read at the bottom of the stroke",
                 color=INK, fontsize=15, weight="bold", y=0.955)
    fig.text(0.5, 0.875, "25–35° of knee bend at full extension. a fitting convention, not a law.",
             ha="center", color=MUTED, fontsize=9)

    crank = body.H*0.095
    foot  = body.H*0.045            # pedal spindle sits this far below the ankle
    setups = [("TOO LOW", 0.795, BAD, "over 40° bend — you never use the leg"),
              ("IN RANGE", 0.863, GOOD, "25–35° — power without strain"),
              ("TOO HIGH", 0.882, BAD, "under 20° — knee strain and the hips rock")]
    frames = 48
    panels = []
    for ax, (title, frac, col, sub) in zip(axes, setups):
        _style(ax, title, sub, col)
        lim = body.H*0.30
        ax.set_xlim(-lim*1.05, lim*0.85); ax.set_ylim(-lim*0.75, lim*2.05)
        ax.set_aspect("equal", adjustable="box")
        ax.add_patch(plt.Circle((0, 0), crank, fill=False, color=GRID, lw=1.2, ls=(0,(3,3))))
        p = {}
        for n, w, c in (("thigh",3.0,col),("shank",3.0,col),("foot",2.2,col),("seat",2.2,INK)):
            p[n], = ax.plot([], [], lw=w, color=c, solid_capstyle="round",
                            alpha=.5 if n == "seat" else .75 if n == "foot" else 1)
        ang = ax.text(-lim*0.1, lim*1.82, "", color=col, fontsize=13, ha="center", weight="bold")
        panels.append((p, frac, ang, col))

    def draw(i):
        th = 2*np.pi*i/frames
        for p, frac, ang, col in panels:
            hipx, hipy = -body.thigh*0.26, (body.thigh + body.shank)*frac
            px, py = crank*np.sin(th), -crank*np.cos(th)      # pedal
            ankx, anky = px, py + foot                        # ankle above the pedal
            d = np.hypot(ankx-hipx, anky-hipy)
            L1, L2 = body.thigh, body.shank
            d = min(d, L1+L2-1e-3)
            a = np.arccos(np.clip((d*d + L1*L1 - L2*L2)/(2*d*L1), -1, 1))
            base = np.arctan2(anky-hipy, ankx-hipx)
            kx = hipx + L1*np.cos(base - a); ky = hipy + L1*np.sin(base - a)
            p["thigh"].set_data([hipx, kx], [hipy, ky])
            p["shank"].set_data([kx, ankx], [ky, anky])
            p["foot"].set_data([ankx, px], [anky, py])
            p["seat"].set_data([hipx-body.H*0.055, hipx+body.H*0.02],
                               [hipy+body.H*0.012, hipy+body.H*0.012])
            v1 = np.array([hipx-kx, hipy-ky]); v2 = np.array([ankx-kx, anky-ky])
            knee = np.degrees(np.arccos(np.clip(v1@v2/(np.linalg.norm(v1)*np.linalg.norm(v2)), -1, 1)))
            if np.cos(th) > 0.93:      # bottom dead centre
                ang.set_text(f"{180-knee:.0f}° bend")
        return []

    FuncAnimation(fig, draw, frames=frames, interval=55, blit=False).save(
        out, writer=PillowWriter(fps=18), savefig_kwargs={"facecolor": BG})
    plt.close(fig); return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--height", type=float, default=178.0, help="stature in cm")
    a = ap.parse_args()
    b = Body(a.height)
    print(f"figure at {a.height:.0f}cm — thigh {b.thigh:.1f}cm, shank {b.shank:.1f}cm, "
          f"torso {b.torso:.1f}cm, shoulder width {b.shoulder_w:.1f}cm\n")
    for f in (gif_sequence(b, "ref_sequence_golf.gif", "golf"),
              gif_sequence(b, "ref_sequence_tennis.gif", "tennis"),
              gif_overstride(b, "ref_overstride.gif"),
              gif_saddle(b, "ref_saddle_height.gif")):
        print("  wrote", f)
