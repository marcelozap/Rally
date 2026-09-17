# Thigh and shorts transition — September 17

During the requested repeat final test, the owner reported that the exposed thighs below the shorts looked awkward while the lower legs looked normal. Build2026091705 had passed another full suite (308 executed, 307 passed, one fixture skip, zero failures), and its packaged hashes/signature were reverified. This was a visual acceptance issue despite passing tests.

## Correction

The generic shorts use a clipped garment helper which already clears the body. Adding another18mm at their openings produced excessive flare: about190mm opening width over a144mm male thigh, and197mm over a151mm female thigh in the bind pose. Added clearance now tapers from10mm at the hem to18mm higher in the seat, retaining the existing6mm waistband fit. Vertical inflation eases to zero at the clipped hem so differing downward normals cannot distort its edge.

The Home/Shop studio stance is more upright: pelvis drop changed from46±5mm to20±3mm, additional foot spread from45mm to35mm per side, and the knee bend direction follows the feet more closely. The continuous idle sway remains. Numerical reach analysis across all six presets leaves at least4.86mm margin before the existing IK reach clamp; native planted-foot tests also pass.

Body vertices, skin weights, textures and limb lengths are unchanged. Court stance, footwork and the owner-approved backhand motion are unchanged. The revised shorts fit is shared by previews and court players; authored/product-specific garment meshes retain their own fit.

## Verification and limits

- Final full native suite: **309 executed, 308 passed, one fixture skip, zero failures**. The new visual diagnostic renders studio/court-ready legs for maleAsian and femaleAsian from front, three-quarter and rear cameras, and saves joint coordinates.
- The fixture skip is `CoachVideoAnalyzerTests/testRealTennisClipsWhenProvided`. The two existing simulator Vision exclusions remain `testBlankRotatedVideoRunsWithoutInventingMovement` and `testCancellationDuringAnalysisAllowsAnotherClip` in that class.
- Focused character, feet, equipment and rendering suite:30tests passed. The new stance has native all-six-athlete full-body previews,12leg close-ups and both-hand backhand motion evidence. Before/after court-ready joint-coordinate reports match exactly for both inspected body models.
- Generic iOS Simulator and signed iPhone Debug **0.1.0 (2026091706)** builds passed. The packaged app passes strict deep signature, identity/build/team, profile and both-phone checks; all67 packaged file hashes match the build output. Signing expires September24 at10:57:29a.m.EDT (`2026-09-24T14:57:29Z`).
- Final native left-handed Clean Eight autoplay completed the full20seconds:3,020points,14-shot streak,100% automated timing. Video, sampled frames and result screenshot are saved. This does not establish physical-phone input timing.
- An initial single-method diagnostic filter executed zero tests; it is retained as `ThighBefore.xcresult` and is not verification evidence. The actual baseline is `ThighBeforeClass.xcresult`, which executed3render tests. `ThighAfter.xcresult` is the cuff-only intermediate; `ThighStance.xcresult` and `ThighReleaseTests.xcresult` cover the final correction.
- During the earlier live walkthrough, the result accessibility tree correctly omitted underlying court controls; Choose a mode, Close, Shop and the Tops filter responded. The Mac relocked before completing product scrolling/photos/detail taps, World links and hand-picker checks. Those remain VERIFY, together with owner acceptance of the thigh correction and physical-phone feel/performance/data retention.

Proof: `/Users/a14/Documents/ChatGPT/Rally/Proof/thigh-polish-2026-09-17`; baseline renders in `before-closeups`, final close-ups/roster/motion in `stance-renders`, final suite in `ThighReleaseTests.xcresult`. Repeat-build1705 evidence is preserved in the sibling `final-retest-2026-09-17` folder.

## Handoff

Source is the owner-authorized relocated checkout at `/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally`, branch `codex/rally-gameplay-feel-sept17`. The exact commit and hashes are in the installation manifest. Latest packet is `/Users/a14/Documents/ChatGPT/Rally/Tonight/2026-09-17-thigh-polish`; `Tonight/START-HERE.md` points to it after final checks.

Neither physical phone was changed. Install in place tonight and check each phone's saved avatar, gear, playing hand and history; then test the complete rally, Shop/World links and reopen after disconnecting. Prior packets are preserved. This revision improves fit and pose; it does not claim motion capture or a newly sculpted anatomical mesh.
