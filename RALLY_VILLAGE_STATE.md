# Rally Village State

This file sits next to `RALLY_PROGRESS.md`.

`RALLY_PROGRESS.md` tracks tasks.

`RALLY_VILLAGE_STATE.md` tracks the living state of the agent village: who is awake, who is sleeping, what is damaged, what is being rebuilt, and what proof is needed before the village is considered healthy.

This is an interface metaphor over real repo facts. The agents are not magic. The village health comes from Git, builds, screenshots, locks, and the progress ledger.

---

## Current Village State

| Building | State | Evidence |
|----------|-------|----------|
| Town Hall | Stable | `RALLY_NORTH_STAR.md` exists and governs direction. |
| Sync Tower | Stable | Active branch is `rally/dev`; GitHub remote is `https://github.com/marcelozap/Rally.git`. |
| Builder Tower | Under construction | `RALLY_PROGRESS.md` has active pending gameplay / Claude-hook entries. Do not rewrite it casually. |
| Lock Wall | Stable | `RALLY_AGENT_LOCK.md` exists; active locks must be checked before hot-zone edits. |
| Rally Pro Box | Stable | `agents/rally-pro-coach.md` exists; Rally Pro sits above Codex and Claude as final owner-backed ruling voice. |
| Rafa Court Lab | Awake | Gameplay files currently have uncommitted work: `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift`. |
| Sinner Locker Atelier | Sleeping | No active Shop/Locker task should begin until gameplay loop stabilizes or user explicitly routes to Sinner. |
| Carlos Atlas Room | Sleeping | No active World/Courts task should begin until gameplay loop stabilizes or user explicitly routes to Carlos. |
| Replay Theater | Needs proof | Visual gameplay verification still matters more than claims. |

---

## Agent Turn Board

| Turn | Agent | Status | Allowed Work | Stop Condition |
|------|-------|--------|--------------|----------------|
| 0 | Rally Pro | President | Final rulings only; does not code | Owner has not made a ruling |
| 1 | Rafa | Active | Wall-rally addiction loop, timing, camera, score/lives/multiplier feel | Build fails, avatar identity diverges, or gameplay screenshot contradicts claim |
| 2 | Sinner | Queued | Locker/Shop clarity after Rafa checkpoint | Gameplay loop still unstable |
| 3 | Carlos | Queued | Courts/Journal reliability after Rafa checkpoint | Gameplay loop still unstable |

Only one active builder should modify files at a time unless the user explicitly starts multi-agent work.

---

## Village Health Rules

The village has four health states.

| Health | Meaning | Trigger |
|--------|---------|---------|
| Green | Safe to build | Clean pull, expected branch, no conflicting locks, build passing. |
| Yellow | Build carefully | Dirty worktree, pending ledger entries, visual QA missing, or untracked docs. |
| Red | Stop and repair | Build failing, wrong path, wrong branch, hot-zone collision, missing required source file. |
| Wiped | Rebuild protocol | Core docs deleted, project file damaged, many files deleted, or Git history diverged badly. |

Current default:

```text
Yellow — gameplay edits are active and uncommitted.
```

---

## Damage Model

Use this to make the world react to real project events.

| Repo Event | Village Event | Required Response |
|------------|---------------|-------------------|
| Required file deleted | Building damaged | Stop feature work; restore from Git or rebuild intentionally. |
| `RALLY_NORTH_STAR.md` deleted | Town Hall destroyed | Restore immediately before any work. |
| `RALLY_PROGRESS.md` corrupted | Builder Tower damaged | Recover from Git history; do not guess task state. |
| `RALLY_AGENT_LOCK.md` deleted | Lock Wall destroyed | Restore before parallel work. |
| `Rally.xcodeproj/project.pbxproj` broken | Roads damaged | Stop and repair build graph. |
| Build fails | Village under attack | Fix build before new features. |
| Screenshot proves mismatch | Replay Theater alarm | Screenshot wins; patch the visible failure. |
| Wrong repo path | False village | Stop immediately. |
| Golden file appears | Treasure chest | Treat as high-value context; read, summarize, and route into the correct doc before coding. |

---

## Golden File Protocol

A golden file is any new file that appears to contain important strategy, specs, screenshots, product direction, or implementation clues.

Examples:

- `RALLY_CHAT_CONTEXT.md`
- design prompts
- screenshot bundles
- product strategy files
- affiliate feed samples
- TestFlight notes

When a golden file appears:

1. Do not ignore it.
2. Do not blindly commit it.
3. Read it.
4. Decide whether it belongs in:
   - `RALLY_NORTH_STAR.md`
   - `RALLY_PROGRESS.md`
   - `AGENT_WORLD.md`
   - `agents/current-priority.md`
   - an archive folder
5. Summarize the decision in the final response.

---

## Rebuild Protocol

If the village is Red or Wiped:

```text
1. Stop all feature work.
2. Run git status.
3. Identify deleted/damaged files.
4. Compare against origin/rally/dev.
5. Restore only the damaged required files, never unrelated user edits.
6. Build.
7. Update RALLY_VILLAGE_STATE.md with the incident.
8. Resume from RALLY_PROGRESS.md only after Green or Yellow health is restored.
```

Never use destructive commands like `git reset --hard` unless the user explicitly asks in the current turn.

---

## Sleep / Wake Rules

Agents can sleep. Sleeping means no active task, not deleted.

```text
Rafa sleeps when gameplay has a passing build and a good screenshot.
Sinner wakes when gear/Shop/Locker is the selected task.
Carlos wakes when World/Courts/Journal is the selected task.
Codex wakes when the user asks this thread to act.
Claude wakes when the user opens Claude Code or runs its hooks.
```

When an agent wakes:

1. Read `AGENTS.md`.
2. Read `AGENT_VILLAGE_AUTONOMY.md`.
3. Read this file.
4. Check Git state.
5. Enter the correct room.

---

## Sync With Claude And Codex

Codex and Claude share the village through GitHub, not through memory.

Both must treat these files as shared state:

- `AGENTS.md`
- `AGENT_VISUALIZER.md`
- `AGENT_WORLD.md`
- `AGENT_VILLAGE_AUTONOMY.md`
- `AGENT_VILLAGE_ROLES.md`
- `agents/rally-pro-coach.md`
- `RALLY_VILLAGE_STATE.md`
- `RALLY_PROGRESS.md`
- `RALLY_AGENT_LOCK.md`

Claude Code additionally has mechanical hooks in `.claude/hooks`.

Codex follows the markdown protocol directly.

If Claude says something and Codex says something else, Git + screenshots + `RALLY_NORTH_STAR.md` decide.

---

## Current Generations

| House / Worker | Generation | Life State | Inheritance Source |
|----------------|------------|------------|--------------------|
| Rally Pro | President | Awake only for rulings | Owner decisions logged in `agents/rally-pro-coach.md` |
| Rafa Builder | 1 | Awake | `RALLY_PROGRESS.md` active gameplay rows + dirty `GameScene.swift` / `Tunables.swift` |
| Sinner Artist | 1 | Sleeping | `agents/sinner-store.md`, Shop backlog |
| Carlos Planner | 1 | Sleeping | `agents/carlos-world.md`, Journal/World backlog |
| Keeper | 1 | Awake when docs/locks change | `AGENTS.md`, `RALLY_AGENT_LOCK.md`, village docs |
| Scout | 1 | Awake when golden files appear | screenshots, `RALLY_CHAT_CONTEXT.md`, user notes |

When a worker session ends, increment its generation only if the next session continues the same house/job from committed repo memory.
