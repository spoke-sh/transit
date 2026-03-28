# AGENTS.md

Shared guidance for AI agents working with this repository.

## Operational Guidance

This repository uses Keel as its project management engine. Your primary responsibility is to execute tactical moves that advance the board state while maintaining 100% integrity.

### Core Principles
1. **Gardening First**: You MUST tend to the garden (fixing `doctor` errors, discharging automated backlog, and resolving structural drift) BEFORE notifying the human operator or requesting input.
2. **Heartbeat Hygiene**: Monitor the system's pulse via `keel pulse`, `keel health --scene`, and `keel flow --scene`. In this pinned Keel build, the wake/charge state is surfaced through `poke` plus the scene commands rather than a standalone `keel heartbeat` command. Uncommitted energy in the worktree is tactical debt that should be closed autonomously by landing the sealing commit.
3. **Notification Discipline**: Ping the human operator ONLY when you need input on design direction or how the application behaves. Resolve technical drift and tactical moves autonomously.

### Canonical Operating Loop
Keel's operator rhythm is still `Orient -> Inspect -> Pull -> Ship -> Close`, but this pinned CLI surfaces it through `poke`, `health`, `pulse`, `flow`, and `doctor` rather than a dedicated `keel turn` command.

- **Orient**: Spark the board when needed with `keel poke "Human interaction in chat"`, then inspect charge and board stability with `keel health --scene`, `keel flow --scene`, and `keel doctor`.
- **Inspect**: Read current demand with `keel mission next --status`, `keel pulse`, and `keel workshop` when a manual lane may be waiting.
- **Pull**: Select one role-scoped slice with `keel next --role <role>`.
- **Ship**: Execute the slice, record proof, and advance lifecycle state.
- **Close**: Land the relevant transition and the sealing commit that clears open-loop energy.

### Session Start & Human Interaction
When a human user opens the chat or "pokes" you (e.g., "Wake up", "I'm poking you"), you MUST immediately energize the system and orient yourself by following the **Human Interaction & Pokes** workflow in [INSTRUCTIONS.md](INSTRUCTIONS.md):
1.  **Energize**: Run `keel poke "Human interaction in chat"` to spark the board if it is idle.
2.  **Pulse**: Run `keel health --scene` to check subsystem stability.
3.  **Scan**: Run `keel mission next --status` and `keel pulse`.
4.  **Confirm**: Run `keel flow --scene` to verify whether the LIGHT IS ON or the board is idle waiting for fresh repository activity.
5.  **Diagnose**: Run `keel doctor` to ensure board integrity before proceeding.

### Procedural Instructions
Follow the formal procedural loops and checklists defined in:
👉 **[INSTRUCTIONS.md](INSTRUCTIONS.md)**

## Project Summary

`transit` is a lineage-aware append-only log with native tiered storage. The same engine is intended to power embedded and server modes. Branching, object storage, and immutable history are product primitives, not optional features.

## Non-Negotiable Working Rules

1. Preserve the shared engine model.
   Embedded and server mode should share storage semantics.
2. Preserve lineage semantics.
   A branch is a real child stream with explicit ancestry.
3. Preserve immutable history.
   Do not introduce in-place mutation of acknowledged records.
4. Preserve object-storage-native design.
   Do not make local disk the only serious persistence path.
5. Make durability explicit.
   Any append guarantee must state whether it is `memory`, `local`, or `tiered`.

Keep `just screen` as the default human proof path. If verification gets richer, improve that path instead of making the operator memorize an expanding command list.

## Current Status (2026-03-25)

- **Kernel Done:** Single-node local engine with branch, merge, and tiered storage verified.
- **Server Done:** Networked daemon with framed protocol, remote CLI, and tail sessions verified.
- **Integrity Done:** Verifiable lineage primitives, manifest roots, and checkpoints landed.
- **Materialization Done:** Branch-aware materialization kernel and Prolly Tree snapshots landed.
- **Consensus Slice Done:** Initial consensus kernel and leader-enforcement slice landed.
- **Proof Ready:** `just screen` covers local, tiered, networked, integrity, and materialization end-to-end flows.

## Next Missions

- **Replication Planning:** Decomposing the staged multi-node replication model into voyages and ready stories.
- **Board Hygiene:** Keeping mission/epic intent, generated artifacts, and pacemaker state aligned with execution.
- **Client Libs:** Promoting external usage via a dedicated Rust client first; other language bindings can follow later.

## Terminology Discipline

Use the same words consistently:

- `record`
- `stream`
- `branch`
- `lineage`
- `segment`
- `manifest`
- `local head`
- `remote tier`
- `drift`: The divergence between Execution and Intent. See [DRIFT.md](DRIFT.md) and [ADR 0001](.keel/adrs/0001-drift-as-a-first-class-metric.md).

If a change needs new vocabulary, define it in the relevant docs instead of letting terms drift in code reviews or commit messages.

## Implementation Guidance

When editing or adding code:

- keep branch creation cheap and ancestry-preserving
- keep recovery rules explicit about committed versus uncommitted data
- prefer designs that work the same in embedded and server mode
- treat large blobs as referenced objects rather than forcing them through the hot append path
- update the docs when configuration, durability, storage layout, or benchmark scope changes

## Review Guidance

When reviewing work, look for these failure modes first:

- server-only semantics that bypass the shared engine
- branch implementations that copy ancestor history eagerly
- hidden rewrite or compaction that changes acknowledged history
- performance claims with no durability or backend context
- configuration knobs that create separate semantic worlds for embedded and server deployments

## Verification Expectations

The expected evidence bar is:

- targeted correctness tests for the changed behavior
- benchmark evidence for performance-sensitive changes
- explicit storage and durability context
- documentation updates when public behavior changes

