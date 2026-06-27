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

## 2026-06-22 — Lazy Audio Launch + Wall Spark Readability Pass

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
Home launch after lazy audio: /tmp/rally_visual_qa/launch_after_lazy_audio_013154.png
Gameplay autoplay after contact-spark tuning: /tmp/rally_visual_qa/autoplay_after_lazy_audio_contact_013559.png
```

Findings:

- Rally now launches silently with the sound toggle off; the previous AVAudioEngine launch abort was fixed by making AudioManager lazy until the player explicitly enables sound.
- Home launch screenshot is valid and no longer a black crash frame.
- Gameplay autoplay reaches live contact with score/combo visible, confirming the app survives the debug run path.
- Wall-contact sparks now use lower alpha, fewer particles, smaller cores, and an outward origin offset so the payoff stays around the ball/racket instead of washing over the avatar silhouette.

## 2026-06-25 — Tight Wall Contact FX Proof

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Tests:

```text
WallRallyEscalationTests: 27 passed, 0 failed
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Autoplay argument: -RallyAutoPlay
```

Screenshot:

```text
Gameplay autoplay after tight contact FX: /tmp/rally_visual_qa/tight_contact_fx_003117.png
```

Findings:

- Wall contact halo, spark count, spark alpha, and spark size are lower so contact reads as a tight tennis beat instead of a broad flash cloud.
- The contact frame reached a live rally state (`335`, x4), confirming ball feed and scoring are active after the FX pass.
- `PERFECT` text remains fully on-screen after the prior clamp, and the player silhouette remains visible through contact.
- Remaining issue: the avatar still reads too puppet-like at gameplay scale, but that belongs to the avatar/geometry lane rather than this Rafa FX pass.

## 2026-06-26 — Wall Feed Watchdog Visual Verify

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Autoplay argument: -RallyAutoPlay
```

Screenshot:

```text
Gameplay autoplay after wall-feed watchdog hardening: /tmp/rally_visual_qa/wall_feed_watchdog_verify_041220.png
```

Findings:

- Wall rally reached live scoring (`335`, x4), so the post-countdown / empty-court feed path is not stuck in the captured run.
- Ball, racket, score, best marker, and `PERFECT` feedback are visible in the same frame, confirming contact and timing feedback are active after the watchdog recovery patch.
- The broad gameplay issue is unchanged: the player still reads toy-like/puppet-like at device scale. Next work should claim the avatar hot zone and improve head/shoulders/feet/anatomy through the shared avatar pipeline, not through more contact-FX tuning.

## 2026-06-22 — Opening Rally Mercy Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Regression test:

```text
xcodebuild test -project Rally.xcodeproj -scheme Rally -destination 'platform=iOS Simulator,id=CA3029AB-A788-4370-BD71-E556B01C8FE6' -only-testing:RallyTests/WallRallyEscalationTests CODE_SIGNING_ALLOWED=NO
Result: TEST SUCCEEDED — 16 tests, 0 failures
```

Screenshot:

```text
Opening mercy proof: /tmp/rally_visual_qa/opening_mercy_170249_5s.png
```

Findings:

- First zero-score warm-up misses now use a named survival mercy contract: 3 misses over 7 seconds do not spend lives.
- Forgiven opening misses show `WARM UP` and feed the next ball quickly, making the first run feel like onboarding instead of instant punishment.
- The mercy ends once time/miss budget is consumed or the player has a score/combo, preserving survival stakes.
- Remaining task: visual/manual test on real phone to tune whether 7s/3 misses feels generous enough or too soft.
- Remaining visual issue: the avatar still looks stylized and toy-like at gameplay scale; the next meaningful pass should be anatomy/face/stance quality, not more wall spark shaving.

Recommended next Rafa task:

```text
Run a focused avatar anatomy pass against the current gameplay screenshot: improve face/ears/neck/shoulders/feet at gameplay scale while preserving the now-working launch/audio and ball-feed paths.
```

