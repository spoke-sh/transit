# Kernel Types And Storage Skeleton - SRS

## Summary

Epic: VDcx2lQGz
Goal: Establish the first executable slice of the transit engine: stream, branch, and merge domain types, local segment and manifest scaffolding, and a meaningful human-facing mission proof path.

## Scope

### In Scope

- [SCOPE-01] Typed domain entities for streams, offsets, branch points, merge specs, and lineage metadata.
- [SCOPE-02] Local segment and manifest scaffolding in `transit-core` with object-store-facing persistence boundaries.
- [SCOPE-03] A human-facing kernel proof path through `just mission` and CLI mission status output.
- [SCOPE-04] The first documented boundary for a future `transit-materialize` layer.

### Out of Scope

- [SCOPE-05] Distributed consensus, replication, or multi-writer conflict resolution.
- [SCOPE-06] A full processing runtime or materialized-view engine.
- [SCOPE-07] Production-grade merge conflict automation beyond explicit policy scaffolding.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | `transit-core` must define typed stream, branch, merge, and lineage kernel entities with explicit merge-policy metadata. | SCOPE-01 | FR-01 | test |
| SRS-02 | `transit-core` must define immutable segment and manifest scaffold types that preserve the shared embedded/server engine boundary and can point at object-store-backed persistence. | SCOPE-02 | FR-02 | test |
| SRS-03 | The planning and implementation slice must document materialization as a first-party adjacent layer reusing lineage, manifests, and checkpoints rather than a separate storage system. | SCOPE-04 | FR-03 | manual |
| SRS-04 | `just mission` and the CLI mission surfaces must validate the current kernel slice through one human-facing proof path. | SCOPE-03 | FR-04 | cli |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The voyage must stay single-node in scope and must not introduce replication or consensus machinery. | SCOPE-01, SCOPE-02 | NFR-01 | manual |
| SRS-NFR-02 | Branch and merge semantics must remain explicit and append-only with no hidden reconciliation. | SCOPE-01, SCOPE-02 | NFR-02 | test |
| SRS-NFR-03 | Core, CLI, and future materialization boundaries must stay legible in crate layout and operator workflow. | SCOPE-03, SCOPE-04 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
