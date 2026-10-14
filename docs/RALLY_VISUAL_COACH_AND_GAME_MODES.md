# Rally: visual coaching and serve-first game modes

Status: owner-requested product plan and laptop implementation handoff. This document does not implement or verify these features.

## What the player needs

The owner's feedback: the Coach felt like a strange chart with confusing axes. A child should be able to see "I move like this; try moving like that" without interpreting a graph or reading a long explanation.

The main loop is: **watch yourself, watch the example, try again.** Measurements support the experience behind the scenes. The default Coach screen must teach through motion.

## Visual Coach

1. Show "Your movement": the player's selected clip with a simple, accurate body outline. Provide play/pause, slow motion and replay.
2. Show "Try this": a short animated demonstration beside the clip, or a clearly labeled toggle on narrow screens. Offer a boy or girl demonstrator using the existing character system where suitable. Keep teaching quality equal across characters.
3. Match the example's camera angle and selected hitting hand to the player where possible. Label any mirrored view; never silently swap anatomical left/right.
4. Highlight one relevant body part and show one short cue. For example, "Bend your knees a little more" is sample wording, not a rule to issue to every player. Personalized corrections require reliable observations and an appropriate reviewed reference.
5. Loop the relevant portion of both movements. Synchronize using a supported motion phase or a player-selected start point; do not invent ball-contact timestamps.
6. End with a prominent "Try again" action to record or select another attempt. Make the camera flow optional; preserve Photos import.

Keep charts out of the primary learning flow. Existing diagnostic measurements can remain under an optional details view. Provide short captions, optional spoken cues with mute, controls accessible to VoiceOver, and highlights distinguishable without color alone. Avoid flashing and support reduced motion for decorative effects while leaving instructional playback under player control.

If tracking or viewpoint cannot support a correction, say "Let's get a clearer video" and visually demonstrate framing. If only a general demonstration is available, label it "Practice example" instead of implying that the player made a detected mistake. A 2D joint range by itself does not establish ideal tennis technique.

## Serve-first Rally gameplay

Every new point in the current Rally game starts with a visible serve, followed by the rally. Preserve the current controls and game feel wherever possible.

- Present a brief ready state and a simple visual serving cue.
- Animate the server preparing, tossing and contacting the ball. Start the ball at the racket contact location with a coherent outgoing path.
- A successful serve transitions into normal rally play. Avoid an unrelated automatic ball feed or duplicate ball spawning during the serve.
- A failed serve produces a clear, friendly retry. Introduce formal first/second serves only in a mode that explicitly uses tennis scoring.
- On the next point or restart, return through the serve state. Recover correctly from pause, backgrounding and interruption.
- For the timed Rally Challenge, start the challenge timer at successful serve contact so the setup animation does not consume play time. This is a proposed default to playtest.

Suggested lifecycle: ready -> serve preparation -> toss -> contact -> rally -> point end -> ready. Integrate with the existing game lifecycle rather than creating a competing spawn/timer system.

## Proposed modes

| Mode | What the player does | Visual feedback |
| --- | --- | --- |
| Serve Practice | Watch a short serve example, then serve toward a target | Show ball path, target hit and immediate retry |
| Rally Challenge | Begin with a serve and keep the rally going | Count successful returns with a clear, encouraging cue |
| Copy the Coach | Watch one animated body movement and try it | Highlight one body part; replay the example alongside the attempt |
| Target Practice | Aim shots into highlighted court areas | Show where the shot landed and the next target |

These are proposed additions, not claims that all four modes already exist. Copy the Coach can begin as demonstration plus video replay; live camera scoring is a separate future capability. Gameplay target hits must not be confused with real-world video-derived technique accuracy.

## Implementation order

1. Inspect the latest phone-building checkout and existing Coach changes. GitHub contains `codex/rally-coach-device` and `codex/rally-coach-kinematics`; determine what is already integrated before changing anything.
2. Deliver one visual Coach lesson end to end: player replay, matching demonstration, one supported cue or clearly labeled general practice example, and retry. Start with a slow, clearly visible movement rather than a full-speed serve assessment.
3. Add the serve lifecycle to the existing Rally mode and verify transitions, scoring and retries.
4. Extend that foundation into Serve Practice and Target Practice. Add Copy the Coach once the comparison flow is usable. Reuse the existing Rally challenge rather than duplicating it.
5. Test on the actual iPhone. Let observed comprehension and gameplay determine the next iteration; do not treat a passing build as proof that the lesson is clear.

## Acceptance checks

- A first-time player can identify their clip, the example, the highlighted movement and the retry control without reading an explanatory paragraph or interpreting axes. Observe a beginner trying it; record confusion rather than assuming comprehension.
- Portrait and landscape clips, left/right hand selection and mirrored views produce understandable comparisons.
- Missing joints and tracking gaps never produce fabricated corrective advice or a jumping body outline. Comparison playback works even when analysis cannot supply a personalized cue.
- The default Coach experience is visual; no chart is required to learn what to try.
- A new game and each new point visibly begin with a serve. Successful serves, misses, restart, pause/resume and background recovery leave one valid ball lifecycle and correct score/timer state.
- Mode instructions can be conveyed by a brief demonstration and a short phrase. Game controls remain usable on the smallest supported screen.
- Existing avatar identity, outfits, Journal, saved reports, purchases, audio preferences and sync behavior remain intact. Keep the existing bundle identifier and signing when installing in place.
- Run focused lifecycle/analysis tests, the relevant existing suite and a full iOS build. Capture short device recordings of the Coach comparison and a complete serve-to-rally-to-next-point cycle. Report tests, device observations and remaining limitations separately.

## Prompt for the laptop

Implement the direction in this document in my latest Rally checkout that built the app on my iPhone. Preserve my local tweaks and verify which Coach/device/kinematics changes are already present. Read repository instructions and active locks, create an isolated feature branch, and work in the order above. The priority is a visual learning experience a child can understand, replacing the chart as the main Coach interaction, plus points that start with a serve. Build a usable first lesson and serve lifecycle before broadening to the proposed modes. Keep demonstrations distinct from validated personalized corrections. Run the Mac/iPhone checks, show actual screen recordings, and push a draft PR with an honest account of what is implemented and what remains. Do not reset my checkout, uninstall the phone app, or overwrite signing, saved data or unrelated work.
