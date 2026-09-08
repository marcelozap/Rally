# Rally Coach motion review

Branch: `codex/rally-coach-kinematics`, based on the tested native Coach integration at `56a0f66`. This branch includes the native Coach feature from `codex/rally-coach-ios`; it does not merge the Python research branches. All video decoding and pose inference remain local Apple AVFoundation/Vision operations.

## Availability

The existing Coach experience remains the default. The new hand selector and motion review are **off by default**, including in Release builds. A Debug launch with `-RallyCoachMotionPreview` enables the experimental review for validation. Tests can explicitly enable its view model. This is not a release-ready tennis measurement feature.

Raw baseline joint ranges, filming guidance, report history, gameplay, avatar, Shop, Journal, account synchronization and sound defaults retain their existing behavior. Optional motion reviews decode alongside old reports without migrating or touching SwiftData. Videos and pose arrays are not stored in history. A review records timestamped derived measurements, the selected hand, sampling rate and filter parameters.

## Reference and adaptation

Reviewed gateKPT commit `caac946cae57f4b52684ce59a550598111c2a23c`:

- [tracking/smoothing.py](https://github.com/marcelozap/gateKPT/blob/caac946cae57f4b52684ce59a550598111c2a23c/kinematics/tracking/smoothing.py)
- [metrics/kinematics.py](https://github.com/marcelozap/gateKPT/blob/caac946cae57f4b52684ce59a550598111c2a23c/kinematics/metrics/kinematics.py)

The Swift implementation independently applies the One Euro low-pass equations and the idea of subtracting same-side shoulder movement from wrist movement. It does not copy the reference's missing-joint zero fallback, assumed initial 60 Hz interval, or zero-initialized acceleration. Filter derivatives use previous raw observations, while filtered coordinates are retained separately.

Each joint's x/y filters use actual decoded timestamps. Missing, invalid or confidence-below-0.4 observations are rejected before filtering. An affected joint resets immediately; time gaps above 0.25 seconds break continuity. Duplicate, backwards, nonfinite and out-of-clip timestamps break the derivative chain. New clips create fresh filters.

Both coordinate axes use frame-height units after applying the video orientation. Relative velocity is the change in `(wrist - shoulder)` divided by elapsed seconds. Units are **frame heights/s**, not metres/s, ball speed or racket speed. Acceleration is a vector derivative in **frame heights/s squared** and remains unavailable until two consecutive velocity estimates exist. For irregular sampling, the difference uses the velocity intervals' midpoints.

The timeline compares original and smoothed relative speeds. Separate paths stop at gaps; shaded intervals mark missing or limited-confidence tracking. The timestamp slider exposes unavailable samples rather than turning them into zeros. Peak buttons select local maxima with confident neighboring samples in the same segment and describe increased tracked arm movement. Use the timestamps in the original video; Rally does not retain that video for playback.

## Filter tuning and evidence

Final provisional settings at 10 Hz: minimum cutoff **3 Hz**, speed coefficient **30**, derivative cutoff **1 Hz**, maximum continuous gap **0.25 s**. These parameters control filtering and evidence continuity; they do not grade athletic performance.

| Comparison | Original candidate (2 Hz / beta 4) | Selected candidate (3 Hz / beta 30) |
| --- | --- | --- |
| Synthetic stationary jitter: filtered/raw speed | 0.395 | 0.529 (47% reduction) |
| Synthetic fast reversal: retained peak | 83.7% | 96.9% |
| Real landscape fixture: retained peak | 59.0% | 79.8% |
| Portrait-framed fixture: retained peak | 64.6% | 77.3% |
| Sampled peak shift in those real comparisons | 0 seconds | 0 seconds |

Real-clip candidate comparisons replay the same observations, avoiding changes in input between filter settings. Mac replay used the actual app sources and Apple Vision. The original candidate was also measured on the iPhone; final phone results are appended to `RALLY_COACH_VALIDATION.md`.

The input is the public [UCF101 TennisSwing g01/c01 clip](https://www.crcv.ucf.edu/THUMOS14/UCF101/UCF101/v_TennisSwing_g01_c01.avi), transcoded locally to a silent H.264 MOV. It lasts 2.57 seconds at 320 x 240. The portrait comparison is the same footage padded into a 320 x 568 frame, not an independent portrait iPhone capture. The foreground player is visible, but the low-resolution footage also includes distant people and weak limb observations. Neither variant is sufficient to validate tennis accuracy. No footage is committed or bundled.

On the initial iPhone 16 Pro/iOS 26.6.1 run, landscape processing took 0.386 seconds and portrait processing 0.459 seconds. Full-body coverage was 30.8% and 0%; usable arm-velocity coverage was 26.9% and 76.9%. The app correctly withheld full-body movement metrics when its continuity gates failed. Thermal state remained nominal. Sampled whole-app resident memory was 353-457 MB, including the game and XCTest host; this is not isolated analyzer memory or a measured peak.

Ten samples per second provide roughly 100 ms observation spacing. Smoothing cannot recover movement between samples. These fixtures showed a stable sampled peak time under filtering, but do not establish timing accuracy against high-rate ground truth. Sampling remains at **10 Hz**. Higher-rate testing, longer clips and sustained device profiling are required before changing it.

## Tests and limitations

The portable suite has 63 passing tests, including 19 motion tests for stationary jitter, constant motion, common body translation, handedness, direction changes, irregular timestamps, acceleration warm-up, missing joints, low confidence, gaps, invalid times/coordinates, cancellation, old-report compatibility and bounded inputs. The test thresholds require both jitter reduction and peak retention; they are not technique thresholds.

The native suite also exercises Vision, video limits, mid-analysis cancellation followed by another clip, temporary storage recovery, local history, real external fixtures and narrow/large-type render captures. External fixtures are copied only to the test-owned `Documents/RallyCoachValidation-20260908` path and removed after use. Optional fixture tests explicitly skip when no fixture is supplied.

Still required before enabling the preview normally: clean independent portrait and landscape practice recordings, native iPhone HEVC/HDR exports, higher-rate timing comparisons, 60-second memory/heat measurements, and the complete Photos/iCloud import, cancellation/navigation/backgrounding, VoiceOver and save/delete flow. The Mac was locked for interactive UI automation during this run. XCTest render captures do not replace that end-to-end check.

For exact commands, current device results and screenshot locations, see [RALLY_COACH_VALIDATION.md](RALLY_COACH_VALIDATION.md).
