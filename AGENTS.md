# Rally Agent Boot

Before doing any work in this repository, read the agent system in `agents/`.

## Mandatory First Action

1. Read `RALLY_REPO_GUARD.md`.
2. Read `RALLY_AGENT_LOCK.md`.
3. Read `agents/session-handshake.md`.
4. Run the handshake commands from `agents/session-handshake.md`.

If the repo path is not `/Users/a14/Desktop/Rally`, stop. Do not inspect, edit, build, or commit from any other Rally copy.

## Canonical Direction

Read `RALLY_NORTH_STAR.md` before code changes. It is the product tiebreaker.

If anything conflicts, priority order is:

1. `RALLY_NORTH_STAR.md`
2. `RALLY_REPO_GUARD.md`
3. `RALLY_AGENT_LOCK.md`
4. `agents/*`
5. `CLAUDE_CODE_PARALLEL_PLAN.md`
6. `RALLY_OVERHAUL_DIRECTIVE.md`

## Agent Operating Docs

- `agents/README.md` — overview and reading order
- `AGENT_VISUALIZER.md` — visual map of agents, lanes, hooks, and handoffs
- `AGENT_WORLD.md` — immersive operating world for Rafa, Sinner, and Carlos
- `AGENT_VILLAGE_AUTONOMY.md` — Clash-style autonomous builder village for Codex/Claude sync
- `AGENT_VILLAGE_ROLES.md` — villager jobs, aging, death, reproduction, and inheritance
- `RALLY_VILLAGE_STATE.md` — live village health, active builders, damage, and proof status
- `agents/session-handshake.md` — repo/path/build safety
- `agents/locks.md` — collision avoidance
- `agents/lanes.md` — CX/CC ownership
- `agents/handoff.md` — how to stop cleanly
- `agents/current-priority.md` — next work to take
- `agents/rally-pro-coach.md` — Rally Pro, president / old-head tennis coach with final say
- `agents/rafa-gameplay.md` — Rafa, gameplay agent
- `agents/sinner-store.md` — Sinner, store / Locker agent
- `agents/carlos-world.md` — Carlos, world / courts agent

## Canonical Repo

- Path: `/Users/a14/Desktop/Rally`
- Remote: `https://github.com/marcelozap/Rally.git`
- Branch: `rally/dev`

## Build Rule

Every code task ends with a passing Rally build unless explicitly documentation-only.

```bash
cd /Users/a14/Desktop/Rally
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```
