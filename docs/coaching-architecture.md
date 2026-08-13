# Coaching Architecture

## Product Direction

Rally's free coach should extend the practice system, not sit beside it.

The app already points toward:

- daily practice loops
- training logs
- match history
- recovery notes
- activity data
- progress review
- local-first iOS storage
- optional account sync

The coach adds video understanding to that loop.

## Current Stack Recommendation

Use a staged architecture:

1. Prototype computer vision locally on this PC.
2. Store raw personal videos only in ignored local folders.
3. Convert video analysis into structured coaching events.
4. Map those events into the existing Rally practice-memory model.
5. Only then decide whether the production path is on-device iOS, web, backend, or hybrid.

## Stack Layers

### iOS App

- SwiftUI: practice UI, logs, review screens, coaching summaries.
- SwiftData: local-first storage for sessions, notes, coaching results, and progress.
- SpriteKit: keep for the game experience; do not force coaching video UI into SpriteKit.
- Activity data: later import layer for workout history and recovery context.

### Local Prototype

- Python: fastest way to test computer vision without touching the App Store build.
- OpenCV: video loading, frame processing, overlays, output files.
- MediaPipe: first pose landmark baseline.
- JSON summaries: bridge between raw CV experiments and future app data models.

### Backend / Sync

- Node.js: optional account sync and future analysis jobs if cloud processing becomes necessary.
- Keep raw video uploads optional because privacy and cost matter.
- Sync structured results before syncing large media.

### Wearable / Activity Direction

- Garmin-style activity history can provide context for workload, recovery, and practice trends.
- Do not make wearable data required.
- Start with manual notes and local logs; add activity imports later.

## Core Data Objects

- PracticeSession: date, sport, focus, duration, intensity, notes.
- CoachingClip: local file reference, angle, stroke, privacy state.
- PoseAnalysis: frame count, detection rate, landmark visibility, confidence.
- CoachingEvent: timestamp, phase, evidence, confidence.
- CoachingCue: priority, plain-language cue, drill, safety note.
- RecoveryNote: sleep, soreness, energy, injury concerns.
- ActivitySummary: optional wearable/imported workload context.

## Why This Stack Fits

- Phone video keeps access free.
- Local-first storage protects personal practice history.
- Python prototypes reduce early engineering friction.
- Structured JSON results make it easier to migrate from prototype to iOS or backend.
- Node sync is useful later, but not required for the first useful coaching loop.

## Near-Term Build Order

1. Run pose overlay on a real phone serve clip.
2. Save pose diagnostics as JSON.
3. Add simple serve-phase events.
4. Generate one coaching cue from those events.
5. Create a sample practice log entry that references the analysis.
6. Decide whether the next UI should be iOS-native or a local/web review tool.

