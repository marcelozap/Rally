# Rally Agent System

This folder is the operating manual for agents working on Rally.

Root `AGENTS.md` is still the automatic boot file. Keep it short. It points here for the detailed rules.

## Required Reading Order

1. `AGENTS.md`
2. `agents/session-handshake.md`
3. `agents/locks.md`
4. `agents/lanes.md`
5. `RALLY_NORTH_STAR.md`
6. `RALLY_PROGRESS.md`
7. `agents/current-priority.md`

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
