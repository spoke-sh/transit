---
# system-managed
id: VH002aOaB
status: done
created_at: 2026-04-16T16:19:31
updated_at: 2026-04-16T16:25:44
# authored
title: Add Cursor Kernel Types And Store
type: feat
operator-signal:
scope: VGzzXWgvv/VGzzmJ8c8
index: 1
started_at: 2026-04-16T16:23:58
completed_at: 2026-04-16T16:25:44
---

# Add Cursor Kernel Types And Store

## Summary

Introduce the cursor data model in `transit-core::kernel` alongside the existing `StreamId`, `Offset`, and `LineageMetadata` types. Define the `Cursor` record shape, its validated `CursorId`, and the ack envelope that cursor operations will return. This story delivers the types only; persistence and engine API land in sibling stories.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Cursor record carries `cursor_id`, `stream_id`, durable `Offset`, `LineageMetadata`, creation timestamp, and last-update timestamp, and has unit tests covering construction and serde round-trips. <!-- verify: cargo test -p transit-core --lib kernel::tests::cursor_, SRS-01:start:end, proof: ac-1.log-->
