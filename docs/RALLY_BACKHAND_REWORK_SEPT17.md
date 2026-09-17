# Backhand modeling revision — September 17

The owner rejected the backhand in build2026091703. Its hands were attached to the handle, but its upright racket and high wrist path produced a cramped chest-level pose. Passing attachment tests did not establish visual quality.

## What changed

- The stroke now has separate preparation, racket drop, forward contact, extension, shoulder wrap and recovery phases. The racket turns sideways at contact rather than remaining upright in front of the face. Both hands follow that same racket, mirrored for left-handed play.
- Contact moved from a high wrist target to a lower forward target; gameplay recalibrates from the actual projected racket head. The existing forehand contact is preserved.
- The hips and rib cage make a coordinated unit turn, with shoulder-girdle movement before arm IK. Feet pivot while their ankle anchors remain planted. The head continues tracking the court.
- The palm orientation follows the racket frame. This removes a wrist flip caused by projecting a fixed world vector as the racket crossed it.
- The authored tee's covered-body mask prevents skin from appearing through its shoulder and sleeve. A small local garment clearance adjustment preserves the outer silhouette. Switching to a tank restores exposed skin; polo/tank/product meshes do not receive the tee mask. Details and source licensing are in `RALLY_GARMENT_OCCLUSION.md`.
- During an incoming ball, the near player now prepares and drives toward contact. The visual phase remains below contact until the actual hit; scoring and timing still depend on input. Preparation cannot move the grading target. Misses settle before the next serve. The far player's existing contact timing is retained.

The broad motion sequence follows the [LTA's backhand fundamentals](https://www.lta.org.uk/advantage-home/content/backhands-essential-steps-when-getting-started/) and [USTA's two-handed backhand guidance](https://www.usta.com/en/home/improve/tips-and-instruction/national/improve-your-tennis-game--the-driving-force-in-your-two-handed-b.html). Animation coordinates are authored for this rig, not measured technique targets or motion capture.

## Verification

- Final native suite: **306 executed, 305 passed, one fixture skip, zero failures**. Two pre-existing simulator Vision-model-dependent exclusions remain: `CoachVideoAnalyzerTests/testBlankRotatedVideoRunsWithoutInventingMovement` and `CoachVideoAnalyzerTests/testCancellationDuringAnalysisAllowsAnotherClip`. The skipped external-fixture test is `testRealTennisClipsWhenProvided`.
- Generic iOS Simulator Debug and signed generic iPhone Debug builds passed. Signed build is **0.1.0 (2026091704)**.
- Render evidence includes all six athletes and both hands: seven-phase full-body/front and unchanged gameplay-camera PNGs, plus 31-frame GIFs. The GIFs intentionally run slowly for inspection; they are not recordings of live gameplay timing.
- Regression checks cover actual chest/shoulder turn, a lowered contact head, racket drop/string-face direction, continuous wrists/racket, supporting palm attachment, mirrored handedness, planted feet, ready/serve recovery, tee exposure restoration, and live scene preparation/contact/miss/pause behavior.
- Final native iPhone 16 simulator autoplay recordings were captured separately from pose renders. Both right- and left-handed runs completed Clean Eight with a 14-shot streak; full recordings, result screenshots and sampled gameplay frames are saved. Physical-phone play, tactile feedback and owner visual acceptance remain **VERIFY**; the Mac is locked, so an interactive UI walkthrough has not been performed for this revision.

Proof: `/Users/a14/Documents/ChatGPT/Rally/Proof/backhand-rework-2026-09-17`. Final result bundle: `BackhandReleaseTests.xcresult`; pose evidence: `final-renders/`; full-suite log: `release-tests.log`.

## Handoff

- Path: `/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally`, the owner-authorized relocated checkout.
- Branch: `codex/rally-gameplay-feel-sept17`. Last commit is the commit containing this note; the exact hash is recorded in the installation packet manifest.
- Dirty files: none intended after committing. No unrelated work was present at the start.
- Intentionally untouched: Shop/World/Clean Eight features, app identity, server/auth/sync and physical-phone data. Earlier build packets remain preserved.
- New packet: `/Users/a14/Documents/ChatGPT/Rally/Tonight/2026-09-17-backhand-rework`. Installer check-only passed for the expected identity/team/build, strict deep code signature, unexpired profile and both known phones. No physical-device commands were run.
- Signing expires September 24, 2026 at 10:57:29 a.m. EDT (`2026-09-24T14:57:29Z`).
- Next acceptance: review the actual motion, install in place on each known phone, try both handedness settings, check timing/contact/retry, verify saved gear/history, and reopen after disconnecting. This remains an authored real-time rig; exact branded clothing replicas and motion capture are outside this revision.