## 2026-06-16 — Autoplay Contact Clutter Pass

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
Gameplay autoplay after coaching suppression: /tmp/rally_visual_qa/autoplay_after_contact_clutter_184730.png
Gameplay autoplay after wall-return trail tuning: /tmp/rally_visual_qa/autoplay_after_contact_clutter_190749.png
Gameplay autoplay after live-ball return readability: /tmp/rally_visual_qa/autoplay_after_wall_return_readability_191636.png
```

Findings:

- Autoplay/debug proof frames no longer show the wall-read coaching label (`SWIPE UP`, `LEFT SIDE`, `RIGHT SIDE`), so screenshots focus on the actual gameplay state.
- Wall-mode contact halo, imprint, strike transition, return trail, return ghost, echo, and live-ball return aura now use quieter wall-specific scalars.
- Player/racket/ball readability is slightly cleaner, especially around the outgoing trail, but the broad central contact cloud remains too large for the premium gameplay target.
- Further scalar shaving is not the right next move. The next Rafa pass should replace the broad circular/rectangular wall-contact cloud with a tighter directional spark/comet effect that travels away from the avatar silhouette.

Recommended next Rafa task:

```text
Replace the broad wall-contact glow with a directional comet/spark payoff: small bright core at the ball, narrow outgoing streak toward the wall, no large circular cloud over the player head/racket.
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

## 2026-06-16 — Wall Score HUD Clamp Pass

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
Gameplay autoplay after score-HUD pass: /tmp/rally_visual_qa/autoplay_after_score_hud_154750.png
```

Findings:

- Wall-mode scores now use compact formatting for 100K+/1M+ survival runs, and the best-score label uses the same formatter.
- Minimal wall score typography clamps by formatted length and caps score punch at 1.10x, so long scores do not crowd the Dynamic Island.
- Score y ratio was nudged down slightly for safer top chrome while keeping the live score readable.
- Build passes, and the captured autoplay frame confirms the normal score HUD still reads cleanly below the Dynamic Island.
- Remaining issue: run a manual wall-rally check later to verify score, lives, streak, and best labels all stay legible with touch input.

Recommended next Rafa task:

```text
Run a manual wall-rally device/simulator check and tune the score/lives/streak layout only if touch-driven play exposes overlap; otherwise move to body mechanics or manual-run addiction feel.
```

## 2026-06-16 — Last-Life Pressure Cue Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Findings:

- Survival mode now fires a dedicated "LAST LIFE" wall banner when a miss leaves exactly one life.
- The lives pips punch to 1.34x and settle back quickly, giving the player a clear pressure beat without adding permanent HUD chrome.
- A small camera dip and horizon pulse make the near-death state feel physical while keeping the top chrome simple.
- Remaining issue: this is build-verified only. A manual simulator/device miss sequence should verify the cue timing, readability, and whether it competes with RESET or miss coaching copy.

Recommended next Rafa task:

```text
Manual-test the survival miss ladder: miss once, miss twice, confirm LAST LIFE reads cleanly, then miss again and confirm RUN OVER still owns the moment.
```

## 2026-06-16 — Lost-Life Pip Burst Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Findings:

- Each survival miss now stages a transient red lost-life pip burst at the spent pip position, so the life loss reads even before the next ball spawns.
- The effect is temporary and tied to the existing lives row, preserving the simple score/exit gameplay chrome.
- The last-life banner still fires when the remaining count reaches one, while the final miss continues into the existing RUN OVER flow.
- Remaining issue: this still needs a manual miss-ladder visual check to judge whether the lost-pip burst, LAST LIFE, RESET, and miss coaching copy compete with each other.

Recommended next Rafa task:

```text
Manual-test the survival miss ladder and decide whether miss coaching should suppress RESET/LAST LIFE copy on crowded moments.
```

## 2026-06-16 — Last-Life Copy Priority Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Regression tests:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO -only-testing:RallyTests/WallRallyEscalationTests test
Result: TEST SUCCEEDED — 9 tests, 0 failures
```

