# Native visual Coach and serve-mode integration

Status: WIP. Not build-ready, installed, visually verified or release-ready.

## Integration provenance

Started at the latest phone-building feature state, 2a488ce, on
codex/rally-visual-lessons-integration. The current branch already contained
rally/dev, rally-coach-ios, rally-coach-device and rally-coach-kinematics.
Only the two product documents were selected from codex/visual-coach-game-modes;
its older app base and separate Python prototypes were not merged.
Existing signing, app identity, assets, account storage and local settings remain.

## Implemented in source, awaiting successful iOS validation

- Native local video replay with slow motion, looping and manually selected comparison start.
- Timestamp-bounded body outline. Missing/low-confidence torso observations hide the outline rather than inventing joints. This remains 10 Hz sampled tracking, not ground-truth motion.
- Shared Rally 3D demonstrator, front/side choices, explicit anatomical hitting hand and highlighted knee. Boy/girl example choices use the existing adult meshes; no new child models are claimed.
- General practice cue and filming help, with diagnostics under optional details.
- Temporary clip ownership lasts only for the open lesson. History remains report-only. The new lifetime still needs cancellation and real Photos testing.
- Serve preparation, toss, timing input and handoff into the existing ball exchange, replacing the independent delayed feed.
- Native mode chooser reuses the timed challenge, adds ten-attempt serve/target sessions, and routes Copy the Coach to the video lesson.
- Settings/pause controls and scene-clock rebasing after interruption.
- Practice does not award ranked rewards. Existing challenge rewards and account models are retained.
- Plain-language introduction and project copy. No LinkedIn posting, partnership claims or new travel booking feature.

## Tests actually run

- `swift test`: 63 portable tests passed, zero failures.
- Full generic iOS Simulator Debug build with Xcode 16.4: FAILED.
- Compiler reports ambiguous numeric division in CoachVisualLesson.swift's Canvas layout, plus a Swift 6 isolation warning in CoachView's PhotosPicker label.
- Correction approval requested before another edit/build pass.
- New focused integration tests were written and explicitly registered, but have NOT run because the app does not compile.
- No new real-video validation, screenshots or recordings. Earlier artifacts must not be presented as evidence for this implementation.

## Remaining acceptance work

1. Resolve compiler error/warning; rerun full build and focused/native suites.
2. Prove serve timing/trajectory alignment with the actual racket. Check misses, duplicate input, all modes, ten-attempt completion and twenty-second challenge timing.
3. Exercise settings, exit/restart, inactive/background and relaunch. Verify reward and Journal isolation for practice.
4. Use real Photos selections in portrait and landscape, both hands, cancellation, missing tracking, repeated selection and saved-history reopening.
5. Inspect real mesh animation, knee highlight, readable short cues, small screens and accessibility. Observe a beginner; do not claim comprehension from unit tests.
6. Capture actual app lesson/gameplay recordings without publishing private footage.
7. Identify the sister's cable-connected iPhone, retain the existing development team and bundle identity, build a signed DEVICE app, install in place and verify launch plus one serve and lesson.
8. Confirm launch after cable disconnection. Read actual profile expiration; do not invent a signing duration.

At discovery, only the phone used for the earlier demo was visible. No install
was attempted on that phone. No personal account session, app data, clips or
device identifiers are included in this handoff. GitHub pushes do not update an
installed development app. No PR merge, TestFlight upload or App Store release
has been performed.

Broader earlier requests for court scenery, clothing icons and personality
flourishes remain outside this checkpoint; they are not claimed complete.

## Device installation references

- [Apple: run an app on a device](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html)
- [Apple: Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
- [Apple: register a device](https://developer.apple.com/help/account/devices/register-a-single-device/)

Unlock and trust are physical user actions. Missing signing permissions must
be resolved using the existing account, not by changing teams, revoking
certificates, purchasing a membership or changing the bundle identifier.
