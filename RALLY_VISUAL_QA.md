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
