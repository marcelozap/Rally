# Rally Agent Visualizer

This file is the map of who is working on Rally, what they own, what guards them, and how Claude Code and Codex should cooperate.

Use it when the project feels noisy. It is a visual index, not a replacement for the rules.

For the more immersive "little world" view of the agents, read `AGENT_WORLD.md`.

For the autonomous Clash-style builder village, read `AGENT_VILLAGE_AUTONOMY.md`.

Source of truth order still comes from `AGENTS.md`:

1. `RALLY_NORTH_STAR.md`
2. `RALLY_REPO_GUARD.md`
3. `RALLY_AGENT_LOCK.md`
4. `agents/*`
5. `CLAUDE_CODE_PARALLEL_PLAN.md`
6. `RALLY_OVERHAUL_DIRECTIVE.md`

---

## Current Operating Picture

```mermaid
flowchart TD
    User["Marcelo / Product Direction"] --> NorthStar["RALLY_NORTH_STAR.md<br/>vision + priorities"]
    User --> WorldDoc["AGENT_WORLD.md<br/>agent rooms + rituals"]
    User --> VillageDoc["AGENT_VILLAGE_AUTONOMY.md<br/>builder huts + sync tower"]
    NorthStar --> Progress["RALLY_PROGRESS.md<br/>backlog + session log"]
    NorthStar --> Agents["AGENTS.md<br/>boot file"]
    Agents --> Guard["RALLY_REPO_GUARD.md<br/>canonical repo safety"]
    Agents --> Lock["RALLY_AGENT_LOCK.md<br/>hot-zone locks"]
    Agents --> AgentDocs["agents/<br/>lane manuals"]
    AgentDocs --> Rafa["Rafa<br/>gameplay feel"]
    AgentDocs --> Sinner["Sinner<br/>shop + locker"]
    AgentDocs --> Carlos["Carlos<br/>world + courts"]
    WorldDoc --> Rafa
    WorldDoc --> Sinner
    WorldDoc --> Carlos
    VillageDoc --> Progress
    VillageDoc --> Lock

    Codex["Codex / CX<br/>this app"] --> AgentDocs
    Claude["Claude Code / CC<br/>local Claude app"] --> ClaudeHooks[".claude/hooks<br/>mechanical guards"]
    ClaudeHooks --> Guard
    ClaudeHooks --> Lock

    Rafa --> Game["Rally/Game/*<br/>GameScene, Tunables, helpers"]
    Sinner --> Shop["Shop + Locker<br/>gear, catalog, referral UI"]
    Carlos --> World["Courts + Journal<br/>venues, links, activity"]
```

---

## Agent Roster

| Name | Surface | Primary Mission | Primary Files | Must Not Do |
|------|---------|-----------------|---------------|-------------|
| **Rafa** | Gameplay | Make wall rally addictive, physical, readable, and fair. | `Rally/Game/GameScene.swift`, `Rally/Game/Tunables.swift`, `Rally/Game/*`, gameplay audio/haptics | Add visual clutter, break Home/gameplay avatar identity, edit Shop/World without explicit override |
| **Sinner** | Store / Locker | Make gear selection and real-merch browsing feel premium and easy. | `Rally/Features/Shop/*`, `Rally/Services/RallyGearItem.swift`, `Rally/Services/RallyReferralCatalog.swift`, `Rally/Services/RallyReferralLinkRouter.swift` | Touch gameplay tuning or courts logic |
| **Carlos** | World / Courts | Make venues, links, court unlocks, and training-life surfaces trustworthy. | `Rally/Features/Courts/*`, `Rally/Features/Journal/*`, `Rally/Data/IconicCourtsCatalog.swift` | Rename actions dishonestly, show dead links, pile markers over cards |
| **Codex / CX** | Execution lane | Fast repo edits, builds, simulator screenshots, visual craft passes. | Any lane after declaring the hat; normally Home, Avatar, Shop, docs | Ignore locks, overwrite uncommitted work, use stale repo copies |
| **Claude Code / CC** | Execution lane | Local-machine execution with hooks; historically gameplay/journal/courts. | Game, Journal, Courts, backend, audio/haptics | Cross into CX-only files unless user explicitly overrides |

Named agents are roles. Codex or Claude can wear a role, but the active role must be stated before editing.

---

## Safety Hooks And Guards

