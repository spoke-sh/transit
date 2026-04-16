# Embedded Cursor Primitive And Engine Storage - SRS

## Summary

Epic: VGzzXWgvv
Goal: Add the cursor primitive to the embedded engine: data model, durable storage, and the advance/ack/lookup/delete operations that the hosted surfaces later wrap.

## Scope

### In Scope

- [SCOPE-01] Cursor data model and durable engine-owned storage for independent reader progress.
- [SCOPE-02] Engine-level create, lookup, list, advance, ack, and delete operations for cursors.
- [SCOPE-03] Restart and warm-cache recovery of cursor state.

### Out of Scope

- [SCOPE-04] Hosted protocol, CLI, and `transit-client` surfaces for cursors; those land in follow-up voyages.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Define a cursor record with `cursor_id`, `stream_id`, durable `Offset` position, `LineageMetadata`, creation timestamp, and last-update timestamp. | SCOPE-01 | FR-01 | test |
| SRS-02 | Persist cursor records in the authoritative local engine directory with an on-disk layout that survives restart and warm-cache loss. | SCOPE-01 | FR-01 | test |
| SRS-03 | Provide engine APIs for `create_cursor`, `get_cursor`, `list_cursors`, `advance_cursor`, `ack_cursor`, and `delete_cursor`. | SCOPE-02 | FR-02 | test |
| SRS-04 | Enforce that cursor advance is monotonic with respect to the stream head and refuses to move backward or past the committed frontier. | SCOPE-02 | FR-04 | test |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Cursor advance ack reports the same durability label as the underlying engine commit (local, replicated, quorum, tiered) without claiming a stronger guarantee. | SCOPE-03 | NFR-01 | test |
| SRS-NFR-02 | Cursor state survives engine restart and warm-cache loss, and the recovery path is exercised by a dedicated test. | SCOPE-03 | NFR-02 | test |
| SRS-NFR-03 | Cursor operations do not mutate stream history or relax the one-writer-per-stream-head model. | SCOPE-02 | NFR-03 | test |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
