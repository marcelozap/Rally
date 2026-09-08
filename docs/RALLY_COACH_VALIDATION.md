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
