# Paste This Into Claude Code

Use this in Claude Code with the repo opened at `/Users/a14/Desktop/Rally`.

```text
SESSION HANDSHAKE FIRST.

Run:
pwd
git pull --ff-only || true
git log --oneline -1
git status --short

If pwd is not /Users/a14/Desktop/Rally, STOP.

Read these files in full before changing code:
- AGENTS.md
- RALLY_NORTH_STAR.md
- RALLY_OVERHAUL_DIRECTIVE.md
- CLAUDE_CODE_PARALLEL_PLAN.md

Then execute Task 1 from CLAUDE_CODE_PARALLEL_PLAN.md only.

Task 1 summary:
Gameplay player credibility pass.

Allowed files only:
- Rally/Game/GameScene.swift
- Rally/Game/Tunables.swift
- Rally/Features/Avatar/RallyAvatarGeometry.swift
- Rally/Features/Avatar/RallyAvatarRebuildDefaults.swift

Do not edit Home, Shop, Journal, Courts, services, project files, screenshots, videos, Artifacts, DerivedData, or docs.

Implement:
1. Feet and legs grounded: no inward feet, clear thighs/knees/calves, shoe shadow under both feet.
2. Body connections clean: hips to legs, shoulders to arms, wrists to hands, torso upright, no diaper pelvis.
3. Face and hair readable from gameplay camera: no bald read, no hostile/scary face.
4. Racket held by the hand, not floating.
5. Forehand/backhand alternation: force both sides; right-handed backhand must be true two-handed backhand, not mirrored forehand.
6. Gameplay top chrome: simple score and exit, no exit on top of score, no heavy top card.

Use named constants in Tunables.swift.
Build after changes:
xcodebuild -scheme Rally -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' -configuration Debug build

If build fails, fix it before reporting.

Commit only the allowed files:
git add Rally/Game/GameScene.swift Rally/Game/Tunables.swift Rally/Features/Avatar/RallyAvatarGeometry.swift Rally/Features/Avatar/RallyAvatarRebuildDefaults.swift
git commit -m "[CC] Gameplay player credibility pass"
git push

Final response must include:
- changed files
- build result
- commit hash
- screenshot path if you captured one
- remaining visible issues, if any
```

