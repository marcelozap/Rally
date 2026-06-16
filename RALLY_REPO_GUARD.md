# RALLY REPO GUARD

This file prevents agents from working in an old or wrong Rally folder.

## Canonical Repo

The only valid Rally project folder is:

```bash
/Users/a14/Desktop/Rally
```

The canonical Xcode project is:

```bash
/Users/a14/Desktop/Rally/Rally.xcodeproj
```

The canonical branch is:

```bash
rally/dev
```

The canonical remote is:

```bash
https://github.com/marcelozap/Rally.git
```

## Forbidden Starting Paths

Do not work from any of these paths:

```bash
/Users/a14
/Users/a14/Documents/New project
/Users/a14/mac-trade-dashboard
/Users/a14/mac-trade-dashboard/Rally_STALE_DO_NOT_USE.xcodeproj
```

If a tool opens in any folder except `/Users/a14/Desktop/Rally`, immediately switch to the canonical repo before reading, editing, building, or committing.

## Mandatory First Commands

Every agent session must run these commands before doing any work:

```bash
cd /Users/a14/Desktop/Rally || exit 1
pwd
git rev-parse --show-toplevel
git branch --show-current
git log --oneline -1
git status --short
```

Expected output:

```bash
/Users/a14/Desktop/Rally
/Users/a14/Desktop/Rally
rally/dev
```

If `pwd` or `git rev-parse --show-toplevel` is anything other than `/Users/a14/Desktop/Rally`, stop and report:

```text
STOP: wrong Rally folder. I am not editing because this is not /Users/a14/Desktop/Rally.
```

## Claude Folder Picker

When Claude asks to "Use an existing folder", choose:

```text
Macintosh HD -> Users -> a14 -> Desktop -> Rally
```

Do not choose:

```text
Macintosh HD -> Users -> a14
Macintosh HD -> Users -> a14 -> Documents -> New project
Any folder named Rally outside Desktop/Rally
```

## Current Standing Request

The user's standing request is:

```text
Never open, edit, build, commit, or reason from an old Rally copy again.
Before any Rally work, prove the path is /Users/a14/Desktop/Rally.
If the path is wrong, stop instead of guessing.
```

## Duplicate Repo Policy

If another Rally copy is found:

1. List its full path.
2. List its newest modified file date.
3. Do not rename, delete, merge, or copy from it without user confirmation.
4. Do not use it as context unless the user explicitly says it contains newer work.

## Git Safety

Before edits:

```bash
git status --short
```

If there are uncommitted changes, report them before editing.

Do not run destructive commands such as:

```bash
git reset --hard
git checkout -- .
git clean -fd
```

unless the user explicitly asks for them.

## Build Rule

For code changes, build from the canonical repo only:

```bash
cd /Users/a14/Desktop/Rally
xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Documentation-only changes do not require a build.
