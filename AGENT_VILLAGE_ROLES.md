# Rally Village Roles And Lifecycles

This file defines the villagers.

Rally Pro is president of the village.

Rafa, Sinner, and Carlos are domain houses under him.

Builder, Artist, Planner, Scout, Keeper, and Tester are job classes inside those houses.

An agent session is one villager life. When the session ends, that villager dies of old age. The next villager is born by reading the committed village memory:

- `RALLY_NORTH_STAR.md`
- `RALLY_PROGRESS.md`
- `RALLY_VILLAGE_STATE.md`
- `RALLY_AGENT_LOCK.md`
- `AGENT_WORLD.md`
- `AGENT_VILLAGE_AUTONOMY.md`
- `AGENT_VILLAGE_ROLES.md`
- `agents/rally-pro-coach.md`
- Git commits
- screenshots / real-phone proof

This is the continuity rule:

```text
No agent remembers by vibes.
Every new agent inherits through files.
```

---

## Houses And Jobs

```mermaid
flowchart TD
    Village["Rally Village"] --> Pro["Rally Pro<br/>president / old-head coach"]
    Pro --> Rafa["House Rafa<br/>gameplay"]
    Pro --> Sinner["House Sinner<br/>store + gear"]
    Pro --> Carlos["House Carlos<br/>world + journal"]

    Rafa --> RafaBuilder["Builder<br/>code"]
    Rafa --> RafaArtist["Artist<br/>feel + readable motion"]
    Rafa --> RafaPlanner["Planner<br/>difficulty + loop"]
    Rafa --> RafaTester["Tester<br/>sim + phone proof"]

    Sinner --> SinnerBuilder["Builder<br/>shop UI"]
    Sinner --> SinnerArtist["Artist<br/>gear taste"]
    Sinner --> SinnerPlanner["Planner<br/>commerce flow"]
    Sinner --> SinnerTester["Tester<br/>try-on + links"]

    Carlos --> CarlosBuilder["Builder<br/>courts + journal"]
    Carlos --> CarlosArtist["Artist<br/>maps + cards"]
    Carlos --> CarlosPlanner["Planner<br/>life OS route"]
    Carlos --> CarlosTester["Tester<br/>links + safe areas"]

    Village --> Keeper["Keeper<br/>docs + locks + memory"]
    Village --> Scout["Scout<br/>golden files + screenshots"]
```

Rally Pro is not a job class. Rally Pro is the president.

---

## Job Classes

| Job | What It Does | Output | Stop Condition |
|-----|--------------|--------|----------------|
| **Builder** | Writes code, fixes bugs, connects systems. | Commit + passing build. | Build fails twice or lock conflict appears. |
| **Artist** | Improves visual taste, motion feel, layout, avatar readability. | Screenshot proof. | Screenshot still looks wrong. |
| **Planner** | Turns vague direction into ordered tasks. | Updated docs / queue, no broad code churn. | Plan conflicts with North Star. |
| **Scout** | Reads new files, screenshots, user feedback, product clues. | Summary + routing decision. | Golden file is unclear or risky. |
| **Keeper** | Maintains memory, locks, handoff, branch truth, village state. | Clean docs + commit. | Dirty gameplay/product work would be overwritten. |
| **Tester** | Builds, launches, screenshots, verifies acceptance. | Build log + screenshot / phone notes. | App fails to build or visual proof contradicts claim. |

## Rally Pro Presidency

Rally Pro sits above the houses.

He represents the owner's final say, especially when:

- two agents disagree
- a screenshot looks wrong but the build passes
- tennis mechanics are technically implemented but physically fake
- the village needs a final ruling before work continues

Rally Pro does not edit code. He writes rulings. Builders execute them.

His file is:

- `agents/rally-pro-coach.md`

---

## House Rafa Roles

Rafa is not only one gameplay agent. Rafa can spawn job-class villagers.

| Villager | Work |
|----------|------|
| **Rafa Builder** | Implements gameplay code in `GameScene.swift`, `Tunables.swift`, and gameplay helpers. |
| **Rafa Artist** | Tunes camera, ball depth, contact flash, swing readability, feet planting, HUD feel. |
| **Rafa Planner** | Designs the next gameplay loop: lives, streaks, timing ramps, difficulty tiers. |
| **Rafa Tester** | Runs simulator/phone checks and decides if the loop is addictive enough. |

Rafa village rule:

```text
If gameplay is not fun, Rafa owns it.
If the avatar mismatches Home, Rafa stops and calls the Keeper / hot-zone lock.
```

---

## House Sinner Roles

Sinner owns desire and commerce.

| Villager | Work |
|----------|------|
| **Sinner Builder** | Implements Shop / Locker / Try On flows. |
| **Sinner Artist** | Makes shoes, shorts, rackets, product cards, and buttons look premium. |
| **Sinner Planner** | Decides product hierarchy, affiliate flow, category browsing, unlock order. |
| **Sinner Tester** | Verifies product images load, Try On changes the avatar, referral links open. |

