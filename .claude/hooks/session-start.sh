#!/bin/bash
# SessionStart hook -- mechanizes agents/session-handshake.md.
#
# SessionStart hooks cannot block (no permissionDecision); they can only inject
# additionalContext into the start of the conversation. Keep this compact: every
# extra line is paid for on every Claude Code session. Detailed rules live in
# agents/credit-saving.md, RALLY_AGENT_LOCK.md, and agents/lanes.md.
#
# Phrased as factual statements, not imperatives, per hooks docs guidance (avoids
# tripping prompt-injection defenses that would surface this back to the user
# instead of just being read as context).

set -u

REPO="/Users/a14/Desktop/Rally"
cd "$REPO" 2>/dev/null || {
  python3 -c '
import json
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "RALLY_REPO_GUARD.md handshake: could not cd into /Users/a14/Desktop/Rally. This session is not rooted in the canonical Rally repo -- do not edit, build, or commit Rally files from here without confirming the correct path first."
    }
}))
'
  exit 0
}

PWD_OUT="$(pwd)"
TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null || echo "(not a git repo)")"
BRANCH="$(git branch --show-current 2>/dev/null || echo "(unknown)")"
LAST_COMMIT="$(git log --oneline -1 2>/dev/null || echo "(no commits found)")"
DIRTY="$(git status --short 2>/dev/null | head -8 || true)"
if [ -z "$DIRTY" ]; then
  DIRTY="clean"
fi

ACTIVE_LOCKS="$(awk '
  /^## ACTIVE LOCKS/ { in_locks=1; next }
  /^---$/ && in_locks { exit }
  in_locks && /^\| 20/ && $0 !~ /RELEASED/ { print }
' RALLY_AGENT_LOCK.md 2>/dev/null | head -4)"
if [ -z "$ACTIVE_LOCKS" ]; then
  ACTIVE_LOCKS="none"
fi

PATH_OK="yes"
if [ "$PWD_OUT" != "$REPO" ] || [ "$TOPLEVEL" != "$REPO" ]; then
  PATH_OK="no"
fi

CONTEXT="Rally fast session-start:
- cwd: $PWD_OUT
- git toplevel: $TOPLEVEL
- canonical path match: $PATH_OK (expected /Users/a14/Desktop/Rally)
- branch: $BRANCH
- last commit: $LAST_COMMIT
- dirty files (first 8): $DIRTY
- active locks: $ACTIVE_LOCKS

Read agents/credit-saving.md before broad discovery. Use scripts/rally_agent_fast_status.sh for a compact board. Check RALLY_AGENT_LOCK.md before hot-zone edits. Destructive git commands remain blocked by guard-bash.sh."

python3 - "$CONTEXT" << 'PYEOF'
import json, sys
ctx = sys.argv[1]
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": ctx
    }
}))
PYEOF
