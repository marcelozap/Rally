# Claude Code Hooks

This folder contains Claude Code hook configuration for Rally.

These hooks are the mechanical side of the same agent protocol described in:

- `AGENTS.md`
- `AGENT_VISUALIZER.md`
- `RALLY_REPO_GUARD.md`
- `RALLY_AGENT_LOCK.md`
- `agents/`

## Hooks

- `hooks/session-start.sh` injects the Rally session handshake into Claude Code context.
- `hooks/guard-edit.sh` blocks writes outside `/Users/a14/Desktop/Rally` and blocks unambiguous CX-owned files.
- `hooks/guard-bash.sh` blocks destructive git commands from automated tool calls.

Codex does not execute these hooks. Codex follows the markdown protocol directly.

The shared rule is simple: one canonical repo, one active branch, one lane at a time, one lock for hot zones.

