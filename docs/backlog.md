# Rally Backlog

## Now

- Gather user stories from real practice sessions.
- Use `docs/post-intake-system.md` whenever a new source post or journal entry arrives.
- Decide prototype target: web app, mobile app, or local demo.
- Collect example serve videos from different angles.
- Research pose estimation options for browser/mobile.
- Define first serve-analysis checklist.
- Build a tiny OpenCV plus MediaPipe webcam demo to confirm landmark quality and FPS.
- Define first rule-based serve feedback checks with visible evidence.
- Find open-source examples of single-camera tennis court calibration and ball tracking.
- Review Tennis_Vision notebook structure and identify reusable concepts.
- Research two-camera pose reconstruction for more accurate technique angles.

## Next

- Build camera upload/recording flow.
- Add video trimming.
- Add slow-motion playback.
- Add pose overlay.
- Add basic serve phase detection.
- Generate first coaching summary.
- Add FPS and pose-confidence diagnostics to the prototype.
- Add a practice-event log: detected setup, toss, contact estimate, follow-through, and confidence.
- Test whether visible court lines can improve serve-location and landing feedback.
- Prototype a cached two-pass video pipeline: analysis pass first, drawing/playback pass second.
- Define a simple two-phone recording setup: side view plus back view.

## Later

- Forehand analysis.
- Backhand analysis.
- Rally footwork analysis.
- Family profiles.
- Progress tracking.
- Multi-person tracking for shared courts or doubles clips.
- Offline mode.
- Community drill library.
- Optional coach review marketplace.
- Single-camera match analytics mode.
- Court-coordinate shot maps.
- Return-depth and rally-pattern summaries.
- Opponent tendency reports.
- Self-supervised ball recovery from confident tracked frames.
- Two-camera 3D pose mode for high-confidence biomechanics.

## Research Questions

- What is the lowest-end phone we want to support?
- Can pose estimation run fast enough in the browser?
- Do we need racket detection, or can MVP feedback focus on body mechanics?
- How do we protect kids' privacy if families use this?
- What feedback should be avoided because it could cause injury or confusion?
- Can a phone camera reliably see enough court lines for homography?
- Is audio impact detection usable on noisy public courts?
- How much ball tracking can run on device before battery and heat become a problem?
- Can two phones be synchronized accurately enough without special hardware?
- Which tennis technique angles are worth measuring in 3D versus explaining visually?
- What should Rally log for each practice clip without making users feel surveilled?
