# Durable Consumer Cursors For Transit Streams - Product Requirements

## Problem Statement

Multiple independent readers on the same Transit stream cannot advance separately without each client persisting offsets out of band. Transit has no cursor primitive: `transit consume` is a stateless one-shot read, tail sessions are ephemeral, and branches are for lineage forks rather than per-consumer progress. Downstream consumers that want per-reader progress either implement their own durable offset store or misuse branches, both of which leak Transit's consistency and lineage guarantees into application code.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Ship a first-class cursor primitive so independent consumers can advance on the same stream without external offset bookkeeping. | A proof exercises two independent cursors on one stream, each advancing and acknowledging through durable position updates that survive restart and cache loss. | Proof passes in both embedded and hosted modes. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Downstream Rust consumer | Service or job that reads a Transit stream to keep a derived view in sync. | Durable, per-consumer progress tracking without a private offset store. |
| Operator | Person running hosted Transit for multiple consumers. | Visibility into where each named consumer is relative to the stream head. |
| Internal materialization engine | `transit-materialize` and similar derived-state pipelines. | Consistent resume semantics that align with cursor ack boundaries rather than stream offsets alone. |

## Scope

### In Scope

- [SCOPE-01] Cursor data model: identifier, bound stream, durable position, optional lineage metadata, creation and last-update timestamps.
- [SCOPE-02] Authoritative cursor storage on the embedded engine, surviving restart and warm-cache loss.
- [SCOPE-03] Explicit advance/ack semantics aligned with Transit's existing durability boundaries (local, replicated, quorum, tiered).
- [SCOPE-04] Server protocol operations for create, lookup, advance, ack, and delete cursor, wrapped in the existing framed request/response envelope.
- [SCOPE-05] CLI and `transit-client` surfaces for the cursor lifecycle and for cursor-scoped consume/tail flows.
- [SCOPE-06] Proof coverage demonstrating two independent cursors advancing without interference and recovering position after restart.

### Out of Scope

- [SCOPE-07] Consumer-group rebalancing or partition assignment — Transit streams are not partitioned the way Kafka topics are.
- [SCOPE-08] Multi-writer semantics or any mutation of stream history through the cursor API.
- [SCOPE-09] Cross-stream fan-in cursors; cursors are scoped to a single stream for the first slice.
- [SCOPE-10] Cursor retention policies or TTL sweep; long-lived unacked cursors are surfaced but not garbage collected automatically.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Provide a cursor data model with stable identifier, bound stream, durable position, and lineage metadata (actor, reason, labels) persisted on the authoritative engine. | GOAL-01 | must | Establishes the identity and durable state that independent consumers need. |
| FR-02 | Expose cursor create, lookup, advance, ack, and delete operations through both the embedded engine API and the hosted server protocol. | GOAL-01 | must | Keeps cursor semantics identical across embedded and hosted modes, matching the shared-engine contract. |
| FR-03 | Surface cursors through the `transit` CLI and `transit-client` so operators and consumers can use cursors without driving the raw protocol. | GOAL-01 | must | Makes the primitive usable from the existing operator and Rust client surfaces. |
| FR-04 | Integrate cursors with consume and tail flows so a reader can resume from its cursor's durable position and acknowledge progress explicitly. | GOAL-01 | must | Connects the cursor primitive to the actual reader workflows it needs to replace. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Cursor advance acknowledgements honor the same durability boundaries Transit already defines for appends (local, replicated, quorum, tiered) and do not claim durability the engine has not reached. | GOAL-01 | must | Keeps Transit's durability contract honest across the new API. |
| NFR-02 | Cursor state survives engine restart and warm-cache loss with behavior verifiable by a dedicated proof. | GOAL-01 | must | Matches the existing durability guarantees used to prove stream state recovery. |
| NFR-03 | Cursors do not relax the one-writer-per-stream-head model and cannot mutate stream history; they only record read position. | GOAL-01 | must | Preserves Transit's core consistency invariant. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Cursor model and embedded engine | Rust unit + integration tests on `transit-core` | Tests demonstrating create, advance, ack, lookup, delete, and crash-recovery semantics |
| Hosted cursor surface | End-to-end CLI proof against a locally started server | Proof output from a new `transit proof cursor-progress` or equivalent flow |
| Independent progress | Proof with two cursors on one stream, advancing at different rates | Deterministic proof snapshot showing divergent positions and independent recovery |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Cursor state can live alongside manifest and lineage metadata without requiring a second storage model. | We would have to introduce a new authoritative store, expanding scope. | Prototype the cursor persistence path inside the existing engine directory layout during the first voyage. |
| Existing durability boundaries (local, replicated, quorum, tiered) are the right ack vocabulary for cursor advances. | We may need a cursor-specific durability grammar. | Review ack semantics during the first voyage SDD review. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should cursors bind to a branch or always to the root stream? | Epic owner | Open |
| Do cursors need a compare-and-advance (optimistic) primitive, or is last-writer-wins acceptable for the first slice? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Cursor data model and engine persistence land in `transit-core` with tests covering create, advance, ack, lookup, delete, and restart recovery.
- [ ] Hosted protocol exposes the cursor surface through the framed request/response envelope with explicit acknowledgement semantics.
- [ ] CLI and `transit-client` surfaces let an operator or Rust consumer drive the full cursor lifecycle and resume a consume flow from a cursor position.
- [ ] A proof demonstrates two independent cursors on one stream, advancing at different rates and recovering durable positions after engine restart.
<!-- END SUCCESS_CRITERIA -->
