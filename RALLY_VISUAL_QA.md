# Rally Visual QA

This file records screenshot-backed visual checks. Do not commit screenshot binaries unless the
owner explicitly asks; store paths are evidence for the current machine/session.

## 2026-06-16 — Replay Theater Check

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Autoplay argument: -RallyAutoPlay
```

Screenshots:

```text
Home: /tmp/rally_visual_qa/home_114002.png
Gameplay autoplay: /tmp/rally_visual_qa/autoplay_game_114436.png
```

Findings:

- Home avatar is readable enough for iteration: hair is attached, eyes/mouth are visible, and the outfit/racket state is clear.
- Gameplay avatar now resembles the Home avatar more than older builds, but still fails the North Star premium bar at device scale: face features are too small and fragile, ears/head/neck still read toy-like, and the player does not yet look athletic enough.
- Gameplay ball/contact glow is too large relative to the avatar in the captured frame; it visually covers the racket/player and reduces contact readability instead of improving it.
- Court perspective has depth, but the camera still reads flatter and more front-facing than a realistic wall-rally POV. Rafa should tune gameplay camera/framing before more surface polish.
- The next gameplay pass should prioritize camera/ball-effect scale and player readability over new features.

Recommended next Rafa task:

```text
Use the autoplay screenshot as the baseline. Reduce contact glow dominance, improve gameplay-scale avatar readability, and tune camera/framing so the court reads less flat while preserving the clean score/exit HUD.
```

## 2026-06-16 — Gameplay FX Readability Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Autoplay argument: -RallyAutoPlay
```

Screenshots:

```text
Gameplay autoplay after FX tuning: /tmp/rally_visual_qa/autoplay_after_vfx_123455.png
```

Findings:

- Contact FX are now governed by named tunables instead of hardcoded burst/glow values, so the next Rafa pass can tune them safely.
- Wall-mode ball aura, wall strike burst, racket burst, sparks, and strike-line transition were all reduced to keep the player/racket more readable at gameplay scale.
- The pass is an improvement but not final: the captured contact frame still shows a large ball/aura bloom near the racket, so the next pass should target the BallNode core/aura sizing path directly.
- Camera/player readability remains the larger gameplay issue after FX: the avatar still reads small and toy-like in the court frame.

Recommended next Rafa task:

```text
Tune BallNode core/aura size at the strike plane and adjust gameplay camera/player scale so the body, feet, racket, and ball remain readable during contact without losing depth.
```

## 2026-06-16 — Wall Contact Stack Cleanup

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Autoplay argument: -RallyAutoPlay
```

Screenshots:

```text
Gameplay autoplay after BallNode pass: /tmp/rally_visual_qa/autoplay_after_ball_aura_125312.png
Gameplay autoplay after contact-stack cleanup: /tmp/rally_visual_qa/autoplay_after_contact_stack_132038.png
```

Findings:

- BallNode wall mode now has separate tunables for aura alpha, core alpha, core scale, and contact-scale boost, making ball visibility tunable without changing normal gameplay.
- Wall strike burst, racket-head burst, and strike-line transition now use wall-specific readability scalars instead of large shared/default alphas.
- The player/racket stay more visible through contact than the earlier FX screenshots, but the next meaningful improvement is not more glow shaving: it is camera/player framing plus avatar scale/readability at gameplay distance.
- This pass intentionally avoided avatar geometry hot-zone files and focused only on safe gameplay VFX tunables and contact presentation.

Recommended next Rafa task:

```text
Tune gameplay camera/player framing: enlarge the player slightly, lower/angle the camera toward a more realistic behind-player wall-rally POV, and verify feet/racket/ball remain readable without changing shared avatar geometry.
```

## 2026-06-16 — Gameplay Camera Framing Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Autoplay argument: -RallyAutoPlay
```

Screenshots:

```text
Gameplay autoplay after camera/framing pass: /tmp/rally_visual_qa/autoplay_after_camera_framing_134317.png
Gameplay autoplay after HUD safety nudge: /tmp/rally_visual_qa/autoplay_after_camera_framing_hud_135036.png
```

