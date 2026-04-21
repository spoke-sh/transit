# INSTRUCTIONS.md

Procedural instructions and workflow guidance for agents and operators working with transit.

## The Turn Loop

Transit uses Keel as its project management engine. Your job is to move the board through the canonical `Orient -> Inspect -> Pull -> Ship -> Close` loop while eliminating drift.

`just keel turn` is the canonical reference surface for this rhythm. Every session follows this deterministic cycle:

1.  **Orient**: Run `just keel heartbeat`, `just keel health --scene`, `just keel flow --scene`, and `just keel doctor`. This tells you whether the board is energized, healthy, and structurally coherent.
2.  **Inspect**: Run `just keel mission next --status` and `just keel pulse`. If routing is unclear, inspect `just keel roles` or `just keel next --role <role> --explain`.
3.  **Pull**: Choose the correct lane and role (`manager`, `operator`, or a configured role family) and pull exactly ONE slice of work.
4.  **Ship**: Execute the move, record proof while the work is fresh, and land the relevant lifecycle transition (`story submit`, `voyage plan`, `bearing lay`, etc.).
5.  **Close**:
    - Record your move in the mission `LOG.md`.
    - **Heartbeat Check**: Use `just keel heartbeat` if you need to inspect the current activity source or confirm the circuit is still energized before the commit boundary.
    - **Commit**: Execute `git commit`. The installed hooks automatically run `just quality`, `just test`, and `keel health`, then append `doctor --status` to the commit message. Resolve any issues if the commit is rejected.
6.  **Re-orient**: After the commit lands, run `just keel doctor --status` and `just keel flow` to see what the board needs next.
 This is the "plug the cord back in" moment. If the delivery lane has ready work, start the next turn immediately. Only stop to ask the human when you reach a manual lane (design direction, bearing assessment, or human verification).

## Primary Workflows

### Operator (Implementation)
Focus on **evidence-backed delivery**.
- **Context**: `just keel story show <id>`, `just keel voyage show <id>`, and `just keel next --role operator`.
- **Action**: Implement requirements, record proofs with `keel story record`, and `submit`.
- **Constraint**: Every AC must have a proof.

### Manager (Planning)
Focus on **strategic alignment and unblocking**.
- **Context**: `just keel epic show <id>`, `just keel roles`, `just keel next --role manager --explain`, and `just keel flow`.
- **Action**: Author `PRD.md`, `SRS.md`, `SDD.md`, resolve routing, decompose stories, and attach mission children explicitly with `just keel mission attach <mission-id> --epic <epic-id>`, `--bearing <bearing-id>`, or `--adr <adr-id>`.
- **Constraint**: Move voyages from `draft` to `planned` only when requirements are coherent.

### Explorer (Research)
Focus on **technical discovery and fog reduction**.
- **Context**: `just keel bearing list`.
- **Action**: Fill `BRIEF.md`, collect `EVIDENCE.md`, and `assess`.
- **Constraint**: Graduate to epics only when research is conclusive.

## Human Interaction & Pokes

Keel's autonomous flow is governed by a physical battery metaphor, but the charge is now derived from real repository activity rather than a synthetic wake file.

If a human user pokes you (e.g., "I'm poking you", "Wake up"), you MUST:
1.  **Heartbeat**: Execute `just keel heartbeat` to inspect current charge and whether the worktree is carrying uncommitted energy.
2.  **Pulse**: Run `just keel health --scene` to check subsystem stability.
3.  **Scan**: Run `just keel mission next --status` and `just keel pulse` to identify any new work that has become ready or materialized.
4.  **Confirm**: Run `just keel flow --scene` to verify whether the light is ON or whether the board is idle waiting for a real move.
5.  **Diagnose**: Run `just keel doctor` to ensure board integrity before proceeding.

## Autonomous Backlog Discharge

