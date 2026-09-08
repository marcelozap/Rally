# Rally Coach validation

Preparation completed on Windows on September 8, 2026. Feature branch: `codex/rally-coach-ios`. App base: `rally/dev` at `481157f`, rechecked against GitHub before handoff.

## Completed here

| Check | Result |
| --- | --- |
| Foundation-only Swift package | 43 tests discovered: **41 passed, 2 skipped, 0 failures** |
| Movement/report tests | Confidence and missing-limb gates, tiny-player rejection, aspect-correct coordinates, tracking gaps, duplicate/invalid timestamps, exact time boundaries, finite metrics and validated report decoding passed |
| Persistent history tests | Save/reload/delete, repeated and concurrent saves, invalid/corrupt/oversized history preservation and storage errors passed |
| Temporary-video workspace tests | Prior-process recovery, active-clip preservation, scoped deletion, failed-cleanup retry and OS temp-purge recovery passed |
| Swift syntax parsing | New SwiftUI/Photos/AVFoundation/Vision sources, focused Apple tests, and changed Home/Training source parsed successfully |
| Xcode project structure | OpenStep project parsed; eight new app sources and five test files registered exactly once; existing source/resource references and target settings preserved |
| Whitespace and diff review | `git diff --check` passed; independent source review completed |

Toolchain: Swift 6.3.1 on Windows, package Swift tools/language compatibility set to 5.9. This host's existing SDKROOT had a trailing Windows separator that broke SwiftPM manifest lookup. The test process used this local normalization without modifying the repository or system configuration:

```powershell
$env:SDKROOT = $env:SDKROOT.TrimEnd([char]92).Replace([char]92, [char]47)
swift test
```

The two skipped tests create symbolic links. This Windows account lacks that privilege; they must run on the Mac. The conditional Apple backup-exclusion test was not compiled on Windows.

The portable tests use deterministic poses and temporary filesystem fixtures. They do **not** execute Apple's Vision model, prove real tennis accuracy, or establish iPhone UI quality. The prior task's MediaPipe demo validated a different Python pipeline and is not evidence that this native adapter has run.

## Required on the laptop

- Compile the full Rally Xcode target against its actual iOS SDK. Parse-only checks do not catch type, framework-availability or actor-isolation errors.
- Run the Coach tests in RallyTests, including the seven AVFoundation/Vision tests and the conditional Apple backup-exclusion test. Run the two symlink tests and the existing Rally suite.
- Run actual pose inference with a real, clean single-player practice clip. Inspect orientation, range estimates, frame coverage and processing time. No real Apple Vision inference was run on this host.
- Verify Photos/iCloud import, supported iPhone formats, cancellation, navigation/backgrounding, progress and error states on the device.
- Check report persistence and deletion after relaunch; test force-quit cleanup, current-session isolation and temp-purge recovery.
- Capture the empty, analyzing, insufficient-tracking, result and history screens. Check small-screen layout, Dynamic Type and VoiceOver.
- Install in place with the existing signing and bundle identifier; verify the current game, avatar, Shop, Journal and saved data remain intact.

Follow [the laptop prompt](../RALLY_COACH_LAPTOP_PROMPT.md) for the exact continuation. Append the Mac build command/results, device/iOS version, real-clip observations, screenshots, and remaining issues here. Until those checks pass, the feature is prepared for integration, not phone-verified.

## Mac integration: September 8, 2026

Verified current checkout: `/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally`, origin `https://github.com/marcelozap/Rally.git`, starting branch `rally/dev`, app commit `481157f`. Integrated preparation commit `e843ce5` on `codex/rally-coach-device` with a non-fast-forward merge. Preserved local Xcode object ordering, signing team, Info.plist version substitutions, and untracked shipping files. A semantic project comparison confirmed all original source/resource objects and signing settings were preserved; eight Coach app sources and five test sources occur once in the correct targets.

Fixed Apple-only issues: PhotosPickerItem needs the SwiftUI overlay import in the view model and transfer adapter; cleanup retries must invalidate Foundation URL resource caches before checking a repaired directory.