Findings:

- Misses that drop survival mode to one life now give the "LAST LIFE" warning priority over the normal RESET banner.
- Miss coaching copy is suppressed on that same last-life beat, so the pressure signal owns the screen instead of stacking three messages.
- New-best banners remain eligible on the same miss because reward beats should not be hidden by survival copy priority.
- Survival miss copy priority is now covered by pure tests, so the last-life suppression contract is less likely to drift during future gameplay tuning.
- Lost-life pip burst still fires at the spent pip to keep the life loss readable.
- Remaining issue: needs a manual miss-ladder visual check to confirm first miss, last-life miss, and run-over miss each read as separate beats.

Recommended next Rafa task:

```text
Manual-test the survival miss ladder after this build: first miss should show lost-pip feedback, second miss should clearly show LAST LIFE without RESET/coaching clutter, final miss should show RUN OVER.
```

## 2026-06-16 — Autoplay Gameplay Proof After Copy Policy

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
Gameplay autoplay after copy-policy pass: /tmp/rally_visual_qa/autoplay_after_copy_policy_181351.png
```

Findings:

- The compact top score/lives stack is readable under the Dynamic Island at score 165, and the exit button no longer collides with the main score.
- Player body, shoes, racket, and court grounding are visible in the contact frame; this is a better proof frame than the older flat/toy screenshots.
- The contact flash still blooms too large and foggy over the avatar/racket area. The payoff is exciting, but it is now the next biggest readability offender.
- `SWIPE UP` coaching copy is visible during autoplay proof, which pollutes screenshots and competes with timing text.
- The right-side "BEST 2" label reads confusingly next to a 165 score. It may be combo-best semantics, but the visual relationship needs clarification or relocation.

Recommended next Rafa task:

```text
Reduce wall-mode contact fog radius/opacity another notch and suppress gesture coaching during autoplay/debug proof frames; then re-capture a contact frame.
```

## 2026-06-18 — Muted Autoplay Feed Proof

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
Sound default: muted
```

Screenshots:

```text
Home sound-toggle proof: /tmp/rally_sound_toggle_home_015946.png
Gameplay muted autoplay proof: /tmp/rally_visual_qa/autoplay_after_sound_default_off_021347.png
```

Findings:

- Fresh autoplay proof confirms the wall-rally feed is alive: score is at 330, lives are intact, and a ball is visible traveling through the court.
- The new sound default is safe for unattended runs: fresh/default and `-RallyAutoPlay` launches start muted, with a visible speaker toggle on Home and a Sound toggle in game settings.
- The court depth and compact top chrome remain readable in the proof frame.
- Remaining issue: the broad cyan wall-return/contact glow still occupies too much space near the avatar and can make the player read toy-like. Do not keep shaving unrelated UI; replace this with a tighter directional comet/spark payoff.

Recommended next Rafa task:

```text
Replace the broad wall-return/contact glow with a narrow directional comet: small bright ball core, thin travel streak toward the wall, and no large rectangular/circular bloom over the avatar lane.
```

