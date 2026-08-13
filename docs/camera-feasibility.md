# Phone Camera Feasibility

## Short Answer

Yes, the first version should be able to work with just a normal phone camera.

It will not perfectly replace an in-person coach, radar gun, or multi-camera motion-capture setup. But it can still give useful coaching feedback if the app is careful about what it claims.

## What A Phone Camera Can Do Well

- Record serve, forehand, backhand, volley, and footwork clips.
- Estimate body pose using computer vision.
- Detect broad movement checkpoints.
- Detect court geometry when lines are visible.
- Map player and ball positions into court coordinates if calibration is good enough.
- Compare one attempt to another.
- Identify obvious setup issues like poor framing, bad camera angle, or missing full body.
- Give simple visual overlays and slow-motion review.
- Help users practice one cue at a time.

## What A Single Phone Camera Struggles With

- Exact 3D joint angles
- Accurate ball speed
- Accurate spin rate
- Fine racket-face angle at contact
- Depth and distance when the camera angle is poor
- Occlusion when the arm, racket, or ball is hidden
- Low-light or motion-blurred clips
- Ball height and depth from low camera angles, because several real-world trajectories can look similar in image space.

## Two-Camera Upgrade Path

Two ordinary camera views can reduce the perspective distortion that makes single-camera joint angles unreliable. This could matter for serve loading, knee bend, trunk tilt, shoulder alignment, and injury-risk cues.

The likely flow would be:

- Place two phones at different angles, such as side view plus back view.
- Calibrate or estimate the relative camera views.
- Run pose estimation independently on both videos.
- Synchronize the clips.
- Reconstruct key joints in 3D.
- Report only the angles that are stable enough to trust.

This should be optional, not required for the MVP. The default Rally experience should still work with one phone because accessibility matters more than lab-style precision.

## Best Recording Setup For Serve

- Use landscape orientation when possible.
- Place the phone far enough away to capture the full body and racket.
- Start with a side view for technique.
- Add a back view later for direction, stance, and landing.
- Keep the camera stable using a tripod, fence mount, bag, or water bottle support.
- Record short clips, ideally 3-8 serves at a time.

## MVP Technical Direction

Start with pose estimation and video review, not perfect biomechanics.

Likely first stack options:

- Web prototype: React or Next.js, using browser camera APIs.
- Pose estimation: MediaPipe or TensorFlow.js.
- Local prototype: Python, OpenCV, and MediaPipe for quick webcam/video experiments.
- Court calibration: line detection plus homography once court lines are visible.
- Optional multi-view reconstruction: synchronized two-camera pose estimation for higher-confidence joint angles.
- Storage: local-only at first, or temporary cloud upload if needed.
- Analysis: rule-based coaching checks first, AI summary later.

For advanced match analytics, a later pipeline could combine court detection, player tracking, ball tracking, bounce detection, audio impact detection, and simple physics constraints. This is not needed for the first coaching MVP, but it is a strong research direction.

## Honest Product Boundaries

The app should say when it is uncertain.

Examples:

- "I could not see your full body. Move the camera farther back."
- "The racket was blurred at contact, so I am focusing on toss and body position."
- "This looks like a possible timing issue, but record from the side for a better read."
- "This angle is not reliable for measuring knee bend. Add a second view for a better 3D estimate."

## First Prototype Goal

Analyze a serve clip and return:

- Whether the player and racket are fully visible
- A few pose checkpoints
- One priority coaching cue
- One drill to try next
