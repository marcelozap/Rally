# NEXT — leftover work after the production-hardening pass

Phases A→D shipped on this branch. The items below are deliberately
**not** in those commits because they require either tooling I didn't
have access to (no Xcode project regeneration, no node CLI to run the
backend tests) or scope the brief tagged as "later". Pick these up in
follow-ups.

## Cross-cutting

- [ ] **Audio latency HUD (debug only).** `AVAudioEngine.outputPresentationLatency`
      + a small overlay showing the host-time compensation we'd apply if
      we scheduled hits via `AVAudioPlayerNode.scheduleBuffer(at:)`. The
      Audio brief says we should *prefer* host-time scheduling already; we
      don't yet — `ToneSynth` plays via a source-node callback. Wiring
      that change is non-trivial and out of scope for this pass.
- [x] **`.gitignore` audit for SwiftData.** `.gitignore` already covers
      DerivedData; double-check `.sqlite`, `.sqlite-shm`, `.sqlite-wal`
      and `*.store` after the next local run. `backend/data/tunables.json`
      is intentionally tracked; backend SQLite files remain ignored.
- [ ] **Regenerate Xcode project** (`xcodegen generate`) after the
      Phase C.6 `NSLocationWhenInUseUsageDescription` was added to
      `project.yml`. Not done here because `xcodegen` isn't installed in
      this environment; without it the location prompt won't show.

## Phase A follow-ups

- [ ] Bake an authored-chart fixture so designers can preview a phase
      transition deterministically in the simulator without playing
      through a 3-minute session.
- [ ] Make the `MatchFlowCoordinator.recoveryUntil` window scale with the
      previous combo height — a 50-combo break should recover slower than
      a 5-combo break.

## Phase B follow-ups

- [ ] **Layer caps under load.** `MusicEngine` currently has no explicit
      voice ceiling — `ToneSynth`'s internal pool is the only guard. If
      stem layering ever stacks above 8 simultaneous voices we'd want a
      cheap CPU meter to back off. Brief flagged this; defer until we
      see a real spike.
- [ ] On-device haptic A/B notes. Run the new Perfect/Great/Good patterns
      blind against the previous scaled-only patterns and record which
      one testers can identify without seeing the screen.

## Phase C follow-ups

- [ ] Surface the journal-hook CTA in **Pause → End run** too, not just
      after `sessionEnd`. Same prompt body, same prefill.
- [ ] Add a second tier of court unlocks (Arthur Ashe, Rod Laver Arena,
      Indian Wells) so check-ins keep paying off beyond the first two.
- [ ] When a tour cosmetic unlocks, briefly highlight the Shop tab badge
      so the player notices. Right now the unlock is silent until they
      navigate over.

## Phase D follow-ups

- [ ] **Server compaction.** The PUT handler now re-serialises the whole
      snapshot on every write. Fine at current scale; revisit if user
      counts grow.
- [x] **`deviceRevision` header.** Avatar/gear edits now use
      `X-Rally-Expected-Revision`; stale appearance edits get a `409`
      while progress/session pushes continue using max-wins merge.
- [x] **Remote tunables admin.** `/api/tunables` reads and writes
      `backend/data/tunables.json` behind `X-Admin-Secret`.
- [x] **Manifest persistence.** `RemoteTunables` loads the cached manifest
      from `UserDefaults` and refreshes/persists when the feature flag is on.

## Tests not yet written

- [ ] Integration test for the JS server merge (needs `node` in the
      build env; couldn't run locally here). Mirror
      `RallyTests/ProgressMergeTests.swift` against `server.js` using
      `vitest` or `node:test`.