## 2026-06-16 — Autoplay Proof Overlay Suppression Pass

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
Baseline proof before this pass: /tmp/rally_visual_qa/autoplay_current_193418.png
After wall popup tighten: /tmp/rally_visual_qa/autoplay_after_popup_tighten_194355.png
After proof overlay suppression: /tmp/rally_visual_qa/autoplay_after_proof_overlay_suppression_200255.png
After live aura / return-pulse clamp: /tmp/rally_visual_qa/autoplay_after_contact_overlay_trim_201848.png
```

Findings:

- Autoplay/debug proof frames now suppress the wall-read training overlays (`SWIPE UP`, side coaching, anticipation bar, anticipation fill, and contact timing ring), leaving the screenshot focused on the rally state instead of tutorial chrome.
- Wall-mode contact score popup is smaller, softer, and offset higher/farther from the avatar, so `PERFECT` no longer sits directly over the player face/racket in proof frames.
- Ball proxy/live-exchange aura and return impact pulse now use smaller wall-specific scale/alpha/glow knobs.
- The player face, racket, shoes, score, lives, and exit chrome are readable in the captured proof frame.
- Remaining issue: a broad cyan/cream contact glow still exists around the wall-exchange ball. The overlay clutter was removed, but the next pass should replace that residual bloom with a true directional comet/spark effect rather than continuing to shave unrelated overlay alphas.

Recommended next Rafa task:

```text
Replace the remaining live wall-exchange bloom with a directional comet/spark: small bright ball core, narrow outbound streak toward the wall, and no large circular aura around the avatar/racket.
```

## 2026-06-16 — Wall Contact Comet Readability Pass

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
First directional comet proof: /tmp/rally_visual_qa/autoplay_after_directional_comet_204045.png
After contact stack clamp: /tmp/rally_visual_qa/autoplay_after_contact_stack_clamp_204941.png
After proxy halo cut: /tmp/rally_visual_qa/autoplay_after_proxy_halo_cut_210510.png
Final proof after wall swing-trail + tail trim: /tmp/rally_visual_qa/autoplay_after_comet_final_211058.png
```

Findings:

- Wall-mode live exchange no longer renders warning/focus rings during the contact handoff; the proxy ball keeps a bright core but drops the large translucent target-circle treatment.
- Racket-contact halo is disabled in wall mode, and the stacked racket/wall contact bursts use lower alpha, scale, and glow multipliers so the player body remains readable behind contact.
- Wall-mode swipe/swing trail now uses a much thinner/lower-alpha stroke so it reads as input direction feedback rather than a full-screen fog bar.
- The final proof frame shows a clearer bright tennis ball with a directional tail near the racket. The player face, racket, legs, shoes, score, lives, and exit button are readable.
- Remaining issue: the contact still has a broad cream/cyan glow region. Further alpha shaving has diminishing returns; the next high-value improvement is a camera/composition pass that moves contact slightly farther from the face/racket and replaces the residual blur with discrete sparks/dust particles.

Recommended next Rafa task:

```text
Gameplay camera/composition pass: lower or offset the contact lane so the ball strike point does not sit directly above the avatar face, then replace residual cream/cyan blur with 6-10 small directional sparks.
```

## 2026-06-16 — Wall Contact Composition Offset Pass

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
Contact composition proof: /tmp/rally_visual_qa/autoplay_after_contact_composition_213644.png
```

Findings:

- Wall-rally contact pockets now move outward and lower in wall mode only, so the racket-side strike point is no longer centered directly over the avatar's face.
- The same `racketContactPoint(for:)` source now drives hit selection, contact pockets, wall exchange, score burst, and contact VFX with the wall-only composition offset. This avoids per-effect drift.
- The final proof frame reads more like the ball is being met by the racket hand rather than hovering above the head.
- Remaining issue: the contact glow is still broad. The next improvement should replace the remaining soft blur with discrete directional particles/sparks rather than more global alpha reductions.

Recommended next Rafa task:

```text
Replace residual contact blur with explicit particles: 6-10 small outbound sparks/dust puffs, no large filled glow behind the ball.
```

## 2026-06-18 — Directional Sparks / Strike-Gate Quieting Pass

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
After directional sparks: /tmp/rally_visual_qa/autoplay_after_directional_sparks_025241.png
After lane aura mute: /tmp/rally_visual_qa/autoplay_after_lane_aura_mute_025943.png
After strike-gate outline + contact-pocket shift: /tmp/rally_visual_qa/autoplay_after_contact_pocket_shift_031951.png
```

Findings:

