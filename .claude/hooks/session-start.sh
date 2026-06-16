#!/bin/bash
# SessionStart hook -- mechanizes agents/session-handshake.md.
#
# SessionStart hooks cannot block (no permissionDecision); they can only inject
# additionalContext into the start of the conversation. So this runs the mandatory
# handshake commands and surfaces the result, plus a standing reminder of the
# lane/lock files that guard-edit.sh deliberately does NOT hard-block (because
# they're ambiguous at the file level -- see guard-edit.sh's header comment).
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
STATUS="$(git status --short --branch 2>/dev/null || echo "(git status unavailable)")"

PATH_OK="yes"
if [ "$PWD_OUT" != "$REPO" ] || [ "$TOPLEVEL" != "$REPO" ]; then
  PATH_OK="no"
fi

CONTEXT="Rally session-start handshake (agents/session-handshake.md):
- cwd: $PWD_OUT
- git toplevel: $TOPLEVEL
- canonical path match: $PATH_OK (expected /Users/a14/Desktop/Rally for both)
- branch: $BRANCH
- last commit: $LAST_COMMIT
- git status --short --branch:
$STATUS

Standing reminders from RALLY_AGENT_LOCK.md and agents/lanes.md:
- guard-edit.sh hard-blocks writes outside the canonical repo and writes to files that are unambiguously CX (Codex/Cursor) lane.
- guard-edit.sh does NOT block these shared/ambiguous files, since they are legitimate CC files most of the time -- check RALLY_AGENT_LOCK.md's ACTIVE LOCKS table before editing them: Rally/Game/GameScene.swift (avatar-assembly block specifically), Rally/Features/Avatar/RallyAvatarAppearance.swift, Rally/Features/Avatar/RallyAvatarPartRenderer.swift, Rally/Features/Play/GameSessionView.swift, RALLY_PROGRESS.md (append-only, never rewrite another agent's rows), Rally.xcodeproj/project.pbxproj.
- guard-bash.sh hard-blocks git reset --hard, git checkout -- ., and git clean -fd/-fdx from automated tool calls -- these only run on an explicit user ask in this turn.
- These hooks only govern this Claude Code session. They are not read or enforced by Codex/Cursor (CX) -- the markdown docs remain the source of truth for that tool."

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
