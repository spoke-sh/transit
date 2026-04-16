---
# system-managed
id: VH002bKbO
status: backlog
created_at: 2026-04-16T16:19:31
updated_at: 2026-04-16T16:21:25
# authored
title: Persist Cursor Records On The Embedded Engine
type: feat
operator-signal:
scope: VGzzXWgvv/VGzzmJ8c8
index: 2
---

# Persist Cursor Records On The Embedded Engine

## Summary

Store cursor records durably under the existing local engine directory with a layout that survives restart and warm-cache loss. Introduce a `CursorStore` collaborator that writes each cursor as a JSON file under a new `cursors/` directory next to the existing manifest and lineage state, and loads all cursors during engine bootstrap.

## Acceptance Criteria

- [ ] [SRS-02/AC-01] `CursorStore` writes a JSON file per cursor under the engine root, reloads them deterministically on restart, and has a test that creates a cursor, restarts the engine, and observes the same position. <!-- verify: test, SRS-02:start:end -->