- Wall contact payoff now uses small directional tennis-dust sparks that travel away from the avatar instead of relying on one broad filled cloud.
- The side-lane aura and wall strike gate are quieted for wall rally mode; the gate now reads as a thin outline cue instead of a large glowing rounded rectangle.
- The wall contact pocket is moved farther outward and lower so the ball no longer sits directly over the avatar's face during the strike read.
- The final proof frame shows the ball readable up-court, the avatar face unobscured, and the racket/contact side clearer than the prior fog-heavy pass.
- Remaining issue: the avatar anatomy and camera are still not pro-quality; feet turn in, shoulders/head feel puppet-like, and the camera remains too flat for realistic tennis depth.

Recommended next Rafa task:

```text
Gameplay camera/anatomy pass: shift to a more realistic over-the-shoulder tennis POV and fix the grounded athletic stance so feet angle outward, shoulders read, and racket contact happens beside the body.
```

## 2026-06-18 — Opening Autoplay Contact Proof

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'platform=iOS Simulator,id=CA3029AB-A788-4370-BD71-E556B01C8FE6' CODE_SIGNING_ALLOWED=NO build
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
Failed proof before cull-boundary conversion: /tmp/rally_visual_qa/autoplay_proof_scene_flag_053559.png
Passing proof after cull-boundary conversion: /tmp/rally_visual_qa/autoplay_cull_boundary_054254.png
```

Findings:

- `-RallyAutoPlay` now reaches live scoring contact instead of ending at zero-score Game Over.
- The passing proof frame shows score `443`, multiplier `x5`, three live pips, and the ball in the racket-side contact pocket.
- The fix is scoped to proof/autoplay mode: normal wall-rally misses still run through the normal miss/cull path.
- Remaining issue: avatar/camera craft is still not premium enough; next Rafa work should focus on realistic tennis POV and anatomy, not more proof plumbing.

## 2026-06-18 — Opening Feed Grace Check

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'platform=iOS Simulator,id=CA3029AB-A788-4370-BD71-E556B01C8FE6' CODE_SIGNING_ALLOWED=NO build
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
Before patch, 5s proof landed on Game Over: /tmp/rally_visual_qa/autoplay_after_opening_feed_043457.png
After patch, 5s proof remains in gameplay with a visible ball/feed: /tmp/rally_visual_qa/autoplay_after_opening_grace_044848.png
```

Findings:

- The previous proof path reached zero-score Game Over within five seconds, matching the owner report that balls were not coming through clearly.
- The opening no-life-loss grace keeps the first visible feeds in gameplay instead of instantly ending the run.
- Remaining issue: proof mode still misses early feeds, so the next Rafa task should tune early contact generosity/autoplay timing and make the first successful hit easier to read.

## 2026-06-18 — Gameplay POV Readability Tuning

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'platform=iOS Simulator,id=CA3029AB-A788-4370-BD71-E556B01C8FE6' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Autoplay argument: -RallyAutoPlay
```

Screenshot:

```text
/tmp/rally_visual_qa/autoplay_pov_readability_060748.png
```

Findings:

- The proof frame shows active scoring (`443`, x5) with a visible ball feed and no instant zero-score Game Over.
- The gameplay player is slightly lower/smaller, leaving more visible court depth and less cramped contact space.
- Wall-rally contact is pushed farther outside the torso/face, and the ball glow is softer so it reads as a tennis ball instead of a giant bloom.
- Remaining issue: the avatar still needs a dedicated anatomy/face/feet pass. This pass intentionally avoided avatar identity files and only improved gameplay POV/readability.

## 2026-06-18 — Avatar Anatomy Readability Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'platform=iOS Simulator,id=CA3029AB-A788-4370-BD71-E556B01C8FE6' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
```

Screenshots:

```text
Home: /tmp/rally_visual_qa/home_avatar_readability_063946.png
Gameplay autoplay: /tmp/rally_visual_qa/game_avatar_readability_063957.png
```

