# Hosted Materialization Progress And Checkpointing - Product Requirements

## Problem Statement

Hosted client-only consumers can replay remote Transit streams, but they cannot checkpoint or resume materialization progress through native Transit server/client semantics, forcing application-owned offsets or embedded LocalEngine usage.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Let client-only Rust consumers checkpoint and resume materialization progress through `transit-client` and `transit-server` without `LocalEngine`. | A hosted proof against a separate `transit-server` can checkpoint opaque reducer state, resume from a hosted-native anchor, and reduce only records after that anchor. | One end-to-end proof plus targeted protocol and client tests land with the mission. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| External Daemon Consumer | A downstream Rust application that intentionally talks only to a separate `transit-server` through `transit-client`. | Native hosted checkpoint and resume semantics for materialization without custom offset files or embedded Transit authority. |
| Transit Operator | The team running `transit-server` as the authoritative messaging substrate for downstream consumers. | Hosted materialization state that preserves lineage verification and is observable through normal Transit proofs and docs. |

## Scope

### In Scope

- [SCOPE-01] Hosted durable consumer cursor primitives for client-only materializers.
- [SCOPE-02] A hosted materialization checkpoint envelope bound to source stream identity, anchor position, and lineage or manifest verification data.
- [SCOPE-03] Hosted resume semantics that replay only records after the checkpoint anchor.
- [SCOPE-04] A client-first Rust API in `transit-client` for the hosted checkpoint and resume workflow.
- [SCOPE-05] Proof coverage and operator guidance for external-daemon materializers.

### Out of Scope

- [SCOPE-06] Replacing or removing the current `transit-materialize` local-engine APIs.
- [SCOPE-07] Making materialized state part of authoritative stream truth.
- [SCOPE-08] Multi-stream transactions, cross-stream checkpoints, or arbitrary server-side reducers.
- [SCOPE-09] Embedding Transit server behavior inside downstream applications.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Expose hosted durable cursor primitives so downstream materializers can create, inspect, advance, and remove replay progress without app-owned offset files. | GOAL-01 | must | Hosted consumers need a native progress primitive before they can resume safely. |
| FR-02 | Expose a hosted materialization checkpoint envelope that binds materialization id, source stream id, source anchor position, lineage or manifest identity, opaque state bytes, and produced-at time. | GOAL-01 | must | Hosted checkpoints need the same semantic anchor that local materialization relies on. |
| FR-03 | Expose hosted resume semantics that validate a checkpoint or cursor and replay only records after the last anchored position. | GOAL-01 | must | Incremental replay is the missing hosted behavior today. |
| FR-04 | Make `transit-client` the canonical Rust API for hosted checkpoint and resume workflows. | GOAL-01 | must | Downstream applications should stay on the server/client boundary instead of reaching into `transit-core`. |
| FR-05 | Provide proof coverage and operator guidance for the hosted materialization workflow against a separate Transit daemon. | GOAL-01 | should | Operators need a demonstrable end-to-end path for adoption and debugging. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve authoritative log semantics by keeping hosted cursors and checkpoints outside acknowledged stream truth. | GOAL-01 | must | Materialization progress must remain derived metadata, not a hidden second truth store. |
| NFR-02 | Bind hosted checkpoints strongly enough to source lineage or manifest identity to reject unsafe resume attempts. | GOAL-01 | must | Hosted materialization must be verifiable, not just convenient. |
| NFR-03 | Keep the workflow viable for a separate `transit-server` process plus Rust client SDK. | GOAL-01 | must | The primary user is intentionally operating across the hosted boundary. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Hosted protocol contract | Targeted core and protocol tests | Story-level acceptance artifacts for cursor and checkpoint semantics |
| Rust client workflow | Targeted client tests plus end-to-end hosted proof | Proof logs showing checkpoint, resume, and incremental replay against a separate daemon |
| Operator guidance | Public docs and proof walkthrough | Updated docs plus `just screen` or equivalent hosted materialization proof output |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Existing lineage checkpoints and replay boundaries in the shared engine are sufficient to anchor a hosted checkpoint envelope. | Hosted materialization may need deeper shared-engine changes than planned. | Validate in the first story by defining the protocol contract against current engine capabilities. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should hosted cursor state and hosted checkpoint state be persisted as distinct artifacts or as one merged envelope? | Epic owner | Open |
| Which minimal lineage or manifest identity is strong enough for hosted resume verification without over-exposing local-only engine internals? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] A downstream Rust client can checkpoint materialization progress against a separate `transit-server` without `LocalEngine`.
- [ ] Hosted resume validates the checkpoint anchor and processes only records after that anchor.
- [ ] Hosted checkpoints remain bound to source stream lineage or manifest identity strongly enough to reject unsafe resume.
- [ ] Operators have proof coverage and docs for the hosted materialization workflow.
<!-- END SUCCESS_CRITERIA -->
