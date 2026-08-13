# Rally Requirements

## Mission

Make tennis coaching more accessible by giving players useful, free feedback from video recorded on a normal phone.

## Primary Users

- Players who cannot afford regular coaching
- Beginners who need simple, non-judgmental feedback
- Recreational players trying to improve one stroke at a time
- Families, siblings, and friends practicing together

## First Use Case

Serve analysis from a phone camera.

The serve is a good first target because:

- It is repetitive and easy to record as a single-player motion.
- It has recognizable checkpoints: stance, toss, loading, contact, follow-through, landing.
- Feedback can be useful even without knowing exact ball speed or spin.

## Core Flow

1. Player chooses a stroke, starting with serve.
2. App shows simple recording guidance.
3. Player records a short clip using a phone camera.
4. App detects key body positions and timing.
5. App returns 1-3 clear coaching notes.
6. App suggests one drill or cue for the next attempt.
7. Player can compare the next attempt with the previous one.

## MVP Requirements

- Works with a normal phone camera.
- Supports uploaded or freshly recorded video.
- Starts with serve analysis.
- Gives plain-language feedback rather than expert jargon.
- Prioritizes safety and injury-risk cues.
- Keeps feedback short enough to use on court.
- Lets two family members use it without a paid coach.

## Feedback Principles

- Be specific: "Your toss is drifting behind your head" is better than "Improve your toss."
- Be kind: feedback should feel like a coach helping, not a grade.
- Be limited: show the most important fix first.
- Be visual when possible: mark body position, contact point, or timing on the video.
- Be honest about confidence: if the video angle is poor, say that instead of guessing.
- Be explainable: show the pose, timing, or rule that caused the feedback when possible.

## Early Feature Ideas

- Serve checklist
- Side-by-side comparison
- Slow-motion playback
- Pose overlay
- Contact-point estimate
- Toss consistency tracker
- Progress history
- Shared family account or local profiles
- Free practice plans
- Coach-style audio summary
- Explainable event timeline for each practice clip
- Match shot maps from a single camera
- Return-depth trends over a match
- Point-breakdown moments where positioning or shot selection changed the rally
- Optional two-camera technique analysis for more accurate joint angles

## Open Questions

- Should the first prototype be a web app, mobile app, or local experiment?
- Should videos be processed on device, in the cloud, or both?
- What phones should we support first?
- Should the app require a court, or work in a driveway/backyard setup?
- Should the first version save videos, or delete them after analysis for privacy?
- Do we want this to be fully free forever, or free for players with optional paid services later?
- Should match analytics be a separate mode from coaching feedback?
- Can we use single-camera court geometry to make feedback more tactical without making the MVP too complex?
- Should Rally eventually support two-phone recording for families who want more accurate 3D technique feedback?
