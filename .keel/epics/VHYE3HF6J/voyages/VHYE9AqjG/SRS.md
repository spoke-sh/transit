# Deliver Hosted Materialization Cursor And Resume Surface - SRS

## Summary

Epic: VHYE3HF6J
Goal: Let external-daemon Rust consumers checkpoint materialization progress, verify hosted resume anchors, and replay only records after the last acknowledged materialization checkpoint.

## Scope

### In Scope

- [SCOPE-01] Hosted durable cursor primitives for materialization progress on a source stream.
- [SCOPE-02] A hosted checkpoint envelope that binds materialization identity, source anchor, lineage or manifest verification data, opaque reducer state, and produced-at time.
- [SCOPE-03] Hosted resume semantics that validate the checkpoint and replay only records after the anchor.
- [SCOPE-04] A canonical Rust SDK workflow in `transit-client` for hosted checkpoint, resume, and incremental replay.
- [SCOPE-05] Proof coverage and operator guidance for external-daemon materializers.

### Out of Scope

- [SCOPE-06] Changes that remove or weaken the existing local `transit-materialize` APIs.
- [SCOPE-07] Making materialized state or cursor state part of authoritative stream truth.
- [SCOPE-08] Multi-stream transactions, cross-stream checkpoints, or server-hosted reducer execution.
- [SCOPE-09] Client-side embedded authority or `LocalEngine` requirements.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Add hosted cursor primitives that let a client-only materializer create, inspect, advance, and delete progress for a source stream and materialization identity. | SCOPE-01 | FR-01 | story: VHYEATqz5 |
| SRS-02 | Add a hosted materialization checkpoint envelope that carries materialization id, source stream id, source anchor position, lineage or manifest verification identity, opaque state bytes, and produced-at time. | SCOPE-02 | FR-02 | story: VHYEATqz5 |
| SRS-03 | Add hosted resume semantics that validate a checkpoint or cursor anchor and replay only records after that anchor while rejecting lineage mismatches or missing anchors. | SCOPE-03 | FR-03 | story: VHYEAUq0l |
| SRS-04 | Expose the canonical hosted materialization workflow through `transit-client` so downstream Rust applications can checkpoint, resume, and fetch pending records without `LocalEngine`. | SCOPE-04 | FR-04 | story: VHYEAUq0l |
| SRS-05 | Publish proof coverage and operator guidance that demonstrate hosted checkpoint, resume, and incremental replay against a separate `transit-server`. | SCOPE-05 | FR-05 | story: VHYEAVyxL |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Hosted cursors and checkpoints must preserve shared-engine lineage semantics and must not alter authoritative append, read, or tail behavior. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-01 | story: VHYEATqz5 |
| SRS-NFR-02 | The hosted workflow must keep downstream applications on the external daemon boundary with no requirement to embed `LocalEngine` or local Transit authority. | SCOPE-03, SCOPE-04 | NFR-03 | story: VHYEAUq0l |
| SRS-NFR-03 | Operator-facing proof and documentation must make checkpoint verification, resume behavior, and failure modes explicit for hosted consumers. | SCOPE-05 | NFR-02 | story: VHYEAVyxL |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
