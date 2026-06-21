# Rally Agent System

This folder is the operating manual for agents working on Rally.

Root `AGENTS.md` is still the automatic boot file. Keep it short. It points here for the detailed rules.

## Required Reading Order

1. `AGENTS.md`
2. `agents/session-handshake.md`
3. `agents/credit-saving.md`
4. `RALLY_NORTH_STAR.md` current priority section
5. `RALLY_AGENT_LOCK.md` active-lock table
6. `RALLY_PROGRESS.md` active task/backlog area
7. the relevant named agent file:
   - `agents/rafa-gameplay.md` for gameplay
   - `agents/sinner-store.md` for Shop / Locker
   - `agents/carlos-world.md` for World / Courts

Only deep-read the visual/world/village docs when the task is about agents, docs, lanes, locks, or project planning. Normal code sessions should stay lean.

## Why This Exists

Rally has already lost time to three avoidable problems:

- agents opening stale copies of the repo
- agents editing the same avatar files at the same time
- agents following old chat context instead of the current product direction

This folder prevents that.

## Operating Rule

If there is a conflict between files, use this order:

1. `RALLY_NORTH_STAR.md`
2. `RALLY_REPO_GUARD.md`
3. `RALLY_AGENT_LOCK.md`
4. `agents/*`
5. `CLAUDE_CODE_PARALLEL_PLAN.md`
6. `RALLY_OVERHAUL_DIRECTIVE.md`
7. older chat prompts or screenshots

Screenshots still beat claims. If the app looks wrong, it is wrong.

## Named Agents

- **Rally Pro** — president / old-head tennis coach; final say above Codex and Claude when the owner makes a ruling.
- **Rafa** — gameplay feel, tennis mechanics, camera, swing, ball, haptics.
- **Sinner** — store, Locker, product cards, outfit selection, referral commerce.
- **Carlos** — world, courts, venues, maps, official links, location unlocks.

## Visual Dashboard

For a compact terminal snapshot, run:

```bash
cd /Users/a14/Desktop/Rally
scripts/rally_agent_fast_status.sh
```

For the full live terminal snapshot, run:

```bash
cd /Users/a14/Desktop/Rally
scripts/rally_agent_status.sh
```

It prints the current branch, latest commit, dirty files, active locks, village board,
North Star priorities, open backlog, and suggested next move.

Use `AGENT_VISUALIZER.md` only when you need the whole operating model at once: named agents, Codex/Claude lanes, hook coverage, hot zones, and handoff flow.

Use `AGENT_WORLD.md` when you want the agents to operate like a small command-center world: Rafa in the Court Lab, Sinner in the Locker Atelier, and Carlos in the Atlas Room.

Use `AGENT_VILLAGE_AUTONOMY.md` when you want the agents to operate like a Clash-style builder village with queues, locks, sync tower, and autonomy levels.

Use `RALLY_VILLAGE_STATE.md` to see whether the village is Green, Yellow, Red, or Wiped, and which agent is awake.

Use `AGENT_VILLAGE_ROLES.md` to spawn the right kind of villager: Builder, Artist, Planner, Scout, Keeper, or Tester.
