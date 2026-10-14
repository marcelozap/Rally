# Email subject: Finish Rally updates and install on my sister's iPhone

Paste the instructions below into the laptop assistant with the Rally project open.

---

Finish the Rally updates described below, build the app on this Mac, and install the verified build on my sister's iPhone connected by cable. Do the implementation and testing, not just another plan. Preserve the current working demo, local tweaks and saved data.

## Get the correct work

Repository: https://github.com/marcelozap/Rally

Latest product plan and this prompt: `codex/visual-coach-game-modes`, PR https://github.com/marcelozap/Rally/pull/5.

Read `docs/RALLY_VISUAL_COACH_AND_GAME_MODES.md` and `docs/RALLY_PROJECT_DESCRIPTION.md` from that branch. Fetch before reading so you receive the updated prompt.

Start in the actual checkout that built my existing iPhone demo. Verify its path, remote, current branch, recent commits and working-tree status. The repo notes a relocated Mac checkout at `/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally`; verify the real location instead of assuming an old hardcoded path. Read current repository instructions and active locks.

Inspect `rally/dev`, `codex/rally-coach-ios`, `codex/rally-coach-device`, and `codex/rally-coach-kinematics` to identify changes already integrated. Do not replace newer device work with the older base of the documentation branch. Keep existing hand selection, gated motion analysis and import/history fixes where appropriate. The separate Python prototype branches are not automatic merge targets.

Create an integration branch from the latest working app state. Preserve uncommitted edits, signing, assets and configuration before bringing in changes. Bring over the plan/copy documents selectively; reconcile the README introduction without replacing newer technical documentation. Do not reset, clean or blindly merge every branch. If an overlapping edit requires a real product choice, show the exact conflict; resolve routine integration issues yourself.

## Implement the full requested experience

1. Update the app's applicable introductory/About copy and project documentation to use the plain-language description in `docs/RALLY_PROJECT_DESCRIPTION.md`: fun tennis mini-games, swipe timing, avatar customization, tennis fashion, travel, match journaling and movement practice. Preserve existing brand/outfit features and links without inventing partnerships or new travel functionality. No technical jargon in the player flow. Keep LinkedIn text ready to copy; no automatic LinkedIn posting is requested.
2. Replace the chart as the primary Coach experience. Show "Your movement" with video replay and a trustworthy body outline, and "Try this" with a simple animated demonstration. Offer a boy or girl demonstrator, matching view and hitting hand where feasible. Include slow motion, looping, one highlighted body part, a short cue, and "Try again." Keep diagnostic charts optional. General examples must be labeled as practice examples; only issue personalized corrections when the evidence supports them. Missing tracking should lead to visual filming help.
3. Start every point in the current Rally game with a serve. Show preparation, toss and contact, then transition smoothly into the existing rally. Preserve swipe timing and current avatar appearance. Handle misses, retries, scoring, restart and pause/background recovery without duplicate balls or timers.
4. Implement playable Serve Practice, Rally Challenge, Copy the Coach and Target Practice using the existing mechanics and character system. Reuse the current challenge rather than duplicating it. Copy the Coach may use demonstration and recorded comparison; do not claim live camera technique scoring without implementing and validating it. Build each mode to a usable state, not merely a menu placeholder.
5. Keep the existing style, tennis clothing, travel/court features, Journal, accounts and saved progress working. Use the feature plan's acceptance checks and implementation order. Finish the requested modes after proving the first lesson and serve cycle.

## Verify on the Mac and phone

Run appropriate focused tests and the existing relevant suites, then build the complete iOS app with the installed Xcode toolchain. Preserve the maintained Xcode project and register new sources explicitly; do not blindly regenerate it. Discover available simulators/devices instead of copying IDs from old logs.

Exercise the real Photos import and comparison flow, unavailable tracking, left/right handedness, portrait/landscape clips, playback, cancellation and saved reports. Test every mode, a full serve-to-rally-to-next-point cycle, outfits in gameplay, Journal persistence, relaunch, and background recovery. Check small screens, legible short cues and accessible controls. Save screen recordings showing the actual visual lesson and gameplay; report synthetic test results separately from real-video observations.

## Install on my sister's iPhone by cable

Use the connected physical iPhone as the destination. Identify it from Xcode's device list; if multiple phones are connected and identity is ambiguous, ask which one is hers. Never reuse my phone's identifier from old validation logs.

Have us connect a data-capable cable, unlock the phone and accept the Trust This Computer prompt. If Xcode requires Developer Mode, guide us through enabling it on the phone and the required restart/confirmation. Those physical actions may require us; continue independent build work while waiting.

Use the project's existing development team and bundle identifier. Verify signing supports this additional device; use Xcode automatic signing/device registration when available with the existing account. Do not buy a membership, switch teams, revoke certificates or change app identity to bypass a signing error. If credentials or account permissions are missing, state the exact remaining action.

Build and Run the Rally scheme with her connected iPhone selected, or use the installed Xcode tools to install and launch the signed device build. Do not install a simulator build. Keep any existing Rally installation/data intact; do not uninstall to work around an error. Do not copy my personal app data or account session onto her phone; use a fresh guest session or her own account.

Verify the app opens on her phone, test a serve and one Coach lesson, then disconnect the cable and confirm it still launches. Explain any actual development-signing expiration/reinstallation requirement shown by the selected signing setup. Cable installation is a development build, not an App Store release, and future GitHub pushes will not automatically update her installed app.

Apple references: [Run on a device](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html), [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device), [Device registration](https://developer.apple.com/help/account/devices/register-a-single-device/).

## Finish and report

Commit and push all owned implementation changes on the integration branch and create/update a draft PR. Include the completed features, test results, screenshots/recordings, exact build commit and actual device-install outcome. Preserve unrelated files and exclude private clips, device identifiers and signing secrets from published proof. Do not merge or publish an App Store release automatically. If phone unlock, trust or signing blocks installation, finish all independent work and clearly distinguish "build ready" from "installed and verified." Do not mark the entire task done while requested features remain placeholders.
