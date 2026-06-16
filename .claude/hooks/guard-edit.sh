#!/bin/bash
# PreToolUse guard for Edit/Write/MultiEdit/NotebookEdit.
#
# Mechanizes two pieces of the markdown protocol (see AGENTS.md / RALLY_REPO_GUARD.md /
# agents/lanes.md) that were previously enforced only by an agent voluntarily reading
# and following them:
#
#   1. RALLY_REPO_GUARD.md  - never write outside the canonical repo.
#   2. agents/lanes.md      - never write a file that is unambiguously CX's lane.
#
# Ambiguous / "shared hot zone" files (RallyAvatarAppearance.swift, GameScene.swift's
# avatar-assembly block, RALLY_PROGRESS.md, GameSessionView.swift, project.pbxproj) are
# deliberately NOT hard-blocked here -- they're real CC files most of the time, and a
# file-level block would also catch ordinary gameplay-tunable edits. Those are instead
# surfaced as a standing reminder via session-start.sh's additionalContext.
#
# Exit 2 + stderr = PreToolUse block (per Claude Code hooks docs).

set -u

INPUT="$(cat)"

FILE_PATH="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    ti = d.get("tool_input", {}) or {}
    print(ti.get("file_path") or ti.get("notebook_path") or "")
except Exception:
    print("")
' 2>/dev/null)"

REPO="/Users/a14/Desktop/Rally"

# Nothing to check (unknown tool_input shape) -- fail open rather than block blind.
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Resolve to an absolute path without requiring the file to already exist.
case "$FILE_PATH" in
  /*) ABS_PATH="$FILE_PATH" ;;
  *)  ABS_PATH="$REPO/$FILE_PATH" ;;
esac

# 1. RALLY_REPO_GUARD.md -- canonical repo only.
case "$ABS_PATH" in
  "$REPO"/*) ;;
  *)
    echo "STOP (RALLY_REPO_GUARD.md): '$ABS_PATH' is outside the canonical repo ($REPO). Never edit, build, or commit from any other Rally copy -- report this to the user instead of guessing." >&2
    exit 2
    ;;
esac

REL="${ABS_PATH#"$REPO"/}"

# 2. agents/lanes.md -- CX-exclusive files. CC must not write these directly.
CX_ONLY_LIST="Rally/Features/Home/HomeView.swift
Rally/Features/Avatar/RallyAvatarGeometry.swift
Rally/Features/Avatar/RallyAvatarView.swift
Rally/Features/Avatar/AvatarCustomizerView.swift
Rally/Features/Shop/AvatarShopStageView.swift
Rally/Features/Shop/ShopView.swift
Rally/Features/Shop/ShopItemDetailView.swift
Rally/Features/Shop/LockerHubView.swift
Rally/Services/RallyGearItem.swift
Rally/Services/RallyReferralCatalog.swift
Rally/Services/RallyReferralLinkRouter.swift"

while IFS= read -r p; do
  [ -z "$p" ] && continue
  if [ "$REL" = "$p" ]; then
    echo "STOP (agents/lanes.md): '$REL' is CX lane (Codex/Cursor), not CC. Surface this to the user and get an explicit override before editing -- do not cross lanes silently." >&2
    exit 2
  fi
done <<EOF
$CX_ONLY_LIST
EOF

exit 0
