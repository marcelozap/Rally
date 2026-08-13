# Source References

## Tennis_Vision

URL: https://github.com/vahehambardzumyan/Tennis_Vision

Status: External reference. Do not vendor code into Rally yet.

### What It Does

Tennis_Vision analyzes a broadcast-style tennis clip from one camera. Its README describes a pipeline that finds the court from painted lines, tracks players and the ball, detects contacts from video and audio, estimates world/court coordinates, and renders an annotated output.

The project is currently organized around one notebook:

- `notebooks/tennis_detection.ipynb`

Its listed Python dependencies are:

- `ultralytics`
- `opencv-python-headless`
- `jupyter`
- `ipykernel`
- `huggingface_hub`
- `matplotlib`
- `numpy`
- `scipy`
- `yt-dlp`

### Useful Ideas For Rally

- Court detection can start from known tennis geometry rather than a trained court-keypoint model.
- Cross-ratio and homography are useful when court lines are visible.
- Fitting all visible court lines may be much more stable than fitting only the outer court rectangle.
- A cached analysis pass plus a separate render/playback pass is a good architecture for iteration.
- Ball tracking should combine detector candidates with temporal filtering and association instead of trusting per-frame detections alone.
- Audio can help identify contact timing, but video still needs to decide where the ball was.
- Physics constraints are important because one camera cannot reliably recover exact 3D ball height and depth in many tennis views.
- The system should report confidence and known failure cases, especially when court lines, ball visibility, or camera angle are poor.

### Possible Rally Adaptation

For the free coaching MVP, avoid the full broadcast analytics pipeline. Borrow only the practical pieces:

- Court visibility score
- Court homography when lines are clear
- Stable overlay rendering
- Hit-timing hints from audio peaks
- Confidence-aware feedback

For a later match analytics mode, revisit:

- Player tracking
- Ball trajectory smoothing
- Bounce and racket-hit classification
- Shot maps
- Tactical summaries

### Notes

This reference is optimized for broadcast footage, not casual phone clips. Rally will need extra guardrails for public-court phone videos: shaky camera, partial court visibility, low resolution, wind noise, multiple courts, and users standing too close to the frame.

## YOLOvX Two-Camera 3D Pose Reference

URL: https://www.linkedin.com/company/yolovx/posts/

Status: User-provided LinkedIn reference. Treat as inspiration until we find the underlying paper, demo, or code.

### What It Describes

The post describes 3D pose estimation for lifting technique analysis using two standard camera views. Pose estimation runs independently on each stream, the views are calibrated and synchronized, and the system reconstructs 3D movement with continuously updated trunk and knee angles.

### Useful Ideas For Rally

- Two camera views can correct perspective distortion that makes single-camera 2D joint angles misleading.
- A side view plus rear/front view may be enough for higher-confidence tennis technique analysis.
- Calibration and synchronization are core requirements, not optional polish.
- 3D reconstruction should be reserved for metrics where it improves coaching quality, such as trunk tilt, knee bend, shoulder alignment, and loading mechanics.

### Possible Rally Adaptation

Keep the MVP one-phone-first. Later, add an optional "two-phone accuracy mode" for players practicing with a sibling, parent, or teammate:

- One phone records from the side.
- One phone records from behind or in front.
- The app synchronizes clips using audio or a visible clap.
- Pose is estimated in each view.
- The app reconstructs only selected joints and reports confidence.

### Notes

This reference comes from lifting and ergonomics, not tennis. The core geometry transfers, but tennis adds fast racket motion, ball timing, and wider movement across the court.

## MediaPipe Real-Time Pose Reference

URL: https://lnkd.in/gWZa-b5T

Status: User-provided LinkedIn-shortened code reference. Treat as a practical prototype pattern; verify the underlying repo before using code.

### What It Describes

The post describes a real-time full-body pose detection system using Python, OpenCV, and MediaPipe. It reads from a webcam, tracks MediaPipe's 33 body landmarks, draws a skeleton overlay, and displays an FPS counter.

### Useful Ideas For Rally

- This is close to the first Rally proof of concept.
- MediaPipe gives a ready-made landmark set for shoulders, elbows, wrists, hips, knees, ankles, and other key body points.
- OpenCV is useful for fast local testing with webcam or saved practice clips.
- FPS matters because on-court feedback should feel responsive.
- Pose confidence and landmark visibility should become part of Rally's feedback quality score.

### Possible Rally Adaptation

Create a local prototype before the full app:

- Open a webcam or sample serve video.
- Run MediaPipe Pose on every frame.
- Draw the skeleton overlay.
- Show FPS and landmark visibility.
- Save a short annotated output clip.
- Use landmarks to detect broad serve phases: setup, toss, loading, contact, and follow-through.

### Notes

This reference is simpler than the full tennis analytics pipeline, which is good. The main missing pieces for Rally are tennis-specific interpretation, camera-placement guidance, and confidence-aware coaching language.

## Human Pose And Activity Intelligence Reference

URL: User-provided LinkedIn post, no code URL supplied.

Status: Conceptual reference. Useful for product architecture and explainability.

### What It Describes

The post describes a real-time camera-only activity recognition system. It uses YOLO Pose for keypoint detection, ByteTrack for multi-person tracking, and a rule-based engine for explainable activity recognition. The demo includes standing, sitting, walking, hand-raised gestures, bending posture, squat rep counting, fall detection, safety alerts, a live analytics dashboard, and persistent event logging.

### Useful Ideas For Rally

- Rule-based recognition can make coaching feedback explainable.
- Event logs can turn raw video into a practice timeline.
- Multi-person tracking may matter on public courts, doubles clips, or family practice sessions.
- Safety-sensitive feedback should avoid black-box claims when a simple rule can be shown.
- A dashboard can summarize practice without requiring the user to rewatch every clip.

### Possible Rally Adaptation

For serve analysis, start with a transparent rules layer over pose landmarks:

- Detect setup, toss, loading, contact estimate, follow-through, and landing.
- Store each phase as a timestamped event with confidence.
- Attach evidence to each coaching note, such as landmark visibility, shoulder/hip relation, or toss drift.
- Show a short timeline below the video.
- Keep persistent logs lightweight and privacy-aware.

### Notes

The architecture is more important than the activities themselves. Rally does not need standing/sitting/walking labels, but it does need explainable tennis-specific events.

## Rally Portfolio Practice System Entry

URL: https://www.marcelozapata.dev/rally

Status: User-provided product framing and stack reference.

### What It Describes

The portfolio entry frames Rally as a practice app for sports, sessions, activity data, training logs, match history, recovery notes, wearable data, and progress review. The core loop is daily practice, with local-first iOS architecture and optional account sync.

### Useful Ideas For Rally

- The free coach should plug into Rally's broader practice-memory system.
- Coaching analysis should create durable practice records, not isolated one-off video reports.
- Training logs, matches, recovery notes, activity data, and video feedback should become one improvement timeline.
- Wearable data, especially Garmin-style activity history, can give recovery and workload context.
- Local-first SwiftData remains a good default for privacy and free access.
- Optional Node sync can preserve progress without forcing every user into an account.

### Possible Rally Adaptation

Treat the coach as another practice input:

- A serve clip becomes a practice entry.
- Pose analysis becomes an event timeline.
- Coaching cues become improvement markers.
- Drills become next-session suggestions.
- Activity and recovery data become context for whether the player should push, maintain, or recover.

### Notes

The current game stack can support this direction, but computer vision should stay modular at first. The safest path is Python/OpenCV/MediaPipe for local experiments, then iOS integration or backend service only after the coaching loop is proven useful.
