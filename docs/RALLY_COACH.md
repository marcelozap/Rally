# Rally Coach

Rally Coach adds a local practice-video review flow to the iPhone app. Open **Coach** beside Journal on Home, or use the Coach entry in Training. Choose a short video, review tracking quality and movement observations, and save a report on that device.

## Scope of this version

This version measures visible movement from one person in a 2–60 second clip, up to 250 MB. It uses Apple's Vision body-pose model, with no server, account requirement, external model download, or LLM integration. The operating system may need to download a selected iCloud Photos item before analysis can start.

Reports describe estimated joint-angle ranges and movement within the camera frame. They are not calibrated tennis judgments. The app does not claim to identify contact, classify strokes, rate form, estimate racket speed, or prescribe technique corrections. A moving camera, occlusion, and viewpoint can change the measurements.

The existing Python MediaPipe work remains separate. It provides research context, not an embedded phone runtime. This feature's native report schema has different provenance and units from the Python `analysis.v1` schema; do not combine the results as if they were equivalent.

## Data flow

```text
PhotosPicker -> bounded temporary movie -> oriented video frames
             -> Apple Vision poses -> CoachAnalyzer -> CoachReport
             -> optional device-local report history
```

- The picker imports only the video selected by the user. Broad photo-library access and camera permissions are unnecessary.
- The analyzer runs off the main actor. It samples at 10 Hz, retains at most one bounded image at a time, and uses actual decoded timestamps.
- Vision coordinates are converted to an upright top-left coordinate system, with both axes expressed in image-height units so portrait/landscape aspect does not distort angles.
- Ambiguous multi-person frames, failed extraction, missing joints, and low confidence reduce coverage. Movement continuity breaks at tracking gaps.
- Cancellation is propagated into the worker and media requests; the caller waits for worker teardown before removing its imported file.
- Temporary clips are removed after analysis, failure, or cancellation. Saved reports contain observations only, not video, pose arrays, or photo-library identifiers.
- Opening Coach after an interrupted app process prunes abandoned clips from its dedicated temporary workspace. Current-process clips and unrelated files are preserved. Failed cleanup blocks a new import until retry succeeds; an OS purge of temporary storage can recover without relaunching the app.
- Report storage is separate from SwiftData and Rally's account-sync snapshot. Save/delete failures are surfaced, and writes are atomic. Reports are excluded from device backup.

## Files

| Area | Role |
| --- | --- |
| `Rally/Features/Coach/Core/` | Portable pose types, report contract, quality gates and measurements |
| `Rally/Features/Coach/Core/CoachImportWorkspace.swift` | Process-scoped temporary clips and recovery after an interrupted process |
| `Rally/Features/Coach/Services/` | Apple video inference, selected-video import and local report storage |
| `Rally/Features/Coach/CoachView.swift` | Picker, progress, report and history presentation |
| `Rally/Features/Coach/CoachViewModel.swift` | Main-actor task, cancellation and result ownership |
| `Tests/RallyCoachCoreTests/` | Core regression tests used by SwiftPM and RallyTests |
| `RallyTests/CoachVideoAnalyzerTests.swift` | Apple-side validation and media tests |
| `RALLY_COACH_LAPTOP_PROMPT.md` | Copyable laptop implementation and device-verification prompt |

All app sources are registered in the checked-in Xcode project. `project.yml` also includes the portable tests for future controlled project generation. The package compiles the actual app core sources; it is not an additional runtime dependency in Xcode.

## Verification

```bash
swift test
```

The Windows environment can execute Foundation-only tests and parse Swift syntax. It cannot type-check the Apple frameworks, run Xcode, or install the phone app. The current evidence and remaining Mac/iPhone checks are recorded in [RALLY_COACH_VALIDATION.md](RALLY_COACH_VALIDATION.md). Follow the [laptop prompt](../RALLY_COACH_LAPTOP_PROMPT.md) to complete those checks.

The video adapter follows Apple's [body-pose detection](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images) and [asynchronous frame extraction](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image%28at%3A%29) APIs. Those Apple-specific paths still require the Mac/iPhone checks above.
