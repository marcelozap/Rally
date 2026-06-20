#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/a14/Desktop/Rally"
cd "$ROOT"

section() {
  printf "\n== %s ==\n" "$1"
}

line_or_empty() {
  local pattern="$1"
  local file="$2"
  grep -E "$pattern" "$file" 2>/dev/null || true
}

section "Rally Repo"
printf "path:   %s\n" "$(pwd)"
printf "branch: %s\n" "$(git branch --show-current)"
printf "head:   %s\n" "$(git log --oneline -1)"
printf "remote: %s\n" "$(git remote get-url origin 2>/dev/null || echo 'none')"

section "Dirty Files"
dirty="$(git status --short)"
if [[ -z "$dirty" ]]; then
  echo "clean"
else
  printf "%s\n" "$dirty"
fi

section "Active Locks"
awk '
  /^## ACTIVE LOCKS/ { in_locks=1; next }
  /^---$/ && in_locks { exit }
  in_locks && /^\| 20/ && $0 !~ /RELEASED/ { print }
' RALLY_AGENT_LOCK.md | sed 's/^/lock: /'
if ! awk '
  /^## ACTIVE LOCKS/ { in_locks=1; next }
  /^---$/ && in_locks { exit }
  in_locks && /^\| 20/ && $0 !~ /RELEASED/ { found=1 }
  END { exit found ? 0 : 1 }
' RALLY_AGENT_LOCK.md; then
  echo "none"
fi

section "Village Board"
awk '
  /^## Current Village State/ { section="state"; next }
  /^## Agent Turn Board/ { section="turn"; next }
  /^## Current Generations/ { section="gen"; next }
  /^## / { section="" }
  section && /^\|/ && $0 !~ /^\|[- ]+\|/ { print }
  /Yellow —/ { print }
' RALLY_VILLAGE_STATE.md

section "North Star Priority"
awk '
  /^## Current Priority Order/ { capture=1; next }
  capture && /^## / { exit }
  capture && NF { print }
' RALLY_NORTH_STAR.md

section "Progress: Active / Open"
awk '
  /^### T/ { task=$0 }
  /← ACTIVE/ { print task }
  /^\- \[ \]/ && open_count < 12 { print "open: " $0; open_count++ }
' RALLY_PROGRESS.md

section "Agent Rooms"
cat <<'ROOMS'
Rally Pro  -> president / final owner-backed ruling
Rafa       -> gameplay, camera, ball, swing, haptics
Sinner     -> shop, locker, gear, try-on, product desire
Carlos     -> world, courts, journal, real tennis life
Keeper     -> docs, locks, memory, repo safety
ROOMS

section "Suggested Next Move"
if [[ -n "$dirty" ]]; then
  echo "Do not start broad work until the dirty files are identified and preserved."
elif grep -q "← ACTIVE" RALLY_PROGRESS.md; then
  echo "Continue the active RALLY_PROGRESS task, respecting locks and lanes."
else
  echo "Take the topmost unchecked RALLY_PROGRESS task that matches the current North Star priority."
fi
