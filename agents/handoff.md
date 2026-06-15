# Handoff Protocol

Use this whenever one agent stops and another continues.

## Required Handoff Note

```text
Path:
Branch:
Last commit:
Dirty files:
Files intentionally left untouched:
What changed:
Build result:
Simulator result:
Next recommended task:
Known risks:
```

## Stop Conditions

Stop and hand off instead of forcing progress when:

- build fails after two repair attempts
- target files are locked by the other agent
- simulator screenshot contradicts the code claim
- the repo path is not `/Users/a14/Desktop/Rally`
- the task requires App Store, Garmin, affiliate, or GitHub credentials not available to the agent

## Progress Ledger

`RALLY_PROGRESS.md` is append-first. Do not rewrite another agent's log.

When completing a task:

1. Check the related box if it is truly done.
2. Add one short session log line with date, task id, commit hash, and note.
3. If visual QA is still needed, say `VERIFY` instead of marking complete.

## Screenshot Rule

For visual work, take or request screenshots of:

- Home / Loadout
- gameplay after PLAY
- Shop card grid
- Shop detail
- World / Courts if changed

If screenshots look wrong, prioritize the screenshot over the implementation claim.
