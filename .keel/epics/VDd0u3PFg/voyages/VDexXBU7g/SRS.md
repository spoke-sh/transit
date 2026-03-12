# Materialization Contract And Snapshot Model - SRS

## Summary

Epic: VDd0u3PFg
Goal: Define the first branch-aware materialization contract on top of the durable local engine

## Scope

### In Scope

- [SCOPE-01] The minimum contract between `transit-core` and a future `transit-materialize` layer.
- [SCOPE-02] Branch-aware checkpoint, snapshot, and merge semantics for durable derived state.
- [SCOPE-03] Cross-document alignment for repository architecture, guide, and evaluation surfaces.

### Out of Scope

- [SCOPE-04] Implementing a production materialization runtime during this voyage.
- [SCOPE-05] Running processors inline in the append acknowledgement path.
- [SCOPE-06] Embedding CRDT metadata into base stream semantics.
- [SCOPE-07] Replication, consensus, or server-specific processing design.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Define the minimum materialization contract for `transit`, including replay cursors, lineage inspection boundaries, checkpoint envelopes, and resume semantics. | SCOPE-01 | FR-01 | manual |
| SRS-02 | Define the branch-aware snapshot model, including prolly trees as the leading structure and explicit alternatives such as content-addressed snapshot manifests and segment-local summary filters. | SCOPE-02 | FR-02 | manual |
| SRS-03 | Define how source-stream merges relate to derived-state merge semantics, including view-specific merge policy and optional derived merge artifacts. | SCOPE-02 | FR-02 | manual |
| SRS-04 | Align repository documentation so the architecture, guide, and evaluation surfaces reference the same materialization contract and boundaries. | SCOPE-03 | FR-03 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The contract must preserve the append-path throughput thesis by keeping processors, checkpoint construction, and snapshot maintenance out of the default acknowledgement path. | SCOPE-01, SCOPE-02 | NFR-01 | manual |
| SRS-NFR-02 | The contract must remain shared across embedded and server packaging and compatible with local and tiered history. | SCOPE-01, SCOPE-03 | NFR-02 | manual |
| SRS-NFR-03 | Checkpoints, snapshots, and merge semantics must be auditable and benchmarkable for future evaluation work. | SCOPE-02, SCOPE-03 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
