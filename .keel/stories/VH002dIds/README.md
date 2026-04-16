---
# system-managed
id: VH002dIds
status: done
created_at: 2026-04-16T16:19:31
updated_at: 2026-04-16T16:35:30
# authored
title: Prove Restart And Warm-Cache Recovery For Cursors
type: feat
operator-signal:
scope: VGzzXWgvv/VGzzmJ8c8
index: 4
started_at: 2026-04-16T16:34:00
completed_at: 2026-04-16T16:35:30
---

# Prove Restart And Warm-Cache Recovery For Cursors

## Summary

Exercise cursor durability end to end: create cursors, advance them to distinct offsets, restart the engine (and separately drop the warm cache), and verify the cursor positions and metadata match what was written. Confirm the advance ack reports the same durability label as the underlying engine commit for each mode the engine currently proves (local, and tiered where available).

## Acceptance Criteria

- [x] [SRS-NFR-02/AC-01] A recovery test creates multiple cursors, advances them to distinct offsets, restarts the engine, and asserts each cursor's persisted position and metadata match pre-restart values. <!-- verify: cargo test -p transit-core --lib engine::tests::cursor_state_survives_engine_restart_with_distinct_positions_preserved, SRS-NFR-02:start:end, proof: ac-1.log-->
- [x] [SRS-NFR-01/AC-02] Cursor advance ack reports the same durability label as the underlying engine commit, validated by tests that cover local-mode acknowledgement at minimum. <!-- verify: cargo test -p transit-core --lib engine::tests::cursor_advance_ack_reports_local_commitment_for_local_engine, SRS-NFR-01:start:end, proof: ac-2.log-->
- [x] [SRS-NFR-03/AC-03] Cursor operations are covered by a test that asserts stream history is unchanged before and after cursor lifecycle actions. <!-- verify: cargo test -p transit-core --lib engine::tests::cursor_lifecycle_does_not_mutate_stream_history, SRS-NFR-03:start:end, proof: ac-3.log-->
