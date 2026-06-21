# Credit-Saving Agent Protocol

Purpose: keep Rally agents useful without spending credits rereading the whole repo, re-running broad searches, or duplicating another agent's work.

This file governs normal sessions. Deep docs still exist, but they are pulled only when needed.

## Fast Boot

For ordinary work, read only:

1. `AGENTS.md`
2. `agents/session-handshake.md`
3. `agents/credit-saving.md`
4. `RALLY_NORTH_STAR.md` current priority section only
5. `RALLY_AGENT_LOCK.md` active-lock table only
6. `RALLY_PROGRESS.md` active task/backlog area only

Then run:

```bash
cd /Users/a14/Desktop/Rally
scripts/rally_agent_status.sh
```

Do not read `AGENT_WORLD.md`, `AGENT_VILLAGE_AUTONOMY.md`, `AGENT_VILLAGE_ROLES.md`, old plan files, or archive files unless the current task is about agent/village/docs.

## When To Deep Read

Deep-read only the docs/files needed for the current lane:

- Gameplay/Rafa: `agents/rafa-gameplay.md`, `Rally/Game/*` files directly touched by the bug.
- Shop/Sinner: `agents/sinner-store.md`, current Shop/Locker files, catalog/router only if relevant.
- World/Carlos: `agents/carlos-world.md`, Courts/Journal files directly touched by the bug.
- Locks/Keeper: `RALLY_AGENT_LOCK.md`, `agents/locks.md`, `RALLY_REPO_GUARD.md`, affected agent docs.

Do not deep-read multiple lanes in one session unless the user explicitly asks for cross-lane work.

## Search Rules

Use targeted searches:

```bash
rg -n "exactSymbol|errorText|functionName" path/to/relevant/files
rg --files Rally/Game Rally/Features/Avatar
```

Avoid:

- repo-wide `cat`
- opening long files from the top when `rg -n` can jump to the relevant symbol
- rereading generated logs, DerivedData, screenshots, archives, or old chat dumps
- broad "audit the whole app" passes without a failing screenshot/build/error

## Work Size

Default to one small, observable task:

- one bug
- one screen
- one mechanic
- one doc/protocol update

Stop after a passing build and commit. Let the next agent inherit from Git.

## Build Economy

Use the cheapest valid proof:

- Docs-only: no `xcodebuild`.
- Pure Swift helper/tests: run the focused XCTest target if practical.
- UI/game code: run the standard Rally build.
- Visual claims: one simulator screenshot is better than three paragraphs.

Do not run a full clean build unless:

- project files changed
- build cache appears poisoned
- previous incremental build failed strangely
- user explicitly asks for clean

## Commit Economy

Commit only owned files:

```bash
git status --short
git add exact/file1 exact/file2
git commit -m "[CX] Short focused message"
git push origin rally/dev
```

Never use `git add -A` when unrelated dirty files exist.

## Response Economy

Final reports should be short:

- changed files
- build/test result
- commit hash
- push status
- next task

Do not paste long source, long logs, or full doc summaries unless the user asks.

## Skill Use

Use skills only when they materially reduce work:

- iOS simulator/debug skills for launching, screenshots, logs, or runtime proof.
- SwiftUI skills for actual UI refactors.
- Data/report/presentation skills only for their matching artifact work.

Do not invoke a skill just because it exists.

## Stop Conditions

Stop and ask if:

- target file is locked by another agent
- dirty target files contain uncommitted work you did not create
- branch/path is wrong
- build fails twice for unrelated reasons
- the task would require a broad rewrite outside the current lane
