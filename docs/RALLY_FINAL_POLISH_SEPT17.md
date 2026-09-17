# Final finishing pass — September 17

The owner approved the revised backhand as “looking much better,” then requested finishing touches. This pass preserves that motion and the existing real Shop photos, World links and Clean Eight challenge.

## Changes

- Keep the live wall-rally ball at its intended court-relative size through contact, return, reentry and normalization. Motion models provide normalized deformation around 1; previously that became a full-size 44-point ball and obscured the racket. Serve-created balls now derive the same court-relative basis as ordinary feeds. A softer outline and reduced glow improve contact clarity. Trajectory, timing, grading and deformation remain intact.
- Bag and accessory cards open their product details directly. Clothing and racket cards retain avatar previews. Shop filters and stage Details have at least 44-point tap targets, selected filters expose their state, and Details names its product for accessibility.
- World website/maps actions stack at accessibility text sizes, while link descriptions wrap vertically and decorative icons stay out of the accessibility reading order.
- Hide and disable the underlying court surface while a result or serve-practice introduction covers it. The earlier result accessibility tree exposed hidden Exit/Pause/Settings and SpriteKit HUD elements.

## Verification

- Final native suite: **308 executed, 307 passed, one fixture skip, zero failures**. The fixture skip is `CoachVideoAnalyzerTests/testRealTennisClipsWhenProvided`. Two existing simulator Vision-model exclusions remain: `testBlankRotatedVideoRunsWithoutInventingMovement` and `testCancellationDuringAnalysisAllowsAnotherClip` in `CoachVideoAnalyzerTests`.
- New regressions cover court-relative ball size across ownership transitions, preserved trajectories/deformation/rearm timing, and unchanged non-wall presentation. The first run used exact equality for SpriteKit Float32 transforms; only those new assertions failed. Measured rounding was below 0.000031 point for position and 0.000000047 for scale. Appropriate tolerances corrected the tests; the final full suite passed without production-code changes.
- Generic iOS Simulator Debug and signed generic iPhone Debug builds passed. Signed app: **0.1.0 (2026091705)**.
- A native iPhone 16 simulator recording completed the full Clean Eight run: **3,020 points, 14-shot streak, 100% autoplay timing**. Sampled frames confirm the reduced ball diameter/outline exposes more of the hand and racket. This is automated input, not a human timing assessment. The previously accepted rig and both-hand pose evidence remain unchanged.
- Packaged app passes strict deep signature verification, expected bundle/team/build checks, profile expiration and registration for both known phones. No physical-device commands were run.
- Final interactive Shop/World/hand-picker checks and verification of the revised result accessibility tree remain **VERIFY** because the Mac relocked during the walkthrough. Physical-phone performance, touch timing, sound/haptics and saved-data acceptance remain for tonight.

Proof: `/Users/a14/Documents/ChatGPT/Rally/Proof/final-polish-2026-09-17`. Final suite: `FinalPolishReleaseTests.xcresult` and `release-tests.log`. Gameplay: `gameplay-right.mp4`, `gameplay-right-result.png` and `gameplay-right-frames/`. The earlier failed test bundle is retained separately as `FinalPolishTests.xcresult`.

## Handoff

- Owner-authorized source: `/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally`.
- Branch: `codex/rally-gameplay-feel-sept17`. The installation manifest records the exact commit containing this note and the packaged app hashes.
- Latest packet: `/Users/a14/Documents/ChatGPT/Rally/Tonight/2026-09-17-final-polish`. Start at `/Users/a14/Documents/ChatGPT/Rally/Tonight/START-HERE.md`.
- Development signing expires **September 24, 2026 at 10:57:29 a.m. EDT** (`2026-09-24T14:57:29Z`). The guide includes renewal through Xcode without Codex.
- Install in place on each known phone, preserving the existing app. Check saved avatar/gear/history, both handedness settings, Shop cards/photos/preview, World links, full challenge/retry, performance and reopen after disconnecting. Neither phone has been changed in this pass.
- App identity, authentication/sync and approved avatar motion are unchanged. Earlier build packets are preserved. No unrelated dirty files were present at the start; none are intended after this commit.