```mermaid
flowchart LR
    Start["Agent session starts"] --> Handshake["agents/session-handshake.md<br/>pwd, branch, status"]
    Handshake --> RepoOK{"Repo is<br/>/Users/a14/Desktop/Rally<br/>on rally/dev?"}
    RepoOK -- "no" --> Stop["STOP<br/>wrong copy"]
    RepoOK -- "yes" --> Dirty["git status"]
    Dirty --> Locks["Read RALLY_AGENT_LOCK.md"]
    Locks --> Hot{"Target file is<br/>hot zone or locked?"}
    Hot -- "yes" --> Claim["Claim lock first<br/>commit + push [lock]"]
    Hot -- "no" --> Work["Do one task"]
    Claim --> Work
    Work --> Build["Build if code changed"]
    Build --> Shot["Screenshot if visual"]
    Shot --> Commit["Commit + push"]
    Commit --> Progress["Update RALLY_PROGRESS.md"]
```

### Claude Code Hook Coverage

| Hook | File | What It Does |
|------|------|--------------|
| Session start | `.claude/hooks/session-start.sh` | Injects repo path, branch, last commit, dirty status, and lock reminders into Claude Code context. |
| Edit guard | `.claude/hooks/guard-edit.sh` | Blocks writes outside `/Users/a14/Desktop/Rally`; blocks Claude from editing unambiguous CX files without override. |
| Bash guard | `.claude/hooks/guard-bash.sh` | Blocks destructive git commands such as `git reset --hard`, `git checkout -- .`, and `git clean -fd`. |

Codex does not automatically execute Claude hooks. For Codex, the protection is the markdown protocol plus the assistant obeying it.

---

## File Ownership Map

```mermaid
flowchart TB
    subgraph Rafa["Rafa Gameplay"]
      G1["Rally/Game/GameScene.swift"]
      G2["Rally/Game/Tunables.swift"]
      G3["Rally/Game/* helpers"]
      G4["Audio/Haptics when tied to hits"]
    end

    subgraph Sinner["Sinner Store"]
      S1["Rally/Features/Shop/ShopView.swift"]
      S2["Rally/Features/Shop/LockerHubView.swift"]
      S3["Rally/Features/Shop/ShopItemDetailView.swift"]
      S4["Rally/Services/RallyReferralCatalog.swift"]
      S5["Rally/Services/RallyGearItem.swift"]
    end

    subgraph Carlos["Carlos World"]
      C1["Rally/Features/Courts/*"]
      C2["Rally/Features/Journal/*"]
      C3["Rally/Data/IconicCourtsCatalog.swift"]
      C4["backend sync/live-ops when needed"]
    end

    subgraph Hot["Shared Hot Zones"]
      H1["RallyAvatarGeometry.swift"]
      H2["RallyAvatarView.swift"]
      H3["RallyAvatarAppearance.swift"]
      H4["GameSessionView.swift"]
      H5["Rally.xcodeproj/project.pbxproj"]
      H6["RALLY_PROGRESS.md"]
    end

    Rafa --> Hot
    Sinner --> Hot
    Carlos --> Hot
```

Hot zones require extra caution. If the file is in the hot-zone box, read `RALLY_AGENT_LOCK.md` before editing.

---

## Collaboration Contract

```mermaid
sequenceDiagram
    participant User as Marcelo
    participant CX as Codex / CX
    participant CC as Claude Code / CC
    participant Git as GitHub rally/dev

    User->>CX: "Work as Rafa/Sinner/Carlos"
    CX->>Git: pull + status
    CX->>CX: read AGENTS + locks + priority
    CX->>Git: claim lock if hot zone
    CX->>CX: implement one focused task
    CX->>CX: build + screenshot if visual
    CX->>Git: commit + push
    CX->>User: report result + next risk

    User->>CC: "continue"
    CC->>CC: .claude SessionStart hook runs
    CC->>Git: pull + status
    CC->>CC: guard hooks block bad edits/commands
    CC->>Git: commit + push
```

Rules:

- One agent takes one task at a time.
- One commit should represent one coherent change.
- Visual claims need screenshots.
- Gameplay claims need simulator or real-phone confirmation.
- If Home avatar and gameplay avatar diverge, stop polishing and fix identity first.

---

## Current High-Level Priority

As of the current docs, Rally is in **Rafa Gameplay mode**.

Focus:

1. Make wall rally addictive and readable.
2. Preserve avatar identity between Home and gameplay.
3. Build and test on a real iPhone.
4. Do not start large new Shop, World, or Journal features until the gameplay loop feels good.

Protected active edits are listed in `agents/current-priority.md`.
