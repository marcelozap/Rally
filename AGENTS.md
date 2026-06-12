## SESSION HANDSHAKE — MANDATORY FIRST ACTION
Before any work: run `pwd` and `git log --oneline -1` and print both. The path MUST be /Users/a14/Desktop/Rally and the commit must be the repo's latest (run `git pull` first if a remote exists). If the path is anything else, STOP — you are in a stale copy — and say so instead of working. Run `git status` and report any uncommitted changes from a previous session before adding new work.

## NORTH STAR — MANDATORY READING
Before changing code, read `RALLY_NORTH_STAR.md` in full. It is the canonical product and craft direction for Rally: avatar identity, gameplay feel, shop/locker commerce, journal/training loop, quality bar, and priority order. If older prompts, comments, or planning files conflict with `RALLY_NORTH_STAR.md`, the North Star wins. Detailed structural specs live in `RALLY_OVERHAUL_DIRECTIVE.md`; parallel-agent ownership lives in `CLAUDE_CODE_PARALLEL_PLAN.md`.

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

## LANE OWNERSHIP — CURRENT ACTIVE SPLIT

| Lane | Owner | Files |
| --- | --- | --- |
| CX | Codex/Cursor | `Rally/Features/Home/HomeView.swift`, `Rally/Features/Avatar/RallyAvatarGeometry.swift`, `Rally/Features/Avatar/RallyAvatarView.swift`, `Rally/Features/Avatar/RallyAvatarAppearance.swift`, avatar-creator files, `Rally/Features/Avatar/AvatarCustomizerView.swift`, `Rally/Features/Shop/AvatarShopStageView.swift`, `Rally/Features/Shop/ShopView.swift`, `Rally/Features/Shop/ShopItemDetailView.swift`, `Rally/Features/Shop/LockerHubView.swift` |
| CC | Claude Code | `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift`, gameplay-only helpers under `Rally/Game/`, `Rally/Features/Journal/`, `Rally/Features/Courts/`, audio and haptics files |

For the current avatar craft pass, CX owns shared avatar geometry and SwiftUI avatar rendering. CC may consume those values from gameplay code but must not independently redraw or redesign the avatar.

## SYNC STATE (last verified: 2026-06-11)
- Duplicate hunt: clean (stale copy renamed)
- iCloud eviction: none found, Desktop not iCloud-managed
- Uncommitted work: committed as `[sync] checkpoint — avatar overhaul, pro body mechanics, gameplay polish` (dd3d701)
- Pushed: yes
