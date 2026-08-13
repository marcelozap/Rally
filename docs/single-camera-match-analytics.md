# Single-Camera Match Analytics

## Source Idea

User-provided reference:

https://lnkd.in/du2bj_Sz

Related open-source reference:

https://github.com/vahehambardzumyan/Tennis_Vision

The idea is to extract meaningful tennis analytics from a single normal broadcast-style camera: court geometry, player tracking, ball bounces, shot maps, return depth, and point breakdowns.

## Why This Matters For Rally

Rally should not only help players with technique. Over time, it could help athletes and coaches understand tactics:

- Where shots land
- Whether returns are getting shorter
- How court position changes during a point
- Which patterns lead to lost points
- What an opponent tends to do under pressure

This supports the broader mission: analytics should be useful for every athlete, not only professionals with expensive coaching and tracking systems.

## Candidate Pipeline

- Court detection: Hough transform plus projective geometry, including cross-ratio constraints, to estimate a homography.
- Player tracking: detect and track both players frame by frame.
- Ball tracking: object detection plus Kalman filtering, chi-square gated association, and smoothing.
- Occlusion recovery: motion-aware segmentation or U-Net-style recovery for missing ball/player observations.
- Audio impact detection: spectral flux to identify likely racket hits and bounces.
- Bounce mapping: project detected bounce points onto court coordinates.
- Physics constraints: constrain ball height to zero at bounce and use gravity between bounce events instead of trusting unconstrained 3D reconstruction from one camera.

## Important Insight

Low camera angles create a depth ambiguity: ball height and distance from the camera can move image pixels in nearly the same direction. A trajectory can look correct in the frame while being wrong by meters in real space.

For Rally, this means single-camera 3D claims should be conservative. Physics constraints and confidence scoring are more trustworthy than pretending the camera gives exact 3D truth.

## MVP Relevance

Do not build the full pipeline first.

Pieces that may help the early product:

- Detect whether the court and full body are visible.
- Estimate a court homography when court lines are clear.
- Use all visible court lines, not just the outer rectangle, to stabilize geometry.
- Use court coordinates for simple feedback like serve landing zone or recovery position.
- Use audio peaks to identify likely hit timing.
- Split video processing into an expensive cached analysis pass and a fast rendering pass.
- Use confidence scores and ask users to re-record when geometry is unreliable.

## Later Product Mode

This could become a separate "Match Analytics" mode:

1. Upload or record a rally/match clip.
2. Calibrate the court from visible lines.
3. Track players and ball.
4. Map bounces and player positions to the court.
5. Generate shot maps and tactical summaries.
6. Show a short explanation of the point pattern.

## Risks

- Broadcast clips may have camera cuts, zooms, overlays, and compression artifacts.
- Public-court phone clips may not show enough court lines.
- Small ball detection is fragile in low resolution or low light.
- Audio impact detection may be noisy on busy courts.
- A high-accuracy pipeline may require cloud compute, which conflicts with free access unless carefully managed.
