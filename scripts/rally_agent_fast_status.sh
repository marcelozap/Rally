#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/a14/Desktop/Rally"
cd "$ROOT"

echo "Rally fast status"
echo "path:   $(pwd)"
echo "branch: $(git branch --show-current)"
echo "head:   $(git log --oneline -1)"

dirty="$(git status --short)"
if [[ -z "$dirty" ]]; then
  echo "dirty:  clean"
else
  echo "dirty:"
  printf "%s\n" "$dirty" | sed 's/^/  /'
fi

active_locks="$(
  awk '
    /^## ACTIVE LOCKS/ { in_locks=1; next }
    /^---$/ && in_locks { exit }
    in_locks && /^\| 20/ && $0 !~ /RELEASED/ { print }
  ' RALLY_AGENT_LOCK.md
)"

if [[ -z "$active_locks" ]]; then
  echo "locks:  none"
else
  echo "locks:"
  printf "%s\n" "$active_locks" | sed 's/^/  /'
fi

echo "priority:"
awk '
  /^## Current Priority Order/ { capture=1; next }
  capture && /^## / { exit }
  capture && /^[0-9]+\./ && count < 3 { print "  " $0; count++ }
' RALLY_NORTH_STAR.md

echo "active:"
awk '
  /^### T/ { task=$0 }
  /← ACTIVE/ { print "  " task }
' RALLY_PROGRESS.md
