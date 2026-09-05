# Mirror Rally — 20-second prototype

Mirror Rally is a short rally against the player's double. Both ends use the same selected appearance, anatomical model, and outfit through the shared avatar rig. The far player is visible on court and moves to return the ball.

## Current loop

- Swipe anywhere on the court to swing. The incoming ball selects forehand or backhand automatically; horizontal swipe direction still controls shot aim.
- The near player begins crossing toward the expected opposite-side reply during the outbound flight. Movement follows the planned contact point, not the ball's changing screen position.
- Actual court travel drives lead-foot and trailing-foot steps. Supporting shoes hold court anchors, moving knees flex, and the feet settle when travel stops. Studio previews retain their planted stance.
- Near and far contact points come from the projected racket positions. The far player's timed approach remains speed-limited, including late arrivals; contact planning must stay within that reachable range.
- A finite 20-second clock ends the run. Three lives allow mistakes; losing all lives ends it early. New incoming exchanges cannot schedule contact beyond the run's deadline.
- The compact result shows score, best streak, and timing accuracy, with **Play Again** and **Home** actions.

The pulse changes at four-shot combo boundaries:

| Successful-shot combo | Half-exchange pulse target |
|---|---|
| 0–3 | 0.76 seconds |
| 4–7 | 0.70 seconds |
| 8+ | 0.64 seconds |

## Implementation

`RallyMirrorRules` owns the timer, pulse tiers, and deadline checks. `GameScene` coordinates the double, anticipated movement, projected contact, and continuous exchanges. `RallyCourtMovement` limits court travel and timed arrival; `RallyAvatarFootwork` and `RallyAvatarRig` animate the shared body and clothes. `RallyFlickInput` preserves horizontal aim, while the play-session and result views provide the short-run interface.

## Verification

The full simulator suite passed all **176 tests**. After the final near-contact pose and completed-clock fixes, **15 focused scene/rig tests** passed again. The generic iOS Simulator Debug build also passed.

The scene tests advance the actual game clock through a 20-second autoplay run, verify one completion event and complete ball cleanup, retain the opening ball through its contact grace period, and check fresh retry state. Other checks cover movement speed, planned arrival, reversal, stopping, pulse/deadline rules, gesture validation, skipped far-contact frames, and delayed normalization without a new timing window. Native SceneKit renders cover near/far male and female foot lift, planted contact, and settling, with fixed body and garment geometry.

Evidence is saved locally at `/Users/a14/Documents/ChatGPT/Rally/Proof/mirror-rally/index.html`, alongside four animation GIFs, foot-position CSV files, and build/test logs. These checks establish mechanical behavior; they do not establish whether the game feels fun.

Live UI and manual playtesting are blocked while the Mac is locked. No human playtest or enjoyment validation is claimed.

Next validation is a real-device run: finger-release timing and swipe-anywhere reliability, haptic/contact synchronization, readability of the approaching ball and far player, forehand/backhand clarity, the 20-second finish, and immediate replay. Judge cadence, responsiveness, and replay appeal through actual play before calling the prototype ready for release.
