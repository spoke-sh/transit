# Local Engine Core And Recovery - SRS

## Summary

Epic: VDeYUdLSW
Goal: Deliver the first executable local transit engine slice with durable append, replay, branch/merge execution, segment roll, and crash recovery on local storage.

## Scope

### In Scope

- [SCOPE-01] Durable local append and segment-roll behavior for the first executable engine slice.
- [SCOPE-02] Replay and tail reads backed by local manifests and rolled segments.
- [SCOPE-03] Explicit branch creation and merge recording on live local engine state.
- [SCOPE-04] Crash recovery rules for committed versus uncommitted local state.
- [SCOPE-05] Human-facing durable-engine verification through CLI proof and `just mission`.

### Out of Scope

- [SCOPE-06] Remote object-store publication and cold-history restore.
- [SCOPE-07] Server-mode networking or any daemon requirement.
- [SCOPE-08] Full processing or materialization runtime behavior.
- [SCOPE-09] Distributed replication or CRDT semantics.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Implement durable local append that writes committed records into an active segment and advances the local stream head. | SCOPE-01 | FR-01 | manual |
| SRS-02 | Implement segment roll plus local manifest persistence for committed engine state at defined boundaries. | SCOPE-01 | FR-03 | manual |
| SRS-03 | Implement replay and tail reads that serve committed records from the active head and rolled local segments in logical stream order through local manifest metadata. | SCOPE-02 | FR-01 | manual |
| SRS-04 | Implement explicit branch creation and merge recording on the local engine using parent positions and merge metadata rather than hidden reconciliation. | SCOPE-03 | FR-02 | manual |
| SRS-05 | Implement crash recovery that reconstructs committed local engine state from persisted segments and manifest metadata while excluding uncommitted bytes. | SCOPE-04 | FR-03 | manual |
| SRS-06 | Upgrade CLI and `just mission` proof surfaces so humans can verify append, replay, branch/merge, and crash-recovery behavior end to end. | SCOPE-05 | FR-05 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The voyage must remain single-node and local-first, without making server mode or remote publication prerequisites for correctness. | SCOPE-01, SCOPE-04, SCOPE-05 | NFR-01 | manual |
| SRS-NFR-02 | Branch and merge execution must preserve explicit, append-only lineage semantics and stream-local offset monotonicity. | SCOPE-03 | NFR-02 | manual |
| SRS-NFR-03 | Durability, recovery, and verification behavior must remain explicit in documentation, tests, and operator proof paths. | SCOPE-01, SCOPE-04, SCOPE-05 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
