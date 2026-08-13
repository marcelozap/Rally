# Free Coaching Track

## Purpose

This track is for Rally's free tennis coaching assistant: phone-camera video analysis that helps players who cannot pay for a coach.

The iPhone game remains the main Rally app effort. Coaching work should stay modular until we know whether it becomes:

- a separate mode inside the Rally app,
- a companion app,
- a web prototype,
- or a backend/computer-vision service that the app can call later.

For repeatable source capture, use `docs/post-intake-system.md` and `docs/templates/source-post.md`.

For the coaching/practice architecture, use `docs/coaching-architecture.md`.

## Current Split

- MacBook: active Rally game development and App Store path.
- This PC: free coaching research, requirements, and computer-vision prototypes.

## Product Frame

Rally should be treated as a practice system first:

- daily practice loop
- training logs
- match history
- recovery notes
- activity data
- improvement markers
- optional video coaching

The coach should not become a separate disconnected tool. It should feed the same practice memory: what the player worked on, what changed, what to try next, and what patterns are showing up over time.

## First Coaching Prototype

Start with a local prototype before changing the production iOS app:

1. Load a webcam feed or recorded serve video.
2. Run pose estimation.
3. Draw a skeleton overlay.
4. Show FPS and landmark confidence.
5. Detect broad serve phases.
6. Return one priority coaching cue with visible evidence.

## Local Video Workflow

Put phone videos in:

```text
data/raw-videos/
```

Write annotated outputs and diagnostics to:

```text
data/processed-videos/
```

Both folders are ignored by Git except for `.gitkeep` placeholders. This keeps personal practice clips off GitHub.

## Keep Separate For Now

Avoid mixing experimental coaching code into the production game until:

- the prototype can analyze at least one serve clip end to end,
- the feedback is useful and explainable,
- privacy and storage expectations are clear,
- and the runtime path is chosen: on-device, local desktop, web, or cloud.
