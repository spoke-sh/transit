# AGENTS.md

Shared guidance for AI agents working with this repository.

## Project Summary

`transit` is a lineage-aware append-only log with native tiered storage. The same engine is intended to power embedded and server modes. Branching, object storage, and immutable history are product primitives, not optional features.

## Read These First

Before making substantial changes, open these documents in order:

1. `README.md`
2. `ARCHITECTURE.md`
3. `CONSTITUTION.md`
4. `INSTRUCTIONS.md`
5. the task-specific reference doc such as `CONFIGURATION.md`, `EVALUATIONS.md`, or `RELEASE.md`

Do not invent behavior that conflicts with those documents silently.

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
- **Proof Ready:** `just screen` covers local, tiered, and networked end-to-end flows.

## Next Missions

- **Replication Planning:** Decomposing the staged multi-node replication model into voyages and ready stories.
- **Board Hygiene:** Keeping mission/epic intent, generated artifacts, and pacemaker state aligned with execution.
- **Client Libs:** Promoting external usage via dedicated Python/JS/Go client libraries.

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
3. Install the git hooks with `just keel hooks install`.
4. Review upstream `~/workspace/spoke-sh/keel/AGENTS.md` and `~/workspace/spoke-sh/keel/INSTRUCTIONS.md`, then reconcile any required local workflow changes in `AGENTS.md`, `INSTRUCTIONS.md`, `Justfile`, or related docs.
5. Run the human-interaction orientation loop: `just keel poke "Human interaction in chat"`, `just keel health --scene`, `just keel mission next --status`, `just keel pulse`, `just keel flow --scene`, and `just keel doctor`.
6. Fix every failing `doctor` issue before doing anything else, then report the `mission next` recommendation to the user.
7. Ask the user whether they want to execute the recommended mission work before starting it.
8. When the upgrade works, the hooks are installed, `keel doctor` is clean, and the board is clean, make a git commit for the maintenance change before moving on.

Do not treat a `keel` upgrade as complete until the flake, hook install, upstream workflow reconciliation, doctor checks, and mission recommendation flow are all clean.

## Commit Discipline

Commit granularity is literal in this repository.

- Make one git commit per completed story.
- Do not batch multiple accepted stories into one commit.
- If a voyage or mission transition produces board-only changes beyond a story commit, record that in a separate management commit.
- If planning work creates an epic, voyage, or backlog stories before implementation starts, record that planning slice in its own commit.
- Before starting the next story, stop and commit the previous story with its code, docs, evidence logs, and generated board artifacts.

The goal is simple: Keel story history and git history should line up without interpretation.
