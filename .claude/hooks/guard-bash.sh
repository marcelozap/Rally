#!/bin/bash
# PreToolUse guard for Bash.
#
# Mechanizes RALLY_REPO_GUARD.md's "Git Safety" section: a small set of destructive
# git commands must never run unless the user explicitly asked for them in this turn.
# A hook can't verify "did the user explicitly ask in this exact turn," so the safe
# mechanical approximation is to always hard-block these from an automated tool call --
# if the user really wants one run, they (or the agent on their direct request) can run
# it manually outside this gate.
#
# Exit 2 + stderr = PreToolUse block (per Claude Code hooks docs).

set -u

INPUT="$(cat)"

CMD="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except Exception:
    print("")
' 2>/dev/null)"

[ -z "$CMD" ] && exit 0

# Normalize whitespace for matching.
NORM="$(printf '%s' "$CMD" | tr -s ' \t' ' ')"

is_blocked=0
case "$NORM" in
  *"git reset --hard"*)   is_blocked=1 ;;
  *"git checkout -- ."*)  is_blocked=1 ;;
  *"git checkout . --"*)  is_blocked=1 ;;
  *"git clean -fd"*)      is_blocked=1 ;;
  *"git clean -fdx"*)     is_blocked=1 ;;
  *"git clean -xfd"*)     is_blocked=1 ;;
esac

if [ "$is_blocked" = "1" ]; then
  echo "STOP (RALLY_REPO_GUARD.md Git Safety): '$CMD' is a destructive git command (reset --hard / checkout -- . / clean -fd). These are never run automatically -- only when the user explicitly asks for them in this turn. Ask the user, or have them run it themselves." >&2
  exit 2
fi

exit 0
