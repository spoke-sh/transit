# Materialization End-To-End Proof - SRS

## Summary

Epic: VEz2huKbt
Goal: Exercise materialization checkpoint, resume, Prolly Tree snapshots, and branch-aware processing end-to-end through `just screen`.

## Scope

### In Scope

- [SCOPE-01] End-to-end materialization proof in the `just screen` path covering checkpoint creation, resume from checkpoint, and Prolly Tree snapshot production.
- [SCOPE-02] At least one branch-aware materialization scenario that processes events across branch and merge boundaries.
- [SCOPE-03] Proof that materialization artifacts (checkpoints, snapshots) use the same manifest and lineage model as the core engine.

### Out of Scope

- [SCOPE-04] Production-grade stream processing framework or user-facing processor API.
- [SCOPE-05] CRDT overlays or collaborative state merging.
- [SCOPE-06] Distributed or multi-node materialization coordination.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Implement a `materialization-proof` CLI mission command that appends records to a stream, runs a `LocalMaterializationEngine` with a simple `Reducer`, and produces a `MaterializationCheckpoint`. | SCOPE-01 | FR-01 | test + screen |
| SRS-02 | Extend the proof to append additional records after checkpointing, resume the materializer from the checkpoint, and verify it processes only the new records. | SCOPE-01 | FR-02 | test + screen |
| SRS-03 | Extend the proof to build a Prolly Tree snapshot from the materializer's derived state using `ProllyTreeBuilder` and `ObjectStoreProllyStore`, and produce a `SnapshotManifest`. | SCOPE-01 | FR-03 | test + screen |
| SRS-04 | Implement a branch-aware scenario: create a branch, append branch-specific records, run a materializer on the branch, and produce a branch-local snapshot distinct from the root snapshot. | SCOPE-02 | FR-04 | test + screen |
| SRS-05 | Verify that materialization checkpoints and snapshots reference the same manifests and lineage model as the core engine. | SCOPE-03 | FR-05 | test + code review |
| SRS-06 | Add the materialization proof as a step in the `just screen` recipe. | SCOPE-01 | FR-01 | screen |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Materialization must use the same `LineageCheckpoint` and manifest model as the core engine; no parallel storage model. | SCOPE-03 | NFR-02 | test |
| SRS-NFR-02 | All proof output must be human-reviewable terminal text with clear step-by-step evidence. | SCOPE-01 | NFR-01 | screen |
| SRS-NFR-03 | The proof must produce structured JSON output via `--json` for machine consumption. | SCOPE-01 | NFR-01 | test |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