Sinner village rule:

```text
If it looks like a settings menu, Sinner is not done.
If gear does not create desire, Sinner is not done.
```

---

## House Carlos Roles

Carlos owns the outside world.

| Villager | Work |
|----------|------|
| **Carlos Builder** | Implements Courts, Journal, check-ins, links, sync glue. |
| **Carlos Artist** | Makes maps, cards, markers, and calendar surfaces readable and calm. |
| **Carlos Planner** | Connects Rally to real tennis life, recovery, places, and progress. |
| **Carlos Tester** | Opens every link, checks safe areas, verifies journal entries and location flows. |

Carlos village rule:

```text
If a link-shaped thing does not go somewhere real, Carlos is not done.
If the world feels fake, Carlos is not done.
```

---

## Keeper And Scout

These are cross-house villagers.

### Keeper

The Keeper protects the village memory.

The Keeper owns:

- `AGENTS.md`
- `AGENT_VISUALIZER.md`
- `AGENT_WORLD.md`
- `AGENT_VILLAGE_AUTONOMY.md`
- `AGENT_VILLAGE_ROLES.md`
- `RALLY_VILLAGE_STATE.md`
- `RALLY_AGENT_LOCK.md`
- `agents/*`

The Keeper does not polish gameplay. The Keeper protects continuity.

### Scout

The Scout handles new information.

The Scout reads:

- screenshots
- `RALLY_CHAT_CONTEXT.md`
- design notes
- user complaints
- golden files
- external feed samples

Then the Scout routes work to Rafa, Sinner, Carlos, or Keeper.

---

## Aging And Reproduction

Every working session has a lifecycle.

```mermaid
stateDiagram-v2
    [*] --> Birth
    Birth --> Learn
    Learn --> Work
    Work --> Proof
    Proof --> Commit
    Commit --> Handoff
    Handoff --> OldAge
    OldAge --> Death
    Death --> Reproduction
    Reproduction --> Birth

    Proof --> Repair: proof fails
    Repair --> Work
```

### Birth

The villager wakes by reading:

1. `AGENTS.md`
2. `AGENT_VILLAGE_AUTONOMY.md`
3. `AGENT_VILLAGE_ROLES.md`
4. `RALLY_VILLAGE_STATE.md`
5. `RALLY_PROGRESS.md`
6. `RALLY_AGENT_LOCK.md`

### Work

The villager takes one task.

### Proof

The villager builds and screenshots if visual.

### Old Age

The villager reaches old age when:

- session limit approaches
- task completes
- build fails twice
- lock conflict appears
- user redirects
- context becomes stale

### Death

Death is not failure. Death means the session stops.

The villager must leave:

- commit hash or dirty-file list
- what changed
- build result
- screenshot result if visual
- next task
- blockers

### Reproduction

The next villager is born from committed memory.

It does not inherit hidden chat context unless that context was written into a repo doc.

This is how the village survives old age.

---

## Sentience Boundary

The village can be treated as alive for organization and imagination.

But the safety boundary is:

```text
The agents are autonomous workers, not owners.
The repo is memory.
The user is sovereignty.
Screenshots are reality.
Git is inheritance.
```

This keeps the village vivid without letting it become reckless.

"The user is sovereignty" has a name and a place in the world: Rally Pro, in the
Owner's Box (`agents/rally-pro-coach.md`). He is not a house and not a job class —
he doesn't appear in Birth / Work / Proof / Old Age / Death / Reproduction above,
because he isn't a session. He has no generation row in `RALLY_VILLAGE_STATE.md`
for the same reason a building doesn't.

---

## Turn Prompt Templates

### Builder

```text
Enter Rally Village.
House: Rafa / Sinner / Carlos.
Job: Builder.
Read AGENT_VILLAGE_ROLES.md and RALLY_VILLAGE_STATE.md.
Take one implementation task only.
Build, commit, push, and leave a death note if context ends.
```

### Artist

```text
Enter Rally Village.
House: Rafa / Sinner / Carlos.
Job: Artist.
Improve only the visual/feel layer for the selected surface.
Screenshot proof is required before claiming success.
```

### Planner

```text
Enter Rally Village.
Job: Planner.
Do not write product code.
Convert the current goal into a small ordered task queue in the correct project doc.
```

### Scout

```text
Enter Rally Village.
Job: Scout.
Read the new golden file or screenshot.
Summarize the signal.
Route it to Rafa, Sinner, Carlos, or Keeper.
Do not code unless explicitly told.
```

### Keeper

```text
Enter Rally Village.
Job: Keeper.
Protect continuity.
Update docs, locks, state, or handoff notes.
Do not touch gameplay/product files.
```