| Check | Actual result |
| --- | --- |
| Xcode | 16.4 (16F6) |
| `swift test` | 44 passed, no skips or failures after fixing cleanup retry |
| Generic iOS Simulator build | Passed, arm64 and x86_64 |
| Focused Coach XCTest | 50 passed; the blank-video Vision test failed because the simulator runtime is missing `cnn_human_pose.espresso.weights` |
| App XCTest regression | 226 passed, no failures, with only that model-dependent test explicitly excluded |
| Physical device discovered | iPhone 16 Pro, iOS 26.6.1; paired, connected, Developer Mode enabled |
| Live UI verification | Pending: Mac UI automation reported a locked Mac; iPhone Mirroring is not configured/connected |
| Real tennis accuracy, formats and performance | Pending; no real-clip accuracy or device-performance claim |

Exact commands (run from the checkout above):

```bash
swift test
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'platform=iOS Simulator,id=CA3029AB-A788-4370-BD71-E556B01C8FE6' -only-testing:RallyTests/CoachAnalyzerTests -only-testing:RallyTests/CoachImportWorkspaceTests -only-testing:RallyTests/CoachReportStoreTests -only-testing:RallyTests/CoachReportTests -only-testing:RallyTests/CoachVideoAnalyzerTests -resultBundlePath /tmp/rally-coach-device-20260908/CoachFocused.xcresult CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'platform=iOS Simulator,id=CA3029AB-A788-4370-BD71-E556B01C8FE6' -skip-testing:RallyTests/CoachVideoAnalyzerTests/testBlankRotatedVideoRunsWithoutInventingMovement -resultBundlePath /tmp/rally-coach-device-20260908/RallySuite.xcresult CODE_SIGNING_ALLOWED=NO test
```

Build logs and result bundles are under `/tmp/rally-coach-device-20260908/`. The source test remains intact for a device/runtime with the Vision model. An existing Swift 6 isolation warning in RallyReferralLinkRouter is outside Coach. Release/app branches have not been advanced.

## Kinematics integration and device handoff

Feature branch: `codex/rally-coach-kinematics`. The baseline integration was committed as `56a0f66`. The algorithm reference, tuning and preview gate are documented in [RALLY_COACH_KINEMATICS.md](RALLY_COACH_KINEMATICS.md).

| Check | Actual result |
| --- | --- |
| Existing native Coach on iPhone | All 51 focused tests passed, including the real Vision blank-video test that the simulator cannot run |
| Final Swift package | 63 passed, no skips or failures |
| Final generic iOS Simulator build | Passed |
| Final complete simulator regression command | 247 executed, 1 optional external-fixture test skipped, 0 failures; the two Vision-dependent tests were explicitly excluded because this runtime lacks the model |
| Expanded Coach suite on iPhone before final tuning/render changes | 73 passed, no skips or failures; included real footage and cancellation followed by another clip |
| Final signed device build | Passed with existing signing and `com.marcelozap.rally` identity |
| Final iPhone test rerun | Did not start: Xcode reported `Unlock iPhone to Continue`; this is pending, not a pass |
| Final in-place install | Succeeded through devicectl while the phone was locked; no uninstall or app identity change |
| Existing saved data | Before/after copies have identical SHA-256 hashes for `default.store`, its WAL and Rally preferences; only SQLite's shared-memory coordination file changed |
| Final source registration | Ten Coach app sources and six Coach test sources registered once in their respective targets; original project objects/assets/signing preserved |
| Narrow and large-type layout capture | Focused XCTest capture passed; final 320-point empty/hand-selector and synthetic motion timeline renders visually inspected |
| Test video cleanup | Cleared both public fixture videos from the dedicated device validation directory after the locked-device run |

Real iPhone measurement (iPhone 16 Pro, iOS 26.6.1, initial filter candidate):

