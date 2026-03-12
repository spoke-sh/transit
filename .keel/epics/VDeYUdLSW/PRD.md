# Durable Local Append And Recovery Engine - Product Requirements

## Problem Statement

Transit has verified kernel scaffolding, AI workload guidance, and integrity contracts, but it still lacks a real local engine for durable append, replay, recovery, branching, merging, segment roll, manifest persistence, and cold-history restore.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Deliver a real local append/replay/recovery engine on top of the existing kernel types. | Durable local engine slice exists with scoped voyages and accepted stories | First engine voyage completed |
| GOAL-02 | Prove explicit branch and merge behavior on the live engine instead of stopping at type definitions. | Branch and merge execution semantics are documented, implemented, and verified | Engine semantics accepted |
| GOAL-03 | Preserve tiered-storage direction through segment roll, manifest persistence, and cold-history publication/restore. | Local and object-store-backed lifecycle exists in the plan and proof path | Cold-history workflow accepted |
| GOAL-04 | Keep the human-facing proof path meaningful as the engine becomes real. | `just mission` exercises the durable engine with recovery-oriented proof | Mission verification upgraded |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Core Transit Maintainer | The engineer building the first real engine out of the current kernel and storage scaffolding. | A traceable delivery plan for append, recovery, lineage, and storage behavior. |
| Runtime Or Application Builder | The engineer who wants to embed `transit` locally before server mode exists. | A usable local engine with explicit branch, merge, and replay semantics. |
| Operator | The human validating progress through CLI proof and `just mission`. | One trustworthy proof path that tracks durable engine behavior instead of repo scaffolding. |

## Scope

### In Scope

- [SCOPE-01] Durable local append, read, replay, and tail semantics for the first local engine slice.
- [SCOPE-02] Branch creation from explicit parent positions and explicit merge records on live engine state.
- [SCOPE-03] Segment roll, manifest persistence, and crash-recovery boundaries for committed versus uncommitted data.
- [SCOPE-04] Cold-history publication and restore behavior that preserves the object-storage-native design.
- [SCOPE-05] A human-facing mission proof path that exercises engine behavior and recovery semantics.

### Out of Scope

- [SCOPE-06] Multi-node replication, consensus, distributed scheduling, or leader election.
- [SCOPE-07] Full server-mode networking as a dependency for proving the engine.
- [SCOPE-08] A production materialization runtime beyond checkpoint and replay boundaries.
- [SCOPE-09] CRDT semantics in the base engine.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Implement durable local append, read, replay, and tail behavior on top of the current kernel types and storage scaffold. | GOAL-01 | must | The project needs a real engine, not just a type model. |
| FR-02 | Implement explicit branch creation and merge recording on the live engine while preserving append-only lineage semantics. | GOAL-01, GOAL-02 | must | Branch and merge are core product behaviors, not later overlays. |
| FR-03 | Implement segment roll, manifest persistence, and crash-recovery rules that distinguish committed from uncommitted data. | GOAL-01, GOAL-03 | must | Recovery discipline is part of the engine contract. |
| FR-04 | Prove a cold-history publication and restore path that keeps object storage in the normal lifecycle. | GOAL-03 | should | Tiered storage must stay real in the first usable engine. |
| FR-05 | Upgrade `just mission` and CLI proof surfaces so humans can verify durable-engine progress end to end. | GOAL-04 | must | Human verification is a product constraint, not incidental tooling. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Keep scope constrained to single-node execution and local durability semantics for this epic. | GOAL-01, GOAL-03 | must | Prevents distributed design from distorting the local engine contract. |
| NFR-02 | Preserve explicit, append-only lineage semantics for branch and merge operations. | GOAL-01, GOAL-02 | must | Hidden reconciliation would undermine the core `transit` model. |
| NFR-03 | Keep durability, recovery, and cold-restore guarantees explicit in docs, code, and benchmarks. | GOAL-01, GOAL-03, GOAL-04 | must | Storage claims are only useful if operators can compare and verify them. |
| NFR-04 | Preserve compatibility with the one-engine thesis so the future server mode wraps the same storage semantics. | GOAL-01, GOAL-02, GOAL-03 | must | This epic must build the shared engine, not a local-only fork. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Local append and replay | Tests plus CLI proof flows | Story-level verification artifacts linked during execution |
| Branch and merge semantics | Focused correctness tests and lineage-oriented proof outputs | Accepted story evidence for branch/merge slices |
| Recovery and manifest behavior | Crash/recovery tests plus mission-path proofs | Accepted story evidence for recovery and storage slices |
| Cold-history publication and restore | Object-store-backed proof runs and restore checks | Accepted story evidence for tiered-storage slices |
| Operator proof path | `just mission`, CLI status, and board health | Accepted story evidence plus `keel doctor` |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The AI workload contract from `VDd1EybWm` is mature enough to shape example and evaluation surfaces without blocking engine work. | Evaluation and example planning may need revision later. | Re-check when voyage planning reaches workload-shaped proofs. |
| The integrity contract from `VDd1F1tUe` is mature enough to constrain manifest, checkpoint, and restore decisions in this epic. | Recovery and storage slices may need resequencing. | Re-check when recovery and cold-restore voyages are planned. |
| The current kernel and storage scaffold are sufficient foundations for an executable local engine. | Additional foundational refactoring may be needed before engine work can start. | Validate during first voyage decomposition. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Where should append acknowledgement boundaries sit relative to local durability and future tiered durability modes? | Epic owner | Open |
| How much object-store publication and restore should the first engine prove before server mode exists? | Epic owner | Open |
| What is the smallest merge execution surface that proves explicit reconciliation without overdesigning conflict policy? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] The repo contains a planned and executable first durable local engine slice beyond kernel scaffolding.
- [ ] Branch, merge, recovery, and manifest behavior are all represented as scoped epic work instead of future hand-waving.
- [ ] Cold-history publication/restore and the human-facing `just mission` proof path remain part of the first usable engine story.
<!-- END SUCCESS_CRITERIA -->