Findings:

- Shared face geometry now has stronger minimum eye, brow, nose, and mouth sizes so the player no longer reads as faceless at gameplay scale.
- Hair fringe is lifted through the shared `RallyAvatarGeometry.hairFringeLift(scale:)` contract, keeping hair connected while clearing more of the eyes.
- Ears are slightly larger and farther out so the head/ear relationship is more legible.
- Foot toe-out constants are increased so the ready stance reads less caved-in.
- Remaining issue: the avatar still needs a deeper body/shoulder/shoe art pass; this was a focused readability repair, not a full character redesign.

## 2026-06-18 — Wall Feed Recovery Verification

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

Screenshot:

```text
/tmp/rally_visual_qa/wall_feed_verify_105707.png
```

Findings:

- The no-ball recovery patch is visually verified in this proof run: autoplay reached score `27`, all three life pips remained visible, and a live ball was present in the racket-side contact pocket.
- This specifically confirms the court did not sit empty after the stale-exchange recovery patch.
- Remaining issue: the gameplay avatar is still not premium enough. Face, shoulder, hand, shoe, and stance anatomy remain the next highest-impact craft pass after ball-feed reliability.

## 2026-06-19 — Quiet Sound Default + Autoplay Feed Proof

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Autoplay arguments: -RallyGuestMode -RallyAutoPlay
```

Screenshots:

```text
3s:  /tmp/rally_visual_qa/autoplay_3s.png
8s:  /tmp/rally_visual_qa/autoplay_8s.png
14s: /tmp/rally_visual_qa/autoplay_14s.png
```

Findings:

- Sound is already quiet by default in the current tree: `RallyDefaults.applyQuietSoundDefaultIfNeeded()` runs at app launch, `AudioPreferences` persists the user toggle, and autoplay resolves sound to off.
- Autoplay feed is alive in the fresh build: the 8s frame shows score `235` and combo `x3` with a visible ball; the 14s frame shows score `859` and combo `x9` with a visible ball.
- This means the owner's "no balls coming through" report is not a global spawn failure in the current branch. The next Rafa task should be a manual-start visual proof to see whether the human tap-through path, first-feed timing, or ball readability still feels broken.

## 2026-06-19 — Manual Launch Home Proof

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Launch arguments: -RallyGuestMode
```

Screenshot:

```text
/tmp/rally_visual_qa/manual_home_031103.png
```

Findings:

- Manual non-autoplay launch lands cleanly on the Home/Loadout screen with the sound toggle visible and muted.
- The avatar has visible eyes, brows, mouth, ears, hair, racket, and slot controls, but still reads too toy-like/muppet-like in proportions. The head/neck/shoulder/shorts/feet silhouette remains the highest-impact avatar craft gap.
- This proof does not replace the needed manual PLAY tap-through proof. The current shell tooling can screenshot the simulator but cannot tap the PLAY button directly, so the next visual QA should either be human-driven or use a simulator-control/browser mirror path.

## 2026-06-20 — Debug StartGame Gameplay Proof

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Launch arguments: -RallyGuestMode -RallyStartGame
```

Screenshot:

```text
/tmp/rally_visual_qa/startgame_161520.png
```

Findings:

- Added a DEBUG-only `-RallyStartGame` launch argument that opens `GameSessionView` without enabling autoplay, giving Rafa a repeatable non-autoplay gameplay proof path when shell tapping is unavailable.
- The proof frame lands in gameplay with visible wall-rally HUD, visible ball/feed, and readable miss coaching (`MISS` + `READ THE FEED`), so the current branch is not globally stuck on an empty court.
- The screenshot still confirms the owner-visible avatar craft problem: face/head/shoulder/leg proportions read too toy-like. The next high-impact visual patch should be avatar anatomy, not another ball-feed rescue, unless a human tap-through proves the feed fails differently from `-RallyStartGame`.

## 2026-06-22 — Avatar Gameplay Anatomy Readability Proof

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Home launch arguments: default
Gameplay launch arguments: -RallyAutoPlay
```

