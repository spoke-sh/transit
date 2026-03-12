# Single-Node Branch And Merge Engine - Product Requirements

## Problem Statement

Transit has docs and bootstrap tooling, but it does not yet have a planned execution path for the first single-node storage engine with explicit branch, merge, and object-store-backed lineage semantics.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Define the first executable kernel for stream, branch, and merge lineage in `transit-core`. | The workspace exposes typed lineage primitives and scoped stories to deliver them | Voyage VDcx4sb6D is planned and story VDcx7jKhg is accepted |
| GOAL-02 | Establish the first local segment and manifest scaffold without breaking the object-store-native architecture. | Storage scaffold types and object-store-facing manifest boundaries exist in the core plan and implementation slice | Story VDcx7jQiT is accepted |
| GOAL-03 | Keep the human-facing proof path meaningful while the storage kernel becomes real. | `just mission` exercises kernel-oriented proof instead of only repo bootstrap checks | Story VDcx7jWDN is accepted |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Core Transit Maintainer | The engineer shaping the initial storage engine and board-guided roadmap. | A concrete, traceable plan for the first executable kernel slice. |
| Runtime Or Agent Builder | The engineer who will embed or call `transit` from an application runtime. | Stable branch and merge semantics that can be implemented incrementally without redesign. |
| Operator | The human validating progress through `just mission`, CLI output, and board state. | One trustworthy proof path that stays aligned with product reality. |

## Scope

### In Scope

- [SCOPE-01] Typed stream, branch, merge, and lineage kernel types in `transit-core`.
- [SCOPE-02] Local segment and manifest scaffolding that preserves the object-store-native architecture.
- [SCOPE-03] A human-facing mission proof path that validates the kernel slice through CLI and `just mission`.
- [SCOPE-04] A documented boundary for first-party materialization and processing work.

### Out of Scope

- [SCOPE-05] Distributed consensus, replication, leader election, or multi-node coordination.
- [SCOPE-06] A full stream-processing or materialization runtime.
- [SCOPE-07] Production-grade merge conflict resolution beyond explicit merge-policy scaffolding.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Define typed stream, branch, merge, and lineage kernel primitives in `transit-core`. | GOAL-01 | must | The first executable storage slice needs a stable domain model before persistence and APIs can grow around it. |
| FR-02 | Add local segment and manifest scaffolding that preserves `transit`'s tiered-storage direction and shared engine boundary. | GOAL-01, GOAL-02 | must | Storage scaffolding is the smallest meaningful implementation step beyond pure planning. |
| FR-03 | Preserve a clear materialization boundary so future derived-state work reuses lineage, manifests, and checkpoints. | GOAL-02 | should | Processing should build on the same storage truth rather than inventing a side system. |
| FR-04 | Keep `just mission` and CLI status surfaces aligned with the current kernel slice. | GOAL-03 | must | Human verification is part of the product discipline, not after-the-fact tooling. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Keep scope constrained to single-node execution for this epic. | GOAL-01, GOAL-02 | must | Avoids mixing foundational storage work with distributed-systems design too early. |
| NFR-02 | Preserve explicit, append-only lineage semantics for branch and merge operations. | GOAL-01, GOAL-02 | must | Hidden reconciliation would undermine the core transit model. |
| NFR-03 | Maintain clear crate and operator boundaries between core logic, CLI proof surfaces, and future materialization work. | GOAL-02, GOAL-03 | should | Keeping boundaries clean now prevents architectural drift as the repo grows. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Kernel domain model | Unit tests and story-level CLI/build proofs | Accepted story evidence for VDcx7jKhg |
| Storage scaffold | Unit tests and object-store-facing proof commands | Accepted story evidence for VDcx7jQiT |
| Mission proof path | `just mission`, CLI status output, and board state | Accepted story evidence for VDcx7jWDN |
| Scope discipline | `keel doctor`, `keel flow`, and planning review | Board health plus planned voyage artifacts |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The first production-worthy path for `transit` should start with a single-node shared engine. | A wider initial scope would invalidate the current voyage boundary. | Revisit before adding replication or multi-writer work. |
| Materialization can begin as an adjacent first-party layer instead of being forced into the first storage-kernel slice. | The epic may under-plan derived-state requirements. | Capture the boundary explicitly in SRS and SDD. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Which merge policies should be first-class in the earliest kernel implementation? | Epic owner | Open |
| How much manifest/checkpoint shape should be implemented before the first materializer exists? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] The repo has a planned and executable first kernel slice for typed lineage and storage scaffolding.
- [ ] The board exposes actionable stories for kernel types, storage scaffold, and mission proof path.
- [ ] The materialization boundary is documented without inflating the hot append path prematurely.
<!-- END SUCCESS_CRITERIA -->
