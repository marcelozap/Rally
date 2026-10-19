# Vela Tennis swipe gameplay — October 18–19, 2026

Candidate branch: `codex/vela-swipe-gameplay`, continuing the October 15 visual polish at `7eb4f48`.

## Player behavior

- Swipe upward on either side of the screen to return the incoming ball. The incoming ball determines forehand/backhand; the swipe's horizontal direction now selects either side of the far court. A vertical swipe aims through the middle.
- Faster swipes shorten the outgoing flight. At the opening tempo, accepted soft-to-hard shots range from approximately 0.91 to 0.61 seconds; later hard shots have a 0.54-second floor. The double's return keeps the existing 0.76/0.70/0.64-second phrase timing. Timing grades remain based on release timing.
- A small court ellipse shows intended placement while swiping. Its bar and color communicate power. Preview and actual flight use the same projected racket contact plan. The cue clears on cancelled gestures, pause, appearance/hand changes and session completion.
- The double uses bounded approach steps with enough court-relative speed for wider shots on phone and tablet. Cached contact geometry is refreshed after avatar/hand changes and retried when the renderer becomes available.
- The app display name and remaining Home/loading labels use Vela Tennis. Source targets, bundle ID and persistence keys retain their existing identities.

The reference mechanic is described in Tennis Clash's official [shot controls](https://tennisclash.zendesk.com/hc/en-gb/articles/12709842502929-How-do-I-hit-the-ball-with-different-intensities-and-styles). This pass implements direction and pace in Vela's existing 20-second Mirror Rally; it does not add competitive scoring, tap-to-move, opponent AI, shot-depth selection or multiplayer.

## Verification

Final verification: **77 focused native tests passed, zero failures** in `VerifiedGameplayTests.xcresult`. The generic iOS Simulator Debug build passed for arm64 and x86_64 (`verified-build.log`).

Evidence lives at `/Users/a14/Documents/ChatGPT/Rally/Proof/2026-10-18/`.

Focused checks cover measured input, mirrored/scaled direction, power bounds, real scene flight times, projected racket contact for both hands at 30/60 Hz, 10 alternating hard tablet shots through the highest tempo tier, single-ball ownership, cue cleanup, pause/restart, 20-second completion, serve/practice lifecycle and shared lesson rig integration.

Native tests exclude `CoachVideoAnalyzerTests.swift`, which has a previously documented unrelated compiler type-check timeout. These focused checks are not a claim that the entire repository suite passed.

`SKView.texture(from:)` initializes the projection for geometry assertions, but its exported offscreen images invert some node textures on this simulator. Those exploratory screenshots are not visual acceptance evidence; use native simulator captures. The exploratory render-only test was removed.

The native simulator demonstration completed the full 20 seconds with a 14-shot streak, 3,020 points and 100% timing accuracy under automated input. `vela-live-swipe.png` shows the live gold placement/power cue; `vela-swipe-demo.mp4` records the run.

For a native Debug demonstration, launch the installed simulator app with `-RallyAutoPlay -VelaSwipeDemo`. The second flag alternates measured soft/hard diagonal flicks through the regular swipe resolver and shows the real aiming cue. It is compiled out of Release. This is automated input, not human phone acceptance.

## Before release

Play on a physical iPhone and iPad to judge thumb timing, cue legibility, frame pacing and replay appeal. The existing submitted build has not been replaced; this branch is a candidate for the next release.

## Checkout continuity

The current source is `/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally`, remote `https://github.com/marcelozap/Rally.git`. Boot/guard instructions and both status scripts now point at the previously approved relocated checkout, with `codex/vela-*` accepted for next-release work.