Screenshots:

```text
Home:     /tmp/rally_visual_qa/avatar_readability_home_125529.png
Gameplay: /tmp/rally_visual_qa/avatar_readability_game_125538.png
```

Findings:

- Home and gameplay now share the same visible identity and outfit in the proof frames: Wimbledon court, neon top, black shorts, white tennis shoes, black hair, visible eyes, ears, brows, mouth, and racket.
- The gameplay-scale face is materially more readable than the previous proof: eyes/mouth survive the camera distance, hair sits connected to the crown instead of floating, and the ears/neck are visible enough to avoid the bald-mask look.
- Shoulder and shoe silhouettes were softened after the first proof in this pass: sleeve caps are less like glowing puppet balls, and shoes are slimmer/more tennis-like with reduced inward toe rotation.
- Remaining craft gap: the figure is usable for playtesting but still stylized. A future avatar art pass should focus on torso/arm anatomy and clothing detail, not identity sync or ball-feed rescue.

## 2026-06-22 — Manual Start Zero-Hit Crash Fix

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Regression test:

```text
xcodebuild test -project Rally.xcodeproj -scheme Rally -destination 'platform=iOS Simulator,id=CA3029AB-A788-4370-BD71-E556B01C8FE6' -only-testing:RallyTests/MatchFlowTests/testDailyChallengeAccuracyTreatsZeroHitsAsZeroPercent CODE_SIGNING_ALLOWED=NO
Result: TEST SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Launch arguments: -RallyGuestMode -RallyStartGame
```

Screenshots:

```text
Pre-fix zero-hit crash fallback to iOS Home Screen: /tmp/rally_visual_qa/manual_startgame_134707_14s.png
Post-fix live ball proof:                         /tmp/rally_visual_qa/startgame_dailychallenge_fix_140457_8s.png
Post-fix zero-hit Game Over proof:                /tmp/rally_visual_qa/startgame_dailychallenge_fix_140504_14s.png
```

Findings:

- The "no balls coming through" manual-start report was reproducible as a zero-hit post-run crash, not a dead feed. The app fell back to the iOS Home Screen after `DailyChallengeMgr.updateChallenges` converted a NaN zero-hit accuracy value to `Int`.
- `DailyChallengeMgr.accuracyPercent(perfectHits:greatHits:totalHits:)` now treats zero total hits as `0%` and guards non-finite values before integer conversion.
- Post-fix proof reaches a normal Rally Game Over screen after a zero-hit opening run instead of crashing to SpringBoard, and the 8-second proof confirms the ball/feed is visible during the run.
- Remaining gameplay feel issue: the opening manual run is still too punishing and can end at zero quickly. The next Rafa pass should make first-rally onboarding more forgiving/addictive rather than chasing another spawn crash.

## 2026-06-22 — Opening Feed Cue Readability Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Regression test:

```text
xcodebuild test -project Rally.xcodeproj -scheme Rally -destination 'platform=iOS Simulator,id=CA3029AB-A788-4370-BD71-E556B01C8FE6' -only-testing:RallyTests/WallRallyEscalationTests CODE_SIGNING_ALLOWED=NO
Result: TEST SUCCEEDED — 18 tests, 0 failures
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Launch arguments: -RallyGuestMode -RallyStartGame
```

Screenshot:

```text
Opening feed cue proof: /tmp/rally_visual_qa/opening_feed_cue_213655.png
```

Findings:

- Opening wall-rally feed cues now use named tunables instead of hardcoded values in GameScene.
- The path guide stays visible through the first 6 feeds and remains available while opening progress is still early, so a rescue/replay cannot make the learning cue disappear immediately.
- Cue strength has a readable floor and an opening peak, making the first seconds feel less like an empty or broken court.
- The proof screenshot shows the live ball, path cue, avatar, and simple score HUD in the first-run gameplay frame.
- Remaining task: real-phone visual check to tune whether the guide is too loud or too quiet during the first 10 seconds.