| Clip | Orientation / framing | Duration | Processing | Body coverage | Arm-velocity coverage | Thermal state |
| --- | --- | --- | --- | --- | --- | --- |
| UCF101 TennisSwing g01/c01, H.264 MOV | Landscape 320 x 240 | 2.57 s | 0.386 s | 30.8% | 26.9% | Nominal before/after |
| Same footage, padded H.264 MOV | Portrait canvas 320 x 568 | 2.57 s | 0.459 s | 0% | 76.9% | Nominal before/after |

These are two framings of one low-resolution clip, not independent portrait/landscape phone recordings. Full-body continuity was insufficient, and unsupported baseline metrics were withheld. Mid-analysis cancellation and a subsequent fresh analysis passed on the physical phone. Whole-app resident memory samples ranged from approximately 353 to 457 MB; they include the game/test host and are not peak memory measurements. No sustained-heat conclusion is supported.

The final filter reduces synthetic stationary jitter by 47.1% and retains 96.9% of the synthetic fast-reversal peak. Replaying real observations on the Mac retains 79.8%/77.3% of landscape/portrait peaks, with no sampled peak-time shift. Final tuned phone execution remains pending the unlock. The preview therefore stays off by default, and sampling remains at 10 Hz.

Final command details, in addition to the baseline commands above:

```bash
swift test
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'platform=iOS Simulator,id=CA3029AB-A788-4370-BD71-E556B01C8FE6' -skip-testing:RallyTests/CoachVideoAnalyzerTests/testBlankRotatedVideoRunsWithoutInventingMovement -skip-testing:RallyTests/CoachVideoAnalyzerTests/testCancellationDuringAnalysisAllowsAnotherClip -resultBundlePath /tmp/rally-coach-device-20260908/FinalRallySuite.xcresult CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'platform=iOS,id=00008140-001204213C62401C' -derivedDataPath /tmp/rally-coach-device-20260908/DeviceBuild -only-testing:RallyTests/CoachAnalyzerTests -only-testing:RallyTests/CoachImportWorkspaceTests -only-testing:RallyTests/CoachReportStoreTests -only-testing:RallyTests/CoachReportTests -only-testing:RallyTests/CoachMotionAnalysisTests -only-testing:RallyTests/CoachVideoAnalyzerTests -resultBundlePath /tmp/rally-coach-device-20260908/FinalPhone.xcresult DEVELOPMENT_TEAM=832KFP5M8B test
xcrun devicectl device install app --device C74329CC-B77B-5815-9668-EB9EDE35B247 /tmp/rally-coach-device-20260908/DeviceBuild/Build/Products/Debug-iphoneos/Rally.app --timeout 30
```

The earlier successful 73-test device result is `MotionPhone.xcresult`; the final locked-device attempt is `FinalPhone.xcresult`. Final render evidence is `FinalLayouts.xcresult`. Full command outputs are saved beside those bundles as `final-swift-test.log`, `final-build.log`, `final-rally-suite.log`, `final-phone.log` and `final-layouts.log`.

Local proof files are kept in the ignored `Artifacts/CoachValidation-20260908/` directory: `coach-empty-320.png`, `coach-large-type-320.png`, `motion-synthetic-320.png`, `home-simulator.png`, and the two initial iPhone JSON reports. The motion screenshot uses synthetic data to show paths, gaps and limited confidence; it is not a real-clip/device-accuracy claim. Initial offscreen capture problems were fixed in the capture harness and by using native SwiftUI paths for the timeline; superseded blank captures are not evidence of a working review.

### Remaining device actions

Unlock the Mac and iPhone to rerun the final focused tests and complete the real Photos-picker flow. Supply clean, independently filmed portrait and landscape practice clips plus native HEVC/HDR examples. Verify iCloud import, import cancellation, back navigation, background/force-quit recovery, repeated save/delete, VoiceOver and the longest supported clips. Capture analyzing, insufficient-tracking and saved-history screens through the actual user flow, and check Home/PLAY, Mirror Rally, outfits, Shop and Journal interactively. Neither this branch nor the release/app branch should be treated as fully device-verified until those checks are recorded.
