# Deliver Streaming Replay And Snapshot-Safe Materialization - SRS

## Summary

Epic: VI1mae3rd
Goal: Expose range replay, resume-ready checkpoint metadata, and Prolly snapshot correctness so downstream applications can build derived state without side stores or full-history scans.

## Scope

### In Scope

- [SCOPE-01] Shared-engine bounded replay and tail pagination.
- [SCOPE-02] Hosted protocol and Rust client range-read support.
- [SCOPE-03] Rich materialization checkpoint envelope and resume validation.
- [SCOPE-04] Deterministic Prolly snapshot construction plus lookup and diff primitives.
- [SCOPE-05] Focused tests and proof updates for the changed public behavior.

### Out of Scope

- [SCOPE-06] A full materializer scheduler or processor runtime.
- [SCOPE-07] Cross-stream materialization transactions.
- [SCOPE-08] Signed checkpoint attestation or external trust roots.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | The shared engine shall expose a bounded replay API that accepts a stream id, start offset, and maximum record count, returning records in logical stream order across branch-inherited, rolled, restored, and active history. | SCOPE-01 | FR-01 | story: VI1mhEI43 |
| SRS-02 | The hosted protocol and `transit-client` shall expose paged range reads while preserving request id, acknowledgement durability, topology, and remote error semantics. | SCOPE-02 | FR-01 | story: VI1mhEI43 |
| SRS-03 | Materialization checkpoints shall carry materialization id, view kind, source stream id, source offset, source manifest generation/root, source durability, lineage reference, opaque state or state reference, optional snapshot reference, produced-at time, and materializer version. | SCOPE-03 | FR-01 | story: VI1mhEX4z |
| SRS-04 | Resume validation shall reject checkpoints whose lineage anchor, manifest identity, source offset, or persisted checkpoint body no longer matches the authoritative stream state. | SCOPE-03 | FR-01 | story: VI1mhEX4z |
| SRS-05 | Prolly snapshot construction shall be deterministic for sorted entries, preserve correct separator keys, expose lookup and diff APIs, and persist snapshot manifests that cite source lineage. | SCOPE-04 | FR-01 | story: VI1mhEj51 |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Bounded replay shall not require allocating all records in the logical stream to return one page. | SCOPE-01 | NFR-01 | story: VI1mhEI43 |
| SRS-NFR-02 | Checkpoint and snapshot work shall remain outside the default append acknowledgement path. | SCOPE-03, SCOPE-04 | NFR-01 | story: VI1mhEX4z |
| SRS-NFR-03 | Public behavior changes shall be reflected in docs or proof output that operators already use. | SCOPE-05 | NFR-01 | story: VI1mhEj51 |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
