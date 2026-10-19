# Session Handshake

## Current Vela Tennis checkout — October 18, 2026

Vela Tennis is the current product name. This is the owner-approved relocated checkout, recorded in the September–October work locks and verified against `https://github.com/marcelozap/Rally.git`. Use the path below; the former Desktop/Rally folder no longer exists. `rally/dev` remains the shared development branch; `codex/vela-*` branches are valid next-release work. Verify the remote, current branch and dirty files before edits. Internal Rally project and bundle identifiers remain stable.

Every agent session starts here. Do not inspect, edit, build, or commit before this check.

## Canonical Repo

```bash
/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally
```

## Forbidden Paths

Do not work from:

```bash
/Users/a14
/Users/a14/Documents/New project
/Users/a14/mac-trade-dashboard
/Users/a14/mac-trade-dashboard/Rally_STALE_DO_NOT_USE.xcodeproj
```

## First Commands

```bash
cd "/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally" || exit 1
pwd
git rev-parse --show-toplevel
git branch --show-current
git log --oneline -1
git status --short --branch
```

Expected:

```text
/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally
/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally
rally/dev
```

If the path is wrong, stop and report:

```text
STOP: wrong Rally folder. I am not editing because this is not /Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally.
```

## Pull Rule

If network credentials are available:

```bash
git pull --ff-only
```

If pull fails because of local edits, stop and report the exact dirty files.

## Dirty Worktree Rule

Before editing:

```bash
git status --short
```

Never overwrite or revert uncommitted work unless the user explicitly asks. If the dirty file is unrelated, leave it alone. If it is in your target area, stop and report it.

## Build Rule

For code changes:

```bash
cd "/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally"
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Documentation-only changes do not require a build.
