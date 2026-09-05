# xiv-movement

Measure how a body moves, and how that changes.

```
pixels -> keypoints + confidence -> smooth -> angles & velocities -> metrics
```

## Install

Use Python 3.11 or 3.12 and a clean environment. This branch uses the legacy
MediaPipe Pose API, so its compatible MediaPipe, NumPy and OpenCV dependencies
are constrained in `requirements.txt`. Installing the latest MediaPipe alone
breaks that API. `opencv-contrib-python` provides `cv2`; do not also install
`opencv-python` into the same environment.

Windows:

```powershell
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
.venv\Scripts\python cli.py analyze serve.mp4
```

macOS/Linux:

```bash
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

## Use

```bash
python cli.py analyze serve.mp4     # overlay video + metrics csv + summary
python cli.py plot serve_metrics.csv
python cli.py live                  # webcam, live HUD
```

## Structure

```
xiv_movement/
  core/         pose.py  filters.py  metrics.py  session.py   <- no camera code
  capture/      file.py  webcam.py                            <- device-specific, thin
cli.py
```

Capture and core are separate on purpose. A video file and a webcam produce the
same thing — `(timestamp, frame)` — so the core never learns where frames came
from. Phone, laptop, desktop: one pipeline.

## Two kinds of measurement

**Universal checks** (`cli.py check`) — the rules that hold for everyone, because
they're physics or gross anatomy. A foot landing well ahead of the centre of mass
brakes you. The kinetic chain sequences hips-then-shoulders in every striking
action ever measured. A hip collapsing under single-leg load is unsupported.
These have real thresholds, and each one states how firm that threshold is.

**Baseline-relative metrics** (`cli.py analyze`) — everything else. Two people of
the same height have different femur:tibia ratios, different femoral anteversion,
different tendon insertions, so *optimal joint angles do not generalise*. These
are compared against the subject's own history, never a template.

`universal.py` says "no universal exists here" where that is the honest answer —
dance technique, and stroke mechanics from an above-water camera.

## Reference animations

```bash
python reference.py --height 178
```

Writes four GIFs demonstrating the universal principles on a figure scaled to
your stature. Segment lengths use Winter's anthropometric fractions — population
averages, meant to be replaced by your own measured proportions once the pipeline
has footage it can read.

**These are not "correct form for someone your height."** No such thing exists:
two people of the same stature differ in femur:tibia ratio, femoral anteversion
and tendon insertion. What the GIFs show is the *principle* in isolation —
sequencing, contact position, saddle height — on a body proportioned like yours
so it is legible to you.

There is deliberately no dance reference and no swimming stroke reference. There
is no universal to draw.

## Variants

The universal principle never changes. What changes with the implement, the pace,
or the stroke is *how much*, not *what order*.

```bash
python cli.py check swing.mp4  --activity golf     --variant wedge
python cli.py check run.mp4    --activity running  --variant downhill
python cli.py check clip.mp4   --activity dance    --variant house
python cli.py check clip.mp4   --activity dance    --variant 124      # or a raw BPM
```

| activity | variants |
|---|---|
| golf | driver · long iron · mid iron · wedge · putt |
| tennis | serve · forehand · backhand 1h · backhand 2h · volley |
| running | sprint · tempo · easy · uphill · downhill |
| cycling | road · climbing · tt · mtb |
| swimming | freestyle · backstroke · breaststroke · butterfly |
| dance | house · techno · afrobeats · hip-hop · dancehall |

Putt and volley return **n/a** — no coil is expected, so flagging its absence would
be flagging correct technique as broken. A wedge is *supposed* to have less coil
than a driver, and the table says so.

### Dance has one real universal after all: timing

Style isn't measurable. Being on the beat is. `beat_lock` takes the vertical
bounce of the hips, finds its dominant frequency by FFT, and compares it to the
tempo — counting on-the-beat, half time, double time and every-fourth as locked.
Verified against synthetic dancers at 124 BPM: on-beat and half-time both read
3% error; a dancer drifting at 1.65 Hz reads 19% and fails.

## Footage quality gate

`check` refuses to report numbers from footage that can't support them. Subject
under ~20% of frame height, or shoulder/hip midpoints inverting, and it stops.
A 99% tracking rate can still be an unmeasurable clip — MediaPipe's confidence
means "the joint is in frame", not "the position is accurate".

## What it measures

`hip_shoulder_separation` is the primitive shared by a golf swing, a tennis
serve, and a pitch: how far the shoulders have rotated ahead of the hips. Peak
separation and the timing of it are most of what "sequencing" means.

Also: shoulder and hip tilt, trunk lean, elbow and knee angles, left/right
asymmetry.

Almost all of it is trigonometry. There is no model to train here yet.

## Verification and app status

```bash
python -m unittest discover -s tests -v
python scripts/verify_movement.py --video serve.mp4
# Or use a local full-body photo to test actual model loading and video export:
python scripts/verify_movement.py --image person.jpg
```

The smoke command saves CSV, an overlay and `result.json` under
`artifacts/verification/`. Image mode repeats a photograph: it verifies real
inference and exports, **not** the accuracy of tennis analysis. Recorded-video
overlays preserve the input frame rate. Low-visibility limb angles are `nan`
in the CSV, and lost tracking clears the overlay's previous measurements.

This is a standalone Python prototype on the `xiv-movement` branch. It is not
called by the Swift iOS game. There is no LLM integration: MediaPipe supplies
pose landmarks, then mathematical metrics and rules produce results. A real
practice clip with known movements is still needed to evaluate coaching
accuracy. See [verification notes](docs/VERIFICATION.md) for tested scope.

## Notes

- **2D.** Depth from one camera is weakly constrained and degrades in sunlight
  and occlusion. These metrics survive without it. Add depth when 2D limits you.
- **Filtering is not optional.** The metrics are derivatives; differentiating raw
  keypoints produces noise. `filters.py` runs a constant-velocity Kalman per
  keypoint and weights each measurement by its confidence.
- **Consistent camera position matters more than camera quality.** Same height,
  angle, and distance every session, or the sessions aren't comparable — and
  comparison over time is the entire point.

## Filming

Side-on, whole body in frame, highest frame rate the phone offers. Phone on a
tripod, not held. Three or four reps.
