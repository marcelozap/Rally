# September 17 visual update

The shared athlete rig now uses softer skin and fabric shading, clearer racket construction, separated shoe-upper/rubber materials, cleaner garment boundaries, and smoother preparation/contact/follow-through/recovery. Existing six player identities, equipped-item persistence, foot planting, racket contact positions, scoring and timing remain in place.

The close-up review exposed visible defects and drove actual mesh repairs: covered foot skin is omitted inside mandatory socks/shoes; intersecting triangles are clipped with interpolated UVs and normalized skin weights; the lower shirt follows the pelvis without alternating thigh-weight tears; shorts keep leg clearance while their waistband fits under the top. These are improved generic game garments and shoes, not scanned or exact branded 3D products.

Courts have native 3× raster detail, proper service boxes and net construction, quiet venue scenery, and overscan for camera movement. Home, fitting stages, Shop/Locker, practice and Coach use the shared evergreen/ivory palette and larger athlete presentation. The scoreboard respects the phone safe area, distinguishes score PB from streak records, and keeps the autoplay control out of the timer. A small contact ring replaces the old head-obscuring cyan hit burst in wall/mirror play.

## Validation and evidence

- Full iPhone 16 Pro / iOS 18.6 simulator suite: **266 executed, 265 passed, one external-video-fixture skip, zero failures**.
- Two existing simulator Vision-model-dependent tests were explicitly excluded, as in the preceding integration baseline: `testBlankRotatedVideoRunsWithoutInventingMovement` and `testCancellationDuringAnalysisAllowsAnotherClip`.
- New coverage verifies swing continuity/contact recovery, mesh seam and skin-weight integrity, and covered-foot geometry. Diagnostic attachments show all six identities, male/female equipment close-ups, contact/follow-through, and near/far travel and stops.
- Generic iOS Simulator build passed. Signed generic iPhone build passed; app identity and signature verified; embedded profile includes both known phones. Physical phone installation and performance acceptance are still pending tonight.
- Final proof folder: `/Users/a14/Documents/ChatGPT/Rally/Proof/visual-polish-2026-09-17`. Open `visual-review.html` for before/after screenshots and actual rig renders. `ReleaseCandidateTests.xcresult` and `release-tests.log` contain the final full suite. `generic-build.log` and the installer-folder `device-build.log` record builds.
- Live simulator Home/gameplay and autoplay were inspected; the 20-second autoplay completed with score 3,020 and a 14-shot best streak. The Mac locked during the work, so interactive Shop/detail/customizer and smaller-phone walkthroughs remain **VERIFY**; initial small-phone launch reached the notification/auth screen. Do not infer phone performance or complete UI acceptance from the diagnostic renders.

## Tonight's prepared app

`/Users/a14/Documents/ChatGPT/Rally/Tonight/2026-09-17-visual-upgrade`

Build **0.1.0 (2026091702)**. The installer checks the existing app identity, signature, profile expiration and selected phone before updating in place. It never uninstalls the app. The previous signing-only package remains separately available in `Tonight/2026-09-17`.

The current profile expires **September 24, 2026 at 10:57 a.m. Eastern**. Xcode can renew development signing later without Codex. This is a development install, not an App Store/TestFlight submission.

## Handoff

- Path: `/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally` (owner-authorized relocated checkout).
- Branch: `codex/rally-visual-polish-sept17`, stacked on `codex/rally-visual-lessons-integration` at `e97b511`.
- All current graphics edits belong to this session. Models, sync/auth, stored user data, commerce/referral routes and gameplay rules were not migrated.
- Next: install the prepared app on each phone tonight, check saved avatar/history, clothes during a full rally, both hands, Shop try-on/equip, Coach, and reopen after disconnecting. Account login still depends on the configured server; Continue offline supports local gameplay/Coach.