As long as the system is **AUTONOMOUS (LIGHT ON)** and the circuit is healthy (no blown capacitors), you are responsible for discharging the delivery backlog.

1.  **Identify Ready Work**: Scan the delivery lane for stories in `backlog` that are not blocked by dependencies.
2.  **Autonomous Start**: For each ready story, execute `just keel story start <id>`.
3.  **Rube Goldberg Loop**: Transitioning a story to `in-progress` mutates the repository, which refreshes the derived heartbeat and keeps the circuit closed while you continue moving work.
4.  **Priority**: Discharging the backlog is your primary tactical objective once energized. You must continue until the backlog is empty or the circuit trips.
5.  **Loop Closure**: After every successful implementation or transition, you MUST land a sealing commit that captures the resulting board and code changes. This applies to ALL work, including storyless gardening or engine changes. The pacemaker warning is cleared by committing the dirty worktree, not by touching a synthetic heartbeat file.

## Global Hygiene Checklist

Apply these checks to **every change** before finalizing work:

1. **Doctor First**: `just keel doctor` is the ultimate source of truth for board integrity. You MUST run the doctor at the start of every session. If the doctor reports errors or "Short Circuits", you MUST prioritize fixing those diagnostic orders before attempting any other work or architectural changes.
2. **The Health Loop**: Use `just keel health --scene` for high-level triage. Subsystems are mapped as follows:
   - **NEURAL**: Stories (ID consistency, AC completion)
   - **MOTOR**: Voyages (Structure, SRS/SDD authorship)
   - **STRATEGIC**: Epics (PRD, Goal lineage)
   - **SENSORY**: Bearings (Research, Evidence quality)
   - **SKELETAL**: ADRs (Architecture decisions)
   - **VITAL**: Missions (Strategic achievement)
   - **AUTONOMIC**: Routines (Cadence, materialization)
   - **CIRCULATORY**: Workflow (Graph integrity, topology)
   - **PACEMAKER**: Heartbeat (derived repository activity and open-loop warning state)
   - **KINETIC**: Delivery (Backlog liquidity, execution capacity)
