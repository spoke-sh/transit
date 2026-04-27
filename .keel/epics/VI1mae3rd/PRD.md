# Production-Grade Replay And Materialization API - Product Requirements

## Problem Statement

Materializers, conversational feeds, and block or index consumers currently rely on full-vector replay, thin checkpoint metadata, and scaffold Prolly snapshots, making downstream derived state expensive and under-specified.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Make replay and tail consumption bounded by caller-specified ranges or page limits. | Materializers and hosted clients can consume a stream window without allocating the complete replay vector. | Shared engine, remote protocol, and client tests cover bounded replay. |
| GOAL-02 | Align materialization checkpoints with the published contract. | Checkpoints carry view kind, source manifest identity, durability, lineage reference, state/snapshot refs, produced-at time, and materializer version. | Existing hosted and local resume tests migrate to the richer envelope. |
| GOAL-03 | Make Prolly snapshots correct enough to become the default branch-aware snapshot substrate. | Snapshot construction is deterministic, separator keys are correct, and lookup/diff APIs are covered by tests. | Prolly tests include multi-layer range and diff cases. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Materializer Author | Builds durable derived views from Transit streams. | Bounded replay, safe checkpoint resume, and reusable snapshots. |
| Conversational App Developer | Builds channel, thread, and summary views over branch-aware history. | Efficient range reads and branch-local materialized state. |
| Block Or Index Consumer | Treats stream history as a canonical ordered source for block-like or indexable data. | Verifiable replay ranges, finality anchors, and bounded catch-up. |

## Scope

### In Scope

- [SCOPE-01] Shared-engine bounded replay and tail pagination.
- [SCOPE-02] Remote/client range-read surfaces that preserve acknowledgement and request correlation envelopes.
- [SCOPE-03] Rich materialization checkpoint envelopes and resume validation.
- [SCOPE-04] Deterministic Prolly snapshot construction plus basic lookup and diff primitives.
- [SCOPE-05] Targeted correctness tests and proof-path updates for the new surfaces.

### Out of Scope

- [SCOPE-06] A full production processor runtime or scheduler.
- [SCOPE-07] Cross-stream transactions or multi-stream materialization atomicity.
- [SCOPE-08] Remote object-store reclamation for deleted snapshots or manifests.
- [SCOPE-09] Signed checkpoint attestation beyond existing manifest-root verification.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Add shared-engine APIs for bounded replay and tail pagination over local, restored, and branch-inherited history. | GOAL-01 | must | Downstream consumers cannot scale if every read allocates the entire logical stream. |
| FR-02 | Expose the bounded read surface through the hosted protocol and Rust client while preserving `RemoteAcknowledged<T>`. | GOAL-01 | must | Hosted consumers need the same efficient semantics as embedded users. |
| FR-03 | Replace the thin hosted materialization checkpoint shape with the richer contract from `MATERIALIZATION.md`. | GOAL-02 | must | Resume safety depends on source manifest and lineage identity, not only opaque state bytes. |
| FR-04 | Harden Prolly snapshots with deterministic ordering, correct separators, lookup, diff, and snapshot manifest coverage. | GOAL-03 | must | Snapshot reuse is central to branch-aware materialization and cannot stay scaffold quality. |
| FR-05 | Update proof and evaluation guidance when public replay or checkpoint behavior changes. | GOAL-01, GOAL-02, GOAL-03 | should | Operators need the changed behavior visible through the default proof path. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve identical logical replay semantics for embedded and server delivery modes. | GOAL-01 | must | Range APIs cannot create two different databases. |
| NFR-02 | Bound memory use for page-sized replay windows independently of total stream length. | GOAL-01 | must | Materializers and block consumers need predictable catch-up behavior. |
| NFR-03 | Keep checkpoint and snapshot work off the default append acknowledgement path. | GOAL-02, GOAL-03 | must | Transit's hot path should remain governed by explicit durability, not derived-state work. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Bounded replay | Unit and integration tests over active, rolled, retained, restored, and branch-inherited records | Story proof logs plus `just test` |
| Hosted range reads | Protocol and `transit-client` tests | Remote acknowledgement and pagination assertions |
| Checkpoint envelope | Serialization, resume, tamper, stale-anchor, and manifest-root tests | Local and hosted materialization proof logs |
| Prolly snapshots | Determinism, separator, lookup, diff, and object-store persistence tests | `transit-materialize` test evidence |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Existing manifest and lineage checkpoint identity is sufficient to enrich materialization checkpoints without redesigning segment manifests. | Checkpoint work may require deeper storage changes. | Validate during the checkpoint-envelope story before changing public structs. |
| Range replay can be implemented incrementally before a full binary segment index lands. | The first range surface may still scan too much history. | Benchmark and document whether the first slice is bounded by output memory or by scan cost. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should range replay return an iterator, a callback visitor, or a paged vector as the stable Rust API? | Epic owner | Open |
| How much of the hosted checkpoint envelope should be a hard cutover versus an additional versioned type? | Epic owner | Open |
| Which Prolly diff shape is minimal: key-level diff, node-level diff, or both? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Embedded and hosted consumers can read bounded replay windows without receiving complete stream history.
- [ ] Materialization checkpoints expose the published contract fields and reject unsafe resume attempts.
- [ ] Prolly snapshots are deterministic, inspectable, and usable for branch-local reuse tests.
- [ ] `just screen` or the relevant proof path reflects the new replay/materialization behavior.
<!-- END SUCCESS_CRITERIA -->
