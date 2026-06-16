# Rally Agent System

This folder is the operating manual for agents working on Rally.

Root `AGENTS.md` is still the automatic boot file. Keep it short. It points here for the detailed rules.

## Required Reading Order

1. `AGENTS.md`
2. `AGENT_VISUALIZER.md`
3. `AGENT_WORLD.md`
4. `AGENT_VILLAGE_AUTONOMY.md`
5. `agents/session-handshake.md`
6. `agents/locks.md`
7. `agents/lanes.md`
8. the relevant named agent file:
   - `agents/rafa-gameplay.md` for gameplay
   - `agents/sinner-store.md` for Shop / Locker
   - `agents/carlos-world.md` for World / Courts
9. `RALLY_NORTH_STAR.md`
10. `RALLY_PROGRESS.md`
11. `agents/current-priority.md`

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

- **Rafa** — gameplay feel, tennis mechanics, camera, swing, ball, haptics.
- **Sinner** — store, Locker, product cards, outfit selection, referral commerce.
- **Carlos** — world, courts, venues, maps, official links, location unlocks.

## Visual Dashboard

Use `AGENT_VISUALIZER.md` when you need the whole operating model at once: named agents, Codex/Claude lanes, hook coverage, hot zones, and handoff flow.

Use `AGENT_WORLD.md` when you want the agents to operate like a small command-center world: Rafa in the Court Lab, Sinner in the Locker Atelier, and Carlos in the Atlas Room.

Use `AGENT_VILLAGE_AUTONOMY.md` when you want the agents to operate like a Clash-style builder village with queues, locks, sync tower, and autonomy levels.
