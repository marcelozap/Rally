# Vela next-release visual polish — October 15, 2026

Branch: `codex/vela-next-visual-polish`, based on submitted-source commit `c97c9a7`.
The current App Store build is not replaced or withdrawn by this work.

## Candidate changes

- Fitting/Home preview: lower racket hand and free hand into an at-ease pose, with a small independent breathing motion. Preserve the selected hand and wrist-attached racket.
- Studio lighting: stronger directional key, quieter ambient/front fill and slightly more local occlusion to show the face and garment shape. Court lighting remains unchanged.
- Footwork: square the swing-foot lift envelope so vertical speed reaches zero at lift-off/touchdown. Keep existing support anchors, timing, clearance and lateral travel.
- Add a bounded ankle roll during the airborne phase; planted feet stay flat. Apply a modest toe-out stance and let forehand feet pivot with the pelvis as backhands already did.

This refines the existing skinned characters; it does not replace their meshes or create higher-resolution texture assets. It is not a completed HD asset overhaul.

## Evidence

Generic iOS Simulator Debug build passes (arm64 and x86_64).

37 focused iOS simulator tests pass (27 rig, 10 footwork), including skinning, mandatory clothing, outfit isolation, all six models/both hands, backhand grip/recovery and soft landing. Old retailer-cut test fixtures were updated to assert the current Vela tee contract rather than expecting removed retailer polo/tank behavior.

The command excludes `CoachVideoAnalyzerTests.swift` because of the previously documented unrelated compiler type-check timeout. This is not a claim that the full app suite passed.

Six 768×1024 roster renders and twelve backhand inspection animations/contact sheets exported to:
`/Users/a14/Documents/ChatGPT/Rally/Proof/2026-10-15/`

Inspected male Model 1 and female Model 3 studio renders and male right-handed backhand sheet. The images show retained clothing coverage and attached rackets. Animations are slow pose inspection, not an on-device frame-rate benchmark.

## Before a release

- Compare live shuffle/stop/reversal and both-hand forehand/backhand on a physical iPhone. Confirm ankle roll does not cause visible sole penetration.
- Inspect the six characters at phone scale, especially fingers, hair edges, shoulder sleeves, shorts-to-thigh transition and shoe grounding.
- Record actual frame-time and memory on phone and iPad before increasing mesh/texture detail.
- Follow up with authored hair/facial and garment-detail improvements where the comparison exposes a clear defect. Additional art must have documented reuse rights.
- Assign the next version/build only after candidate acceptance; preserve local data and current App Store review.