## 2026-06-26 — Gameplay Head/Neck Anchor Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Launch arguments: -RallyAutoPlay
```

Screenshot:

```text
Gameplay proof: /tmp/rally_visual_qa/head_anchor_gameplay_193707.png
```

Findings:

- Gameplay head, hair, ears, eyes, brows, nose, and mouth now share the layout head anchor instead of the previous gameplay-only `+2 * bodyScale` lift.
- This removes a small but compounding head/neck offset that made the face stack read more puppet-like in motion.
- The proof frame reaches live scoring (`335`, `x4`, `PERFECT`) after the change, so wall-rally autoplay still runs.
- Remaining visible issue: at exact contact, the ball/glow can still cover the face. Next Rafa pass should move/scale contact payoff away from the avatar face or fade it behind the racket/head stack.

## 2026-06-27 — Rafa Contact Glow Face-Clear Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Launch arguments: -RallyAutoPlay
```

Screenshot:

```text
Gameplay proof: /tmp/rally_visual_qa/contact_glow_face_clear_031152.png
```

Findings:

- Wall-rally contact payoff still fires on a live PERFECT frame with score/combo visible (`335`, `x4`, `PERFECT`).
- The large yellow-white wall strike burst now blooms outward/down from the ball and behind the player layer, instead of covering the avatar's eyes/mouth at contact.
- The racket-side contact remains readable because the ball/racket are still at the true contact point while the decorative flash is protected from the face stack.
- Remaining task: tune the avatar anatomy itself (head/face/hair/feet/shoulders) separately; this pass only fixed contact-effect occlusion.

## 2026-06-27 — Avatar Anatomy Readability Pass

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Home launch + -RallyAutoPlay gameplay launch
```

Screenshots:

```text
Home proof: /tmp/rally_visual_qa/avatar_anatomy_home_061824.png
Gameplay proof: /tmp/rally_visual_qa/avatar_anatomy_game_061832.png
```

Findings:

- Home avatar no longer reads as bald or faceless: hair stays attached to the head, eyes and mouth are visible, ears have inner definition, and shoulders connect more cleanly into the torso.
- Gameplay avatar carries the same shared head/face/hair geometry; live proof frame reaches scoring contact (`335`, `x4`, `PERFECT`) after the change.
- Tennis shoes now include toe-cap strokes in both renderers, which helps them read less like flat dress shoes or blocks.
- Remaining task: contact animation poses can still look awkward during swing follow-through; handle that separately as a motion/pose pass, not another static head-geometry pass.

## 2026-06-27 — Wall-Rally Feed Liveness Verification

Build:

```text
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
Result: BUILD SUCCEEDED
```

Simulator:

```text
iPhone 16 Pro, iOS 18.6
Bundle: com.marcelozap.rally
Launch arguments: -RallyAutoPlay
```

Screenshots:

```text
10-second proof: /tmp/rally_visual_qa/feed_verify_1301_10s.png
22-second proof: /tmp/rally_visual_qa/feed_verify_1301_22s.png
```

Findings:

- The current fresh build does not reproduce the empty-court/no-ball complaint under autoplay.
- At 10 seconds, the rally is live with score `543`, combo `x6`, and an active contact cue.
- At 22 seconds, the rally is still live with score `3139`, combo `x18`, and a ball/contact payoff visible near the player.
- Existing wall-feed watchdogs are active and covered by tests; do not add another rescue layer unless a new screenshot shows an actual stuck feed on this build.
- Remaining visible task: the swing/contact pose still reads puppet-like during contact. Next Rafa work should target body mechanics and racket/arm pose, not spawn lifecycle.
