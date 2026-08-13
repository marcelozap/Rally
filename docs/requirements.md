# Rally Requirements

## Mission

Make sports practice more useful and accessible by combining training memory, activity data, and free coaching feedback from video recorded on a normal phone.

## Primary Users

- Players who cannot afford regular coaching
- Beginners who need simple, non-judgmental feedback
- Recreational players trying to improve one stroke at a time
- Families, siblings, and friends practicing together
- Multi-sport athletes who want one place for practice logs, matches, recovery notes, and progress review

## First Use Case

Serve analysis from a phone camera.

The serve is a good first target because:

- It is repetitive and easy to record as a single-player motion.
- It has recognizable checkpoints: stance, toss, loading, contact, follow-through, landing.
- Feedback can be useful even without knowing exact ball speed or spin.

## Core Flow

1. Player opens the daily practice loop.
2. Player logs a session, match, recovery note, activity, or video clip.
3. For coaching clips, the app shows simple recording guidance.
4. Player records or uploads a short clip using a phone camera.
5. App detects key body positions and timing.
6. App returns 1-3 clear coaching notes.
7. App suggests one drill or cue for the next attempt.
8. The result becomes part of practice memory so progress can be reviewed later.

## MVP Requirements

- Works with a normal phone camera.
- Supports uploaded or freshly recorded video.
- Starts with serve analysis.
- Connects coaching feedback to training logs and practice history.
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
- Daily practice loop
- Practice memory across logs, matches, recovery notes, activity data, and coaching clips
- Wearable/activity import direction for Garmin-style training history
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
- Should coaching clips attach to existing training logs, or create a new kind of practice entry?
- Should Garmin/activity data stay as later context, or influence coaching recommendations early?
- Should match analytics be a separate mode from coaching feedback?
- Can we use single-camera court geometry to make feedback more tactical without making the MVP too complex?
- Should Rally eventually support two-phone recording for families who want more accurate 3D technique feedback?
