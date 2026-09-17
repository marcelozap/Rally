# September 17 gameplay and discovery update

Prepared build **0.1.0 (2026091703)** on `codex/rally-gameplay-feel-sept17`, based on verified visual commit `7457ca5`. Physical-phone acceptance remains VERIFY.

## Changes

- Clean Eight adds an optional goal to the existing 20-second Mirror Rally: reach eight consecutive returns, then finish the run. The live HUD shows best streak against the goal; results distinguish goal met, goal missed and incomplete play. A separate local record tracks completed attempts, clears and best streak. Stable run IDs prevent duplicate completion callbacks from counting twice. Debug autoplay does not create challenge records.
- Shared athlete movement loads the hips and shoulders before a stroke and transfers weight during the finish while keeping grounded feet and existing contact positions. Serving now completes its overhead follow-through before returning to the ready pose. Its instruction fades after launch instead of covering the court for the whole rally.
- Player setup exposes the existing persisted left/right playing-hand preference. The two-handed backhand mirrors that choice for both court players. The supporting hand joins the upper racket handle, stays attached through contact and releases smoothly. Shoulder rotation, elbow clearance and follow-through were reviewed across all six athletes and both hands.
- Contact sounds use shorter synthesized ball/string attacks, with subtler vibration and a light perfect-contact echo. Existing mute and vibration settings remain in force; disabling vibration cancels cached active patterns.
- World destination cards expose separate Official site and Maps actions; details place official links before secondary facts. Old destinations were checked and repaired. See `RALLY_WORLD_LINKS_SEPT17.md` for source evidence and access limits.
- Every paid non-Rally storefront item has a bundled official product photograph: 32 images cover 33 saved item IDs, including one hidden legacy duplicate. Photos load without a network connection in the grid, brand cards, detail and related-item rail. Exact saved ID, category and product URL select each photo. Existing saved-item IDs, outfit colors, prices and racket tuning remain stable. See `SHOP_PHOTOGRAPHY.md` for exact product/colorway mappings and source evidence.

## Verification

- Final native suite: **294 executed, 293 passed, one fixture skip, zero failures**. `ReleaseCandidateTests.xcresult` and `release-tests.log` contain the results. The skipped test needs externally supplied tennis video fixtures.
- Two known simulator Vision-model-dependent tests remain explicitly excluded: `CoachVideoAnalyzerTests/testBlankRotatedVideoRunsWithoutInventingMovement` and `CoachVideoAnalyzerTests/testCancellationDuringAnalysisAllowsAnotherClip`. This is not a claim that those tests passed.
- Generic iOS Simulator Debug build: **BUILD SUCCEEDED** (`release-simulator-build.log`). Generic signed iPhone Debug build: **BUILD SUCCEEDED** (packet `device-build.log`).
- The final 23 avatar tests passed, including mirrored two-handed grip attachment, contact placement, shoulder rotation and sleeve clearance checks. Native renders for all six athletes and both hands are in `backhand-final-renders`. Small existing garment shoulder/sleeve seam gaps remain visible in close-up renders; exact branded 3D garment replicas are not part of this update.
- Clean Eight completed in live iPhone 16 and iPhone 16 Pro simulators with a 14-shot streak. Initial goal HUD, readable result screens, retry/mode-selection navigation and exclusion of debug autoplay from challenge records were checked. These UI screenshots precede the final World/Shop/backhand additions.
- All bundled product images were decoded, dimension-checked and visually inspected; catalog/resolver tests pass. World destinations were researched using official sources; automated access limitations are listed in `RALLY_WORLD_LINKS_SEPT17.md`.
- The Mac locked before final Shop/detail, World link tapping and hand-selector walkthroughs. Those interactive checks remain **VERIFY**. No physical-phone installation or sound/vibration/performance acceptance has been performed during this update.

Evidence: `/Users/a14/Documents/ChatGPT/Rally/Proof/gameplay-feel-2026-09-17`.

Physical-phone installation, vibration/sound feel and performance remain for tonight. No physical phone has been changed by this task. No data migration, app-identity change or uninstall is part of the update. Shop photographs identify merchandise; existing generic game clothing remains labeled as a style preview.

## Handoff

- Path: `/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally` (existing owner-authorized relocated checkout).
- Branch: `codex/rally-gameplay-feel-sept17`.
- Last commit: the commit containing this handoff; its exact hash is recorded in the packet's `build-manifest.json` after commit.
- Dirty files: none intended after committing this work. No unrelated edits were present at the start.
- Files intentionally left untouched: app identity, backend/auth/sync, physical-phone data and earlier signing-only/visual-upgrade packets.
- Prepared packet: `/Users/a14/Documents/ChatGPT/Rally/Tonight/2026-09-17-gameplay-update`, with signed `Rally.app`, installer, instructions, manifest and logs.
- `install-rally.command --check-only` passed: strict deep signature, expected bundle/team/build and provisioning coverage for both known phones. No device commands were run. Provisioning expires **September 24, 2026, 10:57:29 a.m. EDT** (`2026-09-24T14:57:29Z`).
- Next acceptance: install in place on each known phone, confirm existing avatar/history, check both playing hands, full challenge/retry, Shop imagery/detail/try-on, World website/map links, sound/vibration preferences, and reopen after disconnecting.
