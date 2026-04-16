# VOYAGE REPORT: Embedded Cursor Primitive And Engine Storage

## Voyage Metadata
- **ID:** VGzzmJ8c8
- **Epic:** VGzzXWgvv
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 4/4 stories complete

## Implementation Narrative
### Add Cursor Kernel Types And Store
- **ID:** VH002aOaB
- **Status:** done

#### Summary
Introduce the cursor data model in `transit-core::kernel` alongside the existing `StreamId`, `Offset`, and `LineageMetadata` types. Define the `Cursor` record shape, its validated `CursorId`, and the ack envelope that cursor operations will return. This story delivers the types only; persistence and engine API land in sibling stories.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] Cursor record carries `cursor_id`, `stream_id`, durable `Offset`, `LineageMetadata`, creation timestamp, and last-update timestamp, and has unit tests covering construction and serde round-trips. <!-- verify: cargo test -p transit-core --lib kernel::tests::cursor_, SRS-01:start:end, proof: ac-1.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VH002aOaB/EVIDENCE/ac-1.log)

### Persist Cursor Records On The Embedded Engine
- **ID:** VH002bKbO
- **Status:** done

#### Summary
Store cursor records durably under the existing local engine directory with a layout that survives restart and warm-cache loss. Introduce a `CursorStore` collaborator that writes each cursor as a JSON file under a new `cursors/` directory next to the existing manifest and lineage state, and loads all cursors during engine bootstrap.

#### Acceptance Criteria
- [x] [SRS-02/AC-01] `CursorStore` writes a JSON file per cursor under the engine root, reloads them deterministically on restart, and has a test that creates a cursor, restarts the engine, and observes the same position. <!-- verify: cargo test -p transit-core --lib cursor::tests::, SRS-02:start:end, proof: ac-1.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VH002bKbO/EVIDENCE/ac-1.log)

### Expose Engine Cursor Lifecycle API
- **ID:** VH002cJce
- **Status:** done

#### Summary
Add the engine-level cursor API — `create_cursor`, `get_cursor`, `list_cursors`, `advance_cursor`, `ack_cursor`, `delete_cursor` — as thin wrappers around the store plus a stream-frontier check. Advance must refuse to move backward or beyond the committed frontier, and each operation must return explicit errors for missing streams, duplicate IDs, and non-monotonic advances.

#### Acceptance Criteria
- [x] [SRS-03/AC-01] Engine exposes the full cursor lifecycle API with integration tests that cover create, lookup, list, advance, ack, delete, and the monotonicity and frontier-guard error paths. <!-- verify: cargo test -p transit-core --lib engine::tests::cursor_lifecycle_covers_create_lookup_list_advance_ack_and_delete, SRS-03:start:end, proof: ac-1.log-->
- [x] [SRS-04/AC-02] Advance refuses non-monotonic moves and moves past the committed frontier, with explicit error variants and test coverage. <!-- verify: cargo test -p transit-core --lib engine::tests::cursor_advance_refuses_backward_moves_and_frontier_overrun, SRS-04:start:end, proof: ac-2.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VH002cJce/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VH002cJce/EVIDENCE/ac-2.log)

### Prove Restart And Warm-Cache Recovery For Cursors
- **ID:** VH002dIds
- **Status:** done

#### Summary
Exercise cursor durability end to end: create cursors, advance them to distinct offsets, restart the engine (and separately drop the warm cache), and verify the cursor positions and metadata match what was written. Confirm the advance ack reports the same durability label as the underlying engine commit for each mode the engine currently proves (local, and tiered where available).

#### Acceptance Criteria
- [x] [SRS-NFR-02/AC-01] A recovery test creates multiple cursors, advances them to distinct offsets, restarts the engine, and asserts each cursor's persisted position and metadata match pre-restart values. <!-- verify: cargo test -p transit-core --lib engine::tests::cursor_state_survives_engine_restart_with_distinct_positions_preserved, SRS-NFR-02:start:end, proof: ac-1.log-->
- [x] [SRS-NFR-01/AC-02] Cursor advance ack reports the same durability label as the underlying engine commit, validated by tests that cover local-mode acknowledgement at minimum. <!-- verify: cargo test -p transit-core --lib engine::tests::cursor_advance_ack_reports_local_commitment_for_local_engine, SRS-NFR-01:start:end, proof: ac-2.log-->
- [x] [SRS-NFR-03/AC-03] Cursor operations are covered by a test that asserts stream history is unchanged before and after cursor lifecycle actions. <!-- verify: cargo test -p transit-core --lib engine::tests::cursor_lifecycle_does_not_mutate_stream_history, SRS-NFR-03:start:end, proof: ac-3.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VH002dIds/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VH002dIds/EVIDENCE/ac-2.log)
- [ac-3.log](../../../../stories/VH002dIds/EVIDENCE/ac-3.log)


