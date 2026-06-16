# Handoff Protocol

Use this whenever one agent stops and another continues.

## Required Handoff Note

```text
Path:
Branch:
Last commit:
Dirty files:
Files intentionally left untouched:
What changed:
Build result:
Simulator result:
Next recommended task:
Known risks:
```

### 2026-06-16 — CX continuation note

The two action items in the note above were completed after this handoff was written:

- `RallyTests/WallRallyEscalationTests.swift` was registered in the Xcode project, run on the iPhone 16 Pro simulator, committed as `504e0ed`, and pushed.
- `Rally/App/ContentView.swift` was built, committed as `23509a8`, and pushed.

The archived chat context remains useful as historical memory, but its branch name and build-status lines should be treated as stale.

## Stop Conditions

Stop and hand off instead of forcing progress when:

- build fails after two repair attempts
- target files are locked by the other agent
- simulator screenshot contradicts the code claim
- the repo path is not `/Users/a14/Desktop/Rally`
- the task requires App Store, Garmin, affiliate, or GitHub credentials not available to the agent

## Progress Ledger

`RALLY_PROGRESS.md` is append-first. Do not rewrite another agent's log.

When completing a task:

1. Check the related box if it is truly done.
2. Add one short session log line with date, task id, commit hash, and note.
3. If visual QA is still needed, say `VERIFY` instead of marking complete.

## Screenshot Rule

For visual work, take or request screenshots of:

- Home / Loadout
- gameplay after PLAY
- Shop card grid
- Shop detail
- World / Courts if changed

If screenshots look wrong, prioritize the screenshot over the implementation claim.

---

## 2026-06-16 — [CC] long unattended session (user away at work)

```text
Path: /Users/a14/Desktop/Rally
Branch: rally/dev
Last commit: d355b86 [CX] Wall rally timing taper and multiplier banners
Dirty files: RALLY_PROGRESS.md (M), Rally/App/ContentView.swift (M),
             RallyTests/WallRallyEscalationTests.swift (new, untracked),
             archive/ (new, untracked), shop-art-direction.md (untracked, CX spec — not mine)
Files intentionally left untouched: Rally/Services/RallySyncCoordinator.swift (real bug found,
             not fixed — see Known risks), RallyAvatarView.swift nose stroke (CX lane, logged
             not fixed), HomeView.swift dead code (CX lane, logged not fixed),
             shop-art-direction.md (CX lane spec, referenced only)
What changed:
  1. [coach] Logged the Rally Pro / Owner's Box doc set (verified clean, no further edits needed).
  2. Archived stale golden file RALLY_CHAT_CONTEXT.md → archive/RALLY_CHAT_CONTEXT_2026-06-16.md;
     extracted its still-valid findings (nose stroke, HomeView dead code) into RALLY_PROGRESS.md T7.
  3. Reviewed (did not author) the uncommitted wall-rally timing-taper / multiplier-banner diff in
     GameScene.swift + Tunables.swift already on disk from a parallel session — cross-checked all
     constants and call sites, found correct, left as-is.
  4. Renamed RallyTab.journal → RallyTab.world in ContentView.swift (pure rename, confirmed
     single-file blast radius via grep first — safe without a build).
  5. Surveyed the backend sync layer (RallySyncCoordinator/Triggers, RemoteTunables, RallyAPIClient).
     Found a real data-loss bug in RallySyncCoordinator.apply() (see Known risks). Deliberately did
     NOT fix it — destructive-merge logic on the user's real journal/training history is exactly the
     class of change that needs a build + simulator to trust, and I have neither in this sandbox.
  6. Added RallyTests/WallRallyEscalationTests.swift — full coverage of Tunables.wallSpeedTier /
     wallSpeedScalar / wallTimingScalar (tier boundaries, monotonic taper, openingBoost confined to
     tier 0). Confirmed via read of existing test files that no prior test covered these.
Build result: NOT RUN — no Xcode/simulator available in this sandbox all session.
Simulator result: NOT RUN — same reason.
Next recommended task: (a) run a real build + the new WallRallyEscalationTests, confirm pass;
  (b) fix RallySyncCoordinator.apply() per the Known risks note below; (c) real-phone Priority 1
  test per agents/current-priority.md once (a) is green.
Known risks:
  - RallySyncCoordinator.apply() deletes ALL local TrainingSession/MatchEntry/JournalEntry rows
    every pull and re-inserts from the server payload with no id-based merge — unlike Avatar/Progress,
    which have revision-based conflict detection. A pull that races a local write (or a server payload
    missing recent rows) can silently erase real session/journal history. Full detail already logged
    in RALLY_PROGRESS.md → BLOCKED/NOTES.
  - I do not have git push/commit credentials in this sandbox (by design — "No git push from sandbox").
    All edits above are on-disk via direct file writes, not committed. A .git/index.lock
    "Operation not permitted" also surfaced earlier this session; I did not force-remove it or run any
    git mutating command, on the assumption it could reflect a concurrent process. Please check
    `git status` yourself before committing — there may be more uncommitted work here than just mine.
  - A live, separate Codex/Cursor ([CX]) session appears to have been operating on this same repo
    concurrently with this one (matching commits and a shared task list with entries I didn't create).
    Worth confirming nothing collided before committing.
```
