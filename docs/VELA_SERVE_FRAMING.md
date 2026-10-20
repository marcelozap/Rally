# Vela Tennis serve framing repair

The gameplay avatar render target clipped the overhead racket during the serve. The old 280 × 320 viewport projected the racket above its top edge for all six athlete presets and both hands.

The gameplay viewport is now 350 × 400. Its orthographic scale grows proportionally from 1.05 to 1.3125, preserving pixels per metre and the player’s court size. The camera rises from 0.93 m to 1.18 m to allocate the extra area overhead. Existing floor projection keeps the feet anchored. Studio and opponent cameras retain their existing framing.

## Verification

- Regression samples 61 serve phases for each of six presets and both hands, checking skeleton joints with an eight-pixel margin and the racket bounding-box corners. It fails with the old frame and passes with the repair.
- AvatarRigTests, RallyMirrorSceneTests, and RallyVisualIntegrationTests: 56 tests passed, zero failures.
- Generic iOS Simulator Debug build passed.
- Native simulator screenshots inspected during toss and return to rally. Full extension is covered by the sampled regression; native captures do not cover every animation frame.
- Test invocation retains the existing CoachVideoAnalyzerTests.swift exclusion; this is not a full-suite claim. Physical-device performance has not been tested.

Local evidence: `/Users/a14/Documents/ChatGPT/Rally/Proof/2026-10-19-serve/` contains baseline.log, tests.log, build.log and native serve screenshots (serve-08.png shows the raised racket during the toss).
