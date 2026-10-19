# Forehand continuity — October 18, 2026

Candidate next-release change on `codex/vela-swipe-gameplay`.

The previous forehand body used separate load and finish envelopes, both with zero slope at contact. The torso and weight-transfer layer therefore stopped briefly at impact. It now uses one continuous Hermite path across load, contact, finish and recovery. It retains the zero additive transform at exact contact and the original wrist/contact targets, protecting the established racket/ball alignment. Left-handed movement mirrors the right-handed path.

Verification: generic iOS Simulator Debug build passes (arm64/x86_64). 39 focused simulator tests passed (29 rig, 10 footwork), including both-hand contact/recovery, clothing/skin coverage and a new check for nonzero, continuous body rotation and forward weight velocity through contact. Rendered all six presets for both forehand hands, plus existing backhand evidence. The known unrelated `CoachVideoAnalyzerTests.swift` compile-time issue is excluded from this focused test command.

Evidence: `/Users/a14/Documents/ChatGPT/Rally/Proof/2026-10-18/` contains twelve forehand inspection GIFs and twelve seven-phase sheets. These are slowed pose inspections, not a device performance result. Inspected the male European/right-handed sheet. The racket remains fairly upright through the forehand; a future full stroke-orientation pass is still needed before claiming Tennis Clash-level animation quality. No physical phone verification occurred in this pass.

The workspace already contained uncommitted swipe gameplay, movement/input tests, project registration and checkout-documentation edits on arrival. Those edits were not changed or staged by this pass. Builds/tests run against the combined current checkout; the forehand commit owns only the shared rig, rig tests, this note and its lock row. The App Store build3 remains unchanged and was still Waiting for Review when checked today.
