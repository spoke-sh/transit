# Materialization Contract And Snapshot Model - Software Design Description

> Define the first branch-aware materialization contract on top of the durable local engine

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage is a contract-definition slice. It does not implement a runtime processor graph, checkpoint writer, or prolly-tree index in code. Instead, it defines the boundary between `transit-core` and a future `transit-materialize` layer, with enough precision that future implementation work can preserve the one-engine thesis and branch-aware semantics.

## Context & Boundaries

The boundary is deliberate:

- `transit-core` owns ordered history, manifests, lineage, publication, and restore.
- A future `transit-materialize` layer consumes replayable history and emits checkpoints or snapshots without changing acknowledged stream history.
- Snapshot structures and merge policy should reuse lineage and immutable storage rather than inventing a second persistence model.

```
┌──────────────────────────────────────────────────────────────┐
│           Materialization Contract And Snapshot Model        │
│                                                              │
│  replay/checkpoint API   branch-aware snapshots   repo docs  │
│  cursor/resume/boundary  prolly tree/default      architecture│
│  local+tiered history    derived merge semantics  guide/eval │
└──────────────────────────────────────────────────────────────┘
              ↑                           ↑
        transit-core engine        future transit-materialize
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `README.md`, `ARCHITECTURE.md`, `GUIDE.md`, `EVALUATIONS.md` | repo docs | Current engine and operator guidance to align | current |
| `crates/transit-core/src/engine.rs` | code | Current replay, branch, merge, publish, and restore semantics that the contract is shaped around | current |
| `crates/transit-core/src/storage.rs` | code | Current segment and manifest model that checkpoints and snapshots must respect | current |
| Bearing `VDd0u3PFg` | board | Source research and recommendation for this epic | laid |
| Mission `VDeXa6bFd` | board | Verified durable local engine that now supplies the base boundary | verified |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Layering | Materialization remains first-party-adjacent, not inline in append/recovery internals | Preserves throughput and one-engine semantics |
| Checkpoint contract | Expose replay cursor, lineage boundary, manifest generation, and materializer-defined opaque state | Enough to resume deterministically without leaking unstable storage internals |
| Snapshot default | Use prolly trees as the leading snapshot structure for branch-local reuse and diffing | Best fit with branch-heavy derived state and content-addressed reuse |
| Supporting structures | Mention Merkle snapshot manifests and Bloom/Xor summaries as optional supporting structures | Useful for verification and pruning without overcommitting implementation |
| Merge semantics | Source-stream merges are first-class; derived-state merge policy stays view-specific, with optional derived merge artifacts | Avoids forcing one reduction model across all projections |
| CRDT stance | CRDTs remain optional overlays in specific views, not base log semantics | Keeps throughput and base record shape clean |

## Architecture

The voyage produces one canonical contract and three aligned operating surfaces:

1. `MATERIALIZATION.md` will define the engine/materializer contract, checkpoint envelope, and snapshot guidance.
2. `ARCHITECTURE.md` will describe where materialization fits relative to the durable engine and tiered history.
3. `GUIDE.md` and `EVALUATIONS.md` will describe how operators and benchmark authors should reason about checkpoints, replay, and branch-aware derived state.

## Components

### Engine-To-Materializer Contract

- Defines the minimum replay boundary a processor can rely on.
- Keeps checkpoints tied to stream identity, offset, lineage, and manifest generation.
- Lets materializers resume deterministically across local and restored history.

### Snapshot Model

- Establishes prolly trees as the default design center for reusable branch-local state.
- Names supporting structures for verification, pruning, and partial restore.
- Avoids coupling snapshot shape to one storage backend or deployment mode.

### Merge Semantics

- Separates source-stream merge artifacts from derived-state reconciliation policy.
- Keeps `transit` explicit about lineage while allowing views to choose their own reduction logic.

### Repository Alignment

- Ensures the repo does not describe materialization one way in architecture and another way in evaluation or guide surfaces.

## Interfaces

This voyage defines documentation and planning interfaces rather than wire protocols:

- epic PRD requirements
- voyage SRS requirements
- story acceptance criteria
- repository contracts for future `transit-materialize` work

## Data Flow

1. A materializer reads ordered history from `transit-core` replay surfaces.
2. It records a checkpoint envelope containing lineage-aware cursor state plus materializer-owned opaque state.
3. It emits branch-aware snapshots using the chosen snapshot structure.
4. On source-stream merge events, it either replays through the merge or emits a derived merge artifact according to view policy.
5. Operators and benchmark authors verify replay, resume, and merge behavior using the same explicit boundaries.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Materialization drifts into the append hot path | Review against SRS-NFR-01 and architecture thesis | Reject requirements that imply inline processing or checkpoint acknowledgements | Re-scope work to adjacent replay consumers |
| Checkpoint contracts leak unstable segment internals | Review against SRS-01 and dependency boundaries | Collapse the contract to stable lineage and manifest fields plus opaque view state | Rework docs before implementation begins |
| Merge semantics become falsely universal across all views | Review against SRS-03 | Keep source merges canonical and derived merges view-specific | Document optional derived merge artifacts instead of enforcing one reducer |
| Snapshot guidance becomes storage-backend-specific | Review against SRS-NFR-02 | Keep snapshot structures content-addressed and provider-neutral | Re-align docs and future prototypes around manifest and lineage boundaries |