3. **Pacemaker Protocol**: The system's heartbeat is derived from Git/worktree activity and inspected with `just keel heartbeat`. A clean repo falls back to the latest commit; a dirty repo uses the freshest changed path it can observe. `doctor` warns when the worktree carries uncommitted energy, and the sealing commit is what clears that warning. The installed pre-commit hook keeps quality checks, tests, and `keel health` tied to the commit boundary, and the commit-msg hook appends `doctor --status` to the message body.
4. **Gardening First**: You MUST tend to the garden (fixing `doctor` errors, discharging automated backlog, and resolving structural drift) BEFORE notifying the human operator or requesting input.
5. **Notification Threshold**: Only request human intervention when you reach a "Manual Lane" that requires design direction or a decision on application behavior (e.g., assessing a Bearing, planning a Voyage, or human verification of a complex Story).
6. **Automated Guardrails**: You no longer need to run `just quality` or `just test` manually before every commit. The git hooks installed via `just keel hooks install` automatically enforce those checks, run `keel health`, and append `doctor --status` to the commit message body. If a commit fails, resolve the reported lints or test failures and try again.
7. **Lifecycle Before Commit**: Run board-mutating lifecycle commands before the atomic commit when they generate or rewrite `.keel` artifacts (for example `just keel story submit`, `just keel voyage plan`, `just keel voyage done`, `just keel bearing assess`, `just keel bearing lay`). After the transition, inspect `git status` and include the resulting `.keel` churn in the same commit.
8. **Atomic Commits**: Commit once per logical unit of work. Use [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat:` (new feature)
   - `fix:` (bug fix)
   - `docs:` (documentation)
   - `refactor:` (code change, no behavior change)
   - `test:` (adding/updating tests)
   - `chore:` (build/tooling)
9. **Mission Loop Discipline**: For mission-driven work, return to the mission steward loop after every completed story, planning unit, or bearing instead of continuing ad hoc from the last worker context.
10. **Knowledge Quality Bar**: Prefer no new knowledge over low-signal knowledge. A new knowledge entry should be novel, reusable across stories, and materially reduce future drift; otherwise link existing knowledge or omit capture entirely.

## Compatibility Policy (Hard Cutover)

At this stage of development, this repository uses a **hard cutover** policy by default.

1. **No Backward Compatibility by Default**: Do not add compatibility aliases, dual-write logic, soft-deprecated schema fields, or fallback parsing for legacy formats unless a story explicitly requires it.
2. **Replace, Don't Bridge**: When introducing a new canonical token, field, command behavior, or document contract, remove the old path in the same change slice.
3. **Fail Fast in Validation**: `keel doctor` and transition gates should treat legacy or unfilled scaffold patterns as hard failures when they violate the new contract.
4. **Single Canonical Path**: Keep one source of truth for rendering, parsing, and validation; avoid parallel implementations meant only to preserve old behavior.
5. **Migration Is Explicit Work**: If existing board artifacts need updates, handle that in a dedicated migration pass/story instead of embedding runtime compatibility logic.

## Commands

### Command Execution Model

Use one path for each concern:

- `nix develop` for the repository shell and shared tooling.
- `just ...` for repo build, test, proof, and helper workflows.
- `just keel ...` for all board and workflow operations.

### `just` Workflow Commands

| Command | Purpose |
|---------|---------|
| `just` | List available recipes |
| `just screen` | Default human proof path (local, tiered, networked, integrity, materialization, board) |
| `just rust-client-proof` | Run the native Rust client proof example against a local transit server |
| `just quality` | Formatting and clippy checks |
| `just test` | Workspace tests |
| `just doctest` | Run doc tests |
| `just coverage` | Produce coverage output |

### `just keel` Board Workflow Commands

Run `just keel --help` for the full command tree. The core commands you should rely on:

| Category | Commands |
|----------|----------|
| Orientation | `just keel turn` `just keel heartbeat` `just keel health --scene` `just keel flow --scene` `just keel doctor` `just keel screen --static` |
| Inspection | `just keel mission next [<id>]` `just keel pulse` `just keel roles` `just keel workshop` `just keel next --role <role> --explain` |
| Discovery | `just keel bearing new <name>` `just keel bearing research <id>` `just keel bearing assess <id>` `just keel bearing list` |
| Planning | `just keel epic new "<name>" --problem "<problem>"` `just keel voyage new "<name>" --epic <epic-id> --goal "<goal>"` |
| Execution | `just keel story new "<title>" [--type <type>] [--epic <epic-id> [--voyage <voyage-id>]]` |
| Board Ops | `just keel mission next [<id>]` `just keel next --role manager` `just keel next --role operator` `just keel flow` `just keel doctor` `just keel generate` `just keel config show` `just keel mission show <id>` `just keel mission attach <mission-id> --epic <epic-id>` |
| Lifecycle | Story/voyage/epic transitions in the table below |

## Story and Milestone State Changes

Use CLI commands only. Do not move `.keel` files manually.

| Action | Command |
|--------|---------|
| Start | `just keel story start <id>` |
| Reflect | `just keel story reflect <id>` |
| Submit | `just keel story submit <id>` |
| Reject | `just keel story reject <id> "reason"` |
| Accept | `just keel story accept <id> --role manager` |
| Ice | `just keel story ice <id>` |
| Thaw | `just keel story thaw <id>` |
| Voyage plan | `just keel voyage plan <id>` |
| Voyage done | `just keel voyage done <id>` |
| Bearing assess | `just keel bearing assess <id>` |
| Bearing lay | `just keel bearing lay <id>` |
| Mission activate | `just keel mission activate <id>` |
| Mission achieve | `just keel mission achieve <id>` |
| Mission verify | `just keel mission verify <id>` |
