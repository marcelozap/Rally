# Finish Rally Coach on my laptop and iPhone

Rally is already installed on my iPhone and looks good. Finish integrating the Rally Coach feature prepared on GitHub, build it on this Mac, and test it on my phone. Preserve my current gameplay, avatar, shop, signing settings, saved data, and any minor local tweaks. Complete the implementation and verification; do not stop at a plan.

## Start from my current app checkout

The repository is `https://github.com/marcelozap/Rally.git`. The active app branch is `rally/dev`, not GitHub's older default `cursor/init-rally-ios-scaffold`. The Coach preparation branch is `codex/rally-coach-ios`, based on app commit `481157f` (the September 5 Mirror Rally update).

Use the actual Rally checkout that built my current phone app. Recent repository notes identify `/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally`; older guard documents still name `/Users/a14/Desktop/Rally`. Confirm the existing project location and its remote, branch, latest commits, and dirty files before choosing. This request authorizes the cross-device continuation in that verified current checkout. Do not create or use a stale replacement copy merely to satisfy an old hard-coded path.

Read `AGENTS.md`, the current lock table, and the focused session instructions. Preserve unrelated uncommitted files. Do not run destructive resets, clean the checkout, discard local changes, or uninstall the phone app to make integration easier. If local work overlaps this feature, reconcile the actual diff; ask only if there is an unresolved choice about which user change to keep.

Run these read-only/status commands from the verified project directory:

```bash
pwd
git rev-parse --show-toplevel
git remote -v
git branch --show-current
git status --short --branch
git log -5 --oneline
git fetch origin
git log --oneline origin/rally/dev..origin/codex/rally-coach-ios
git diff --stat origin/rally/dev...origin/codex/rally-coach-ios
```

Integrate `origin/codex/rally-coach-ios` into a new local integration branch based on my current app state, keeping local fixes. If the worktree is clean, `git switch -c codex/rally-coach-device` followed by `git merge --no-commit --no-ff origin/codex/rally-coach-ios` is a suitable starting point. If that branch already exists, inspect and resume it. Do not blindly replace `rally/dev`, HomeView, or the Xcode project with a downloaded snapshot.

## What is already prepared

Read `docs/RALLY_COACH.md` and the feature files before rewriting anything.

- A Home toolbar **Coach** button and a second entry in Training.
- A SwiftUI video-picker flow with progress, cancellation, errors, report review, and device-local report history.
- `CoachVideoAnalyzer`, which samples an imported 2–60 second video on a background worker and runs Apple's Vision body-pose model locally. The 250 MB limit is checked before copying and again before analysis. Oriented frames are bounded to 720 pixels and sampled at 10 Hz.
- A pure Swift core with confidence and continuity checks, joint-angle ranges, and camera-frame movement observations. Poor tracking produces filming guidance; missing body parts must never become invented measurements.
- Report persistence and temporary-video cleanup. Videos are not uploaded or kept in report history. Reports are separate from the existing account-sync/SwiftData data model.
- A Swift package for portable core tests, plus focused iOS tests and Xcode source registration.

This first phone implementation uses Apple Vision. The earlier Python MediaPipe experiments remain on their own branches for research and calibration. Do not merge the entire `rally-coach` or `xiv-movement` branch into the iOS app, bundle a Python runtime, add a server requirement, or add an LLM API key. The native report format is intentionally distinct from Python's `analysis.v1`; their measurements are not interchangeable.

Keep feedback honest: these are observed 2D movement ranges, not a validated tennis score, stroke diagnosis, ball-contact time, racket speed, or medical guidance. Camera motion and viewpoint affect the values. Do not add confident technique corrections using arbitrary thresholds.

## Finish and build

1. Verify all new Swift files are included exactly once in the Rally target; core and video tests belong in RallyTests. Both `project.yml` and the checked-in project have been updated. Reconcile existing local project changes carefully. Do not broadly regenerate the Xcode project if that would remove hand-maintained asset or signing configuration.
2. Compile against the actual iOS SDK and resolve any Apple-framework availability, PhotosPicker transfer, SwiftUI isolation, or concurrency diagnostics. Windows preparation cannot type-check AVFoundation, Vision, or SwiftUI.
3. Run `swift test` from the repository root. The package tests the same core sources compiled by the app. Run the focused Coach tests in RallyTests, then the existing app suite after integration.
4. Run the usual build:

```bash
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Use `xcrun simctl list devices available` to select an actual simulator for XCTest; do not invent a device ID. Capture the exact commands and results. Repair feature failures and rerun the affected checks before proceeding.

## Verify the complete phone flow

Use my already configured signing and bundle identifier for an in-place development install when the iPhone is connected. Keep the current saved app data. If the device is unavailable or locked, finish everything independent of that, then report the exact remaining device action.

Test and capture screenshots of these states:

- Home -> Coach is obvious and fits the smallest supported phone width; the main PLAY control and avatar remain unchanged.
- Choose a real, clean tennis-practice clip with one person fully visible. The picker may download an iCloud item through the system, but Rally must not upload it. Check portrait, landscape, rotated, and normal iPhone HEVC/HDR exports.
- Progress stays responsive. Cancel during import and analysis, navigate back, background the app, then start another clip. An old job must not publish a stale result or delete the next job's video.
- Try blank footage, a cropped body, poor visibility, and multiple people. The result must withhold unsupported metrics and give useful filming guidance. Reject clips shorter than 2 seconds, longer than 60 seconds, unreadable files, and clips above 250 MB with clear copy.
- Inspect estimates against visible movement in the actual clip. Verify orientation and aspect ratio do not distort joint angles. Check that lost tracking breaks movement continuity rather than adding a jump to travel.
- Save a report, leave Coach, reopen it, relaunch Rally, and delete that report. Test repeated saves and storage errors. Confirm analysis temporary files are cleaned after success, failure, and cancellation and that report saving does not change existing training/journal/account data.
- Force-quit during import/analysis, then relaunch and open Coach. Verify abandoned prior-process clips are removed and unrelated files remain. Also verify a temporary-storage purge can recover without requiring an app reinstall.
- Check Dynamic Type, VoiceOver labels, error dismissal, and long filenames. Capture the empty, analyzing, insufficient-tracking, and saved-report screens.
- Run a brief regression check of Mirror Rally, outfit/player selection, Shop, and Journal. Sound remains off by default.

Do not call the feature device-verified based on synthetic pose tests or the earlier Python demo. Record actual iPhone model, iOS version, clip orientation/duration, processing time, tracking coverage, cancellation behavior, and any heat or memory issues. If real footage reveals unreliable metrics, fix or withhold those metrics before presenting them as useful feedback.

## Finish the handoff

Update `docs/RALLY_COACH_VALIDATION.md` with actual Mac build, XCTest, screenshot, and phone results. Clearly separate completed tests from anything still pending. Commit only the intended feature/integration changes and push the reviewed integration branch; do not merge into the release/app branch until the build and requested device checks are complete. Leave a short report with branch, commit, files changed, test results, phone status, and any specific remaining blocker.
