# Post And Journal Intake System

## Purpose

Use this system every time Marcelo sends a new post, journal entry, link, idea, or reference for Rally's free coaching track.

The goal is to make the workload easier: each new source should be captured once, routed to the right docs, and turned into concrete next steps without rethinking the process.

## Default Intake Steps

1. Read the full user-provided post, link, or journal entry.
2. Identify the source type:
   - external code repo
   - LinkedIn/social post
   - product idea
   - technical architecture idea
   - coaching insight
   - UI/design request
   - raw testing observation
3. Add the source to `docs/source-references.md` if it teaches Rally something reusable.
4. Update `docs/requirements.md` if the source changes what the product should do.
5. Update `docs/camera-feasibility.md` if the source changes what phone cameras, webcams, or two-camera setups can do.
6. Update `docs/backlog.md` with concrete tasks, not vague inspiration.
7. If the source implies an implementation path, update or add prototype notes under `prototypes/free-coaching/`.
8. If the source affects the product split, update `docs/free-coaching-track.md`.
9. Keep personal videos and test outputs local only under `data/`.
10. Commit and push the updated docs/code when the user asks to upload to GitHub.

## Routing Rules

- `docs/source-references.md`: what the source is, why it matters, useful ideas, possible Rally adaptation, risks.
- `docs/requirements.md`: user needs, MVP behavior, feedback principles, open product questions.
- `docs/camera-feasibility.md`: what one phone, one webcam, broadcast footage, or two phones can realistically support.
- `docs/backlog.md`: short actionable tasks grouped by now, next, later, and research questions.
- `docs/free-coaching-track.md`: how the free coaching lane stays separate from the Rally iPhone game.
- `prototypes/free-coaching/README.md`: exact commands and local prototype workflow.

## Source Note Format

Use this structure when adding a new source to `docs/source-references.md`:

```md
## Source Name

URL: source URL or "User-provided post, no public URL supplied."

Status: External reference / Conceptual reference / Candidate code reference / Verified code reference.

### What It Describes

Short summary in plain language.

### Useful Ideas For Rally

- Idea 1
- Idea 2
- Idea 3

### Possible Rally Adaptation

- What to borrow now
- What to save for later
- What not to copy

### Notes

Risks, privacy concerns, verification gaps, or reasons to keep this separate from the MVP.
```

## Current Product Split

- Rally game: SwiftUI/SpriteKit iPhone game, App Store path, mostly MacBook work.
- Free coaching: phone-camera analysis, pose detection, explainable coaching, local prototypes, this PC.

## Current Free Coaching Direction

Start with uploaded phone videos, not a webcam purchase.

First prototype:

1. Copy phone video to `data/raw-videos/`.
2. Run `prototypes/free-coaching/pose_overlay.py`.
3. Save annotated output to `data/processed-videos/`.
4. Review pose visibility, detection rate, and FPS.
5. Convert reliable landmarks into simple serve-phase events.
6. Generate one clear coaching cue with visible evidence.

## Privacy Rule

Do not commit raw personal videos or processed practice clips. Keep them in ignored `data/` folders unless Marcelo explicitly says a clip is safe to publish.