If the change touches manifests, segments, or protocol surfaces, also check `RELEASE.md`.

## Keel Maintenance

When updating `keel`, follow this sequence literally:

1. Update the Nix flake input and lockfile.
2. Build the new `keel` version through Nix and confirm it runs.
3. Install the git hooks with `keel hooks install` so the pre-commit hook enforces `just quality`, `just test`, and the auto-poke heartbeat update, while the commit-msg hook appends `keel doctor --status`.
4. Review upstream `~/workspace/spoke-sh/keel/AGENTS.md` and `~/workspace/spoke-sh/keel/INSTRUCTIONS.md`, then reconcile any required local workflow changes in `AGENTS.md`, `INSTRUCTIONS.md`, `Justfile`, or related docs.
5. Run the human-interaction orientation loop: `keel poke "Human interaction in chat"`, `keel health --scene`, `keel mission next --status`, `keel pulse`, `keel flow --scene`, and `keel doctor`.
6. Fix every structural `doctor` issue before doing anything else. Treat any open-loop energy reported by the scene commands or `keel doctor` as debt that must be cleared by the sealing commit, then report the `mission next` recommendation to the user.
7. Ask the user whether they want to execute the recommended mission work before starting it.
8. When the upgrade works, the hooks are installed, the upstream workflow reconciliation is landed, and the board is otherwise clean, make the sealing git commit for the maintenance change. Re-run `keel pulse`, `keel doctor --status`, and `keel flow` after that commit before moving on.

Do not treat a `keel` upgrade as complete until the flake, hook install, upstream workflow reconciliation, doctor checks, and mission recommendation flow are all clean, with no structural errors and no open heartbeat debt after the sealing commit.

## Commit Discipline

Commit granularity is literal in this repository.

- Make one git commit per completed story.
- Do not batch multiple accepted stories into one commit.
- If a voyage or mission transition produces board-only changes beyond a story commit, record that in a separate management commit.
- If planning work creates an epic, voyage, or backlog stories before implementation starts, record that planning slice in its own commit.
- Before starting the next story, stop and commit the previous story with its code, docs, evidence logs, and generated board artifacts.

The goal is simple: Keel story history and git history should line up without interpretation.

## Decision Resolution Hierarchy

When faced with ambiguity, resolve decisions in this descending order:
1.  **ADRs**: Binding architectural constraints.
2.  **CONSTITUTION**: The philosophy of collaboration.
3.  **ARCHITECTURE**: Source layout and technical boundaries.
4.  **PLANNING**: PRD/SRS/SDD authored for the current mission.

## Foundational Documents

These define the constraints and workflow of this repository:

| Document | Purpose |
|----------|---------|
| `README.md` | Entrypoint and canonical document navigation |
| `CONSTITUTION.md` | Non-negotiable product principles |
| `ARCHITECTURE.md` | Reference architecture and system model |
| `INSTRUCTIONS.md` | Step-by-step procedural loops and checklists |
| `CONFIGURATION.md` | Configuration philosophy and reference |
| `EVALUATIONS.md` | Benchmark and correctness evaluation guide |
| `RELEASE.md` | Release process and artifacts |
| `AI_TRACES.md` | Canonical AI trace workload contract |
| `COMMUNICATION.md` | Communication workload contract |
| `INTEGRITY.md` | Verifiable lineage and integrity contract |
| `MATERIALIZATION.md` | Materialization and stream processing contract |
| `GUIDE.md` | Developer guide and mental models |
| `.keel/adrs/` | Binding architecture decisions |

Use this order when interpreting constraints: ADRs → Constitution → Architecture → Configuration → Planning artifacts.

## Commands

### Command Execution Model

Use one path for each concern:

- `nix develop` for the repository shell and shared tooling.
- `just ...` for repo build, test, proof, and helper workflows.
- `keel ...` for all board and workflow operations.

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

### `keel` Board Workflow Commands

Run `keel --help` for the full command tree. Common commands:

| Category | Commands |
|----------|----------|
| Orientation | `keel poke "Human interaction in chat"` `keel health --scene` `keel flow --scene` `keel doctor` `keel screen --static` |
| Inspection | `keel mission next [<id>]` `keel pulse` `keel workshop` |
| Discovery | `keel bearing new <name>` `keel bearing research <id>` `keel bearing assess <id>` `keel bearing list` |
| Planning | `keel epic new "<name>" --problem "<problem>"` `keel voyage new "<name>" --epic <epic-id> --goal "<goal>"` |
| Execution | `keel story new "<title>" [--type <type>] [--epic <epic-id> [--voyage <voyage-id>]]` |
| Board Ops | `keel mission next [<id>]` `keel next --role manager` `keel next --role operator` `keel flow` `keel doctor` `keel generate` `keel config show` `keel mission show <id>` |
| Lifecycle | Story/voyage/epic transitions in the table below |

## Story and Milestone State Changes

Use CLI commands only. Do not move `.keel` files manually.

| Action | Command |
|--------|---------|
| Start | `keel story start <id>` |
| Reflect | `keel story reflect <id>` |
| Submit | `keel story submit <id>` |
| Reject | `keel story reject <id> "reason"` |
| Accept | `keel story accept <id> --role manager` |
| Ice | `keel story ice <id>` |
| Thaw | `keel story thaw <id>` |
| Voyage plan | `keel voyage plan <id>` |
| Voyage done | `keel voyage done <id>` |
| Bearing assess | `keel bearing assess <id>` |
| Bearing lay | `keel bearing lay <id>` |
| Mission activate | `keel mission activate <id>` |
| Mission achieve | `keel mission achieve <id>` |
| Mission verify | `keel mission verify <id>` |