Findings:

- Court perspective is more aggressive: the near court is wider, the far court is tighter/higher, and the playable field reads more like a behind-player tunnel toward the wall.
- Player scale is larger and grounded lower in frame, improving body/racket readability without touching shared avatar geometry or any avatar hot-zone files.
- Strike plane moved higher so the contact line no longer slices through the avatar face at rest.
- Minimal wall HUD score moved down to clear the Dynamic Island while keeping the score central.
- Remaining issue: contact text/glow can still partially obscure the avatar during PERFECT frames, so the next pass should target contact feedback layering rather than camera geometry.

Recommended next Rafa task:

```text
Tune contact feedback layering: keep PERFECT readable, but move/scale the label and glow so the racket/ball/player remain visible during the exact contact frame.
```

## 2026-06-16 — Contact Feedback Layering Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Autoplay argument: -RallyAutoPlay
```

Screenshots:

```text
Gameplay autoplay after contact-layering pass: /tmp/rally_visual_qa/autoplay_after_contact_layering_141301.png
```

Findings:

- PERFECT timing text is now wall-mode scaled and offset away from the player body/racket instead of using the full normal-contact placement.
- Wall moment banners move higher toward the wall plane and use quieter scale/alpha so streak copy does not compete with the player.
- Contact payoff remains visible, but the player face, body, racket, and ball are easier to read during the captured contact frame.
- Remaining issue: the contact glow cloud itself is still broad; the next pass should tune the glow shape/gradient or clip it away from the avatar silhouette rather than moving text again.

Recommended next Rafa task:

```text
Tune the contact glow shape: keep the hit aura bright around the ball/racket, but reduce the broad beige/white cloud spilling over the avatar silhouette.
```

## 2026-06-16 — Contact Glow Shape Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Autoplay argument: -RallyAutoPlay
```

Screenshots:

```text
Gameplay autoplay after contact-glow pass: /tmp/rally_visual_qa/autoplay_after_contact_glow_shape_145538.png
```

Findings:

- Wall-mode racket-contact halo and BallNode proxy aura now use named wall-specific readability tunables instead of the shared normal-contact bloom values.
- Strike-line transition halo/sweep now uses lower wall-mode alpha knobs instead of hardcoded broad bloom alphas.
- Build passes, and the captured frame keeps the avatar, racket, and ball readable through contact better than the earlier broad-glow screenshots.
- Remaining issue: a broad contact aura still exists around the strike moment. The next pass should inspect `stageRacketContactHalo` / `stageContactImprint` and consider replacing the circular cloud with a tighter directional spark/comet payoff.

Recommended next Rafa task:

```text
Inspect the remaining contact halo/imprint emitters and replace the broad circular cloud with a tighter directional racket-spark/comet effect so contact remains punchy without covering the player.
```

## 2026-06-16 — Directional Contact Imprint Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Autoplay argument: -RallyAutoPlay
```

Screenshots:

```text
Gameplay autoplay after directional-contact pass: /tmp/rally_visual_qa/autoplay_after_directional_contact_151347.png
Contact-frame burst proof: /tmp/rally_visual_qa/autoplay_directional_burst_1_151541.png
```

Findings:

- The older `stageRacketContactHalo` circle now uses wall-mode alpha/glow/scale tunables, so it no longer expands into a full fog bubble over the avatar.
- `stageContactImprint` now heavily quiets wall-mode rings and pushes the slash/spark travel farther, making the hit read more like a racket cut than a circular cloud.
- The contact-frame proof shows the avatar, feet, racket head, and ball remain readable while the hit still has a visible yellow-white payoff.
- Remaining issue: wall-mode score typography can become visually too large/noisy during long autoplay runs; next Rafa pass should clamp/format the score display for six-digit survival runs without covering the Dynamic Island.

Recommended next Rafa task:

```text
Clamp and format the wall-rally score HUD for long survival runs, then verify the contact effect still reads in a normal manual run and not only autoplay.
```
