## SESSION HANDSHAKE — MANDATORY FIRST ACTION
Before any work: run `pwd` and `git log --oneline -1` and print both. The path MUST be /Users/a14/Desktop/Rally and the commit must be the repo's latest (run `git pull` first if a remote exists). If the path is anything else, STOP — you are in a stale copy — and say so instead of working. Run `git status` and report any uncommitted changes from a previous session before adding new work.

---

## CANONICAL REPO
- Path: `/Users/a14/Desktop/Rally`
- Remote: `https://github.com/marcelozap/Rally.git`
- Branch: `cursor/init-rally-ios-scaffold`
- Stale copy (renamed, do not use): `/Users/a14/mac-trade-dashboard/Rally_STALE_DO_NOT_USE.xcodeproj`

## COMMIT PREFIXES
- `[CC]` — Claude Code agent commits
- `[CX]` — Codex/Cursor agent commits
- `[sync]` — checkpoint / handoff commits

## FILE OWNERSHIP (parallel work — do not cross lanes)
See `CLAUDE_CODE_PARALLEL_PLAN.md` for the full boundary map.
Additive-only rule applies to any file marked shared — Claude Code may ADD a call site
or injection but must NOT rearrange existing code in those files.

## SYNC STATE (last verified: 2026-06-11)
- Duplicate hunt: clean (stale copy renamed)
- iCloud eviction: none found, Desktop not iCloud-managed
- Uncommitted work: committed as `[sync] checkpoint — avatar overhaul, pro body mechanics, gameplay polish` (dd3d701)
- Pushed: yes
