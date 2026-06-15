# Agent Locks

Read `RALLY_AGENT_LOCK.md` before editing.

This file explains the daily version of the same rule.

## Why Locks Matter

Uncommitted edits are invisible to the other agent. A lock only works if it is committed and pushed before the risky work begins.

## When To Lock

Create a lock before editing:

- avatar geometry or avatar rendering
- `GameScene.swift` avatar assembly
- `HomeView.swift` loadout controls
- `RALLY_PROGRESS.md`
- any file already listed in `RALLY_AGENT_LOCK.md`

## Lock Flow

1. Pull latest.
2. Add your row to `RALLY_AGENT_LOCK.md`.
3. Commit only the lock file:

```bash
git add RALLY_AGENT_LOCK.md
git commit -m "[lock] [CX] claims <area>"
git push
```

4. Do the work.
5. Build.
6. Commit work.
7. Mark the lock `RELEASED` in the same commit or in a follow-up release commit.

## If Another Agent Holds The Lock

Stop. Do not edit around the lock.

Report:

- the lock row
- the file you needed
- the proposed next step

## Shared Hot Zones

Always check the live table in `RALLY_AGENT_LOCK.md`, but the common danger files are:

- `Rally/Features/Avatar/RallyAvatarView.swift`
- `Rally/Features/Avatar/RallyAvatarGeometry.swift`
- `Rally/Features/Avatar/RallyAvatarAppearance.swift`
- `Rally/Features/Avatar/RallyAvatarPartRenderer.swift`
- `Rally/Game/GameScene.swift`
- `Rally/Features/Home/HomeView.swift`
- `RALLY_PROGRESS.md`
