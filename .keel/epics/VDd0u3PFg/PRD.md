# Research Branch-Aware Materialization And Processing - Product Requirements

> Define the first materialization contract for `transit` so branch-aware processing, checkpoints, and snapshots can become a first-party-adjacent layer on top of the durable local engine.

## Problem Statement

`transit` now has a verified durable local engine with append, replay, branching, merging, publication, and cold restore. What it still lacks is a precise contract for stream processing and durable derived state. Without that contract, future materialization work will drift between ad hoc replay loops, storage-coupled checkpointing, and vague claims about branch-aware views. The product needs one explicit model that says what `transit-core` exposes to processors, what belongs in a future `transit-materialize` layer, and how snapshots and merge-aware views should behave on top of lineage-preserving streams.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Define the minimum engine-to-materializer contract for deterministic replay, lineage inspection, and resumable checkpoints. | Contract authored | Canonical contract published |
| GOAL-02 | Define the first branch-aware snapshot and merge model for durable derived state. | Snapshot and merge model documented | Design center published |
| GOAL-03 | Align repository architecture and evaluation guidance around a first-party-adjacent materialization layer. | Cross-doc guidance updated | Alignment complete |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Core Engineer | Extends `transit-core` and adjacent crates | A stable replay and checkpoint boundary that does not leak unstable internals |
| View Author | Builds materialized projections, indexes, and branch-aware processors | Clear snapshot, checkpoint, and merge semantics |
| Operator / Benchmark Author | Verifies correctness and performance of processing layers | Explicit durability, replay, and checkpoint proof boundaries |

## Scope

### In Scope

- [SCOPE-01] Define the minimal contract between `transit-core` and a future `transit-materialize` layer.
- [SCOPE-02] Define branch-aware checkpoint, snapshot, and merge semantics for derived state.
- [SCOPE-03] Align repository docs and evaluation guidance around that contract.

### Out of Scope

- [SCOPE-04] Implementing a production materialization runtime in this epic.
- [SCOPE-05] Running processors inline in the hot append path or changing core durability semantics.
- [SCOPE-06] Treating CRDT metadata as a mandatory part of base stream semantics.
- [SCOPE-07] Designing replication, consensus, or server-specific processing behavior here.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Define the minimum materialization contract for `transit`, including replay cursors, lineage boundaries, checkpoint envelopes, and resume semantics. | GOAL-01 | must | The engine and future processing layer need a stable shared contract. |
| FR-02 | Define the first branch-aware snapshot and merge model, including the role of prolly trees, content-addressed snapshots, and view-specific merge policy. | GOAL-02 | must | Materialized views need one coherent design center instead of ad hoc structures. |
| FR-03 | Align architecture, guide, and evaluation surfaces around a first-party-adjacent materialization layer. | GOAL-03 | must | Future implementation and benchmarking work should cite one contract. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve the append-path throughput thesis by keeping processors, checkpoints, and snapshot construction out of the default acknowledgement path. | GOAL-01, GOAL-02 | must | Materialization should consume the log, not distort its durability model. |
| NFR-02 | Keep the contract shared across embedded and server packaging and compatible with local and tiered history. | GOAL-01, GOAL-03 | must | Materialization semantics belong to the engine model, not one wrapper. |
| NFR-03 | Keep checkpoints, snapshots, and merge semantics auditable and benchmarkable. | GOAL-02, GOAL-03 | must | Processing claims should remain verifiable in future evaluation work. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

- Prove the contract through voyage SRS coverage and authored repository artifacts.
- Verify the design boundary by updating architecture and guide surfaces to preserve the one-engine model and explicit durability boundaries.
- Re-run `keel doctor` and `keel flow` after planning and execution so the research mission stays coherent.

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The durable local engine now provides stable enough stream, branch, merge, segment, and manifest semantics for a materialization contract | The contract may need rework if storage boundaries change significantly | Validate against the current `transit-core` engine and docs |
| Prolly trees remain the strongest default candidate for branch-local snapshots | Snapshot guidance may need revision later | Re-evaluate once a prototype materializer exists |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| How much checkpoint metadata should `transit-core` expose directly versus leave opaque to a materializer? | Architecture | Open |
| Should derived-state merge ever be standardized beyond source-stream merge artifacts? | Architecture | Open |
| Could materialization work drift into an alternate storage model that ignores manifests and lineage? | Architecture | Mitigated by scope and NFR-02 |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] The repo contains a canonical materialization contract that defines replay, checkpoint, and resume semantics in `transit` terms.
- [ ] The repo contains a branch-aware snapshot and merge model with prolly trees as the leading snapshot structure and explicit alternatives called out.
- [ ] Architecture, guide, and evaluation guidance all describe the same first-party-adjacent materialization model.
<!-- END SUCCESS_CRITERIA -->

## Research Analysis

*From bearing assessment:*

### Findings

- The architectural direction is already coherent: materialization should be first-party and lineage-aware, but adjacent to the core engine rather than fused into append/recovery internals [SRC-01] [SRC-02].
- Prolly-tree-backed snapshots are the strongest current candidate for branch-local reuse and diffing, giving this bearing a concrete design center instead of a vague processing story [SRC-02].

### Opportunity Cost

Pursuing this immediately would compete with the current single-node kernel work, which is explicitly the prerequisite surface for shared manifests, lineage, and checkpoint contracts [SRC-03].

### Dependencies

- Stable stream, branch, merge, segment, and manifest types from the active single-node mission are required before the materialization contract can be trusted [SRC-02] [SRC-03].

### Alternatives Considered

- Keep processing fully external and replay raw streams into ad hoc mutable indexes, but that gives up branch-aware checkpoints and undercuts the product thesis around lineage-rich derived state [SRC-01] [SRC-02].

---

*This PRD was seeded from bearing `VDd0u3PFg`. See `bearings/VDd0u3PFg/` for original research.*
