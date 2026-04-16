---
# system-managed
id: VH002cJce
status: backlog
created_at: 2026-04-16T16:19:31
updated_at: 2026-04-16T16:21:25
# authored
title: Expose Engine Cursor Lifecycle API
type: feat
operator-signal:
scope: VGzzXWgvv/VGzzmJ8c8
index: 3
---

# Expose Engine Cursor Lifecycle API

## Summary

Add the engine-level cursor API — `create_cursor`, `get_cursor`, `list_cursors`, `advance_cursor`, `ack_cursor`, `delete_cursor` — as thin wrappers around the store plus a stream-frontier check. Advance must refuse to move backward or beyond the committed frontier, and each operation must return explicit errors for missing streams, duplicate IDs, and non-monotonic advances.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] Engine exposes the full cursor lifecycle API with integration tests that cover create, lookup, list, advance, ack, delete, and the monotonicity and frontier-guard error paths. <!-- verify: test, SRS-03:start:end -->
- [ ] [SRS-04/AC-02] Advance refuses non-monotonic moves and moves past the committed frontier, with explicit error variants and test coverage. <!-- verify: test, SRS-04:start:end -->
