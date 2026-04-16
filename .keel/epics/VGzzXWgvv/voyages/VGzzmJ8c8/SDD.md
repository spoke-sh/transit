# Embedded Cursor Primitive And Engine Storage - Software Design Description

> Add the cursor primitive to the embedded engine: data model, durable storage, and the advance/ack/lookup/delete operations that the hosted surfaces later wrap.

**SRS:** [SRS.md](SRS.md)

## Overview

Introduce `Cursor` as a first-class kernel entity alongside `StreamId`, `Offset`, and `LineageMetadata`. The embedded engine owns authoritative cursor state, persists it under the existing local engine directory, and exposes create / lookup / list / advance / ack / delete operations. Cursor advance is monotonic with respect to the committed stream frontier and returns the same durability label Transit already reports for appends. This voyage delivers only the embedded primitive and its persistence; hosted protocol, CLI, and client wrappers land in later voyages.

## Context & Boundaries

In scope: kernel types, engine methods, on-disk layout, tests. Out of scope: remote protocol envelope wiring, CLI, client surfaces, materialization engine changes.

```
┌─────────────────────────────────────────┐
│              This Voyage                │
│                                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  │
│  │ Cursor  │  │ Engine  │  │ Cursor  │  │
│  │  model  │  │   API   │  │  store  │  │
│  └─────────┘  └─────────┘  └─────────┘  │
└─────────────────────────────────────────┘
        ↑               ↑            ↑
   [kernel.rs]     [engine.rs]  [local dir]
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `transit-core::kernel` | internal | Shares `StreamId`, `Offset`, `LineageMetadata` types | current |
| `transit-core::engine` | internal | Hosts the new cursor APIs next to existing append/replay | current |
| `serde` + `serde_json` | external | Persist cursor records as JSON alongside existing engine state | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Cursor identifier shape | Client-provided opaque string validated like `StreamId` | Lets callers pick stable names without the engine owning a naming authority. |
| Storage location | New `cursors/` directory under the engine root, one JSON file per cursor | Matches existing per-entity file layout and keeps the manifest untouched. |
| Advance semantics | Monotonic-forward only, capped at the current committed frontier | Keeps the one-writer invariant intact and prevents reading uncommitted bytes. |
| Concurrent cursor writes | Last-writer-wins on distinct cursor IDs; a later voyage may add compare-and-advance | Ship the primitive now; upgrade to CAS once downstream demand is clear. |

## Architecture

Cursor types live in `transit-core::kernel`. The engine gains a `CursorStore` collaborator that reads and writes cursor files under the engine root. Engine methods (`create_cursor`, `get_cursor`, `list_cursors`, `advance_cursor`, `ack_cursor`, `delete_cursor`) are thin wrappers around the store plus a stream-frontier check.

## Components

- **`Cursor` record** (`kernel.rs`): `cursor_id`, `stream_id`, `position: Offset`, `metadata: LineageMetadata`, `created_at`, `updated_at`.
- **`CursorStore`** (`engine.rs` or a new `cursor.rs`): owns the `cursors/` directory, writes each cursor as `cursors/<cursor_id>.json`, reads on startup for recovery.
- **Engine cursor API**: validates the bound stream exists, clamps advance to the committed frontier, emits a durability label sourced from the underlying engine commit.

## Interfaces

```
fn create_cursor(&self, id: CursorId, stream_id: StreamId, metadata: LineageMetadata) -> Result<Cursor>
fn get_cursor(&self, id: &CursorId) -> Result<Option<Cursor>>
fn list_cursors(&self, stream_id: Option<&StreamId>) -> Result<Vec<Cursor>>
fn advance_cursor(&self, id: &CursorId, position: Offset) -> Result<CursorAck>
fn ack_cursor(&self, id: &CursorId, position: Offset) -> Result<CursorAck>
fn delete_cursor(&self, id: &CursorId) -> Result<()>
```

`CursorAck` carries `position`, `durability`, and `topology` fields using the same vocabulary as `AppendAck`.

## Data Flow

1. Caller invokes `create_cursor`; engine validates the stream, persists the record, returns the created `Cursor`.
2. Caller reads records via existing replay/tail APIs.
3. Caller invokes `advance_cursor` with the offset it has processed. Engine clamps to frontier, updates the file, emits ack.
4. On restart, the engine reloads all cursor files before serving reads.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Bound stream does not exist | `create_cursor` pre-check | Return `CursorError::StreamNotFound` | Caller creates stream or fixes ID |
| Advance beyond committed frontier | `advance_cursor` frontier check | Return `CursorError::BeyondFrontier` | Caller retries after frontier advances |
| Advance moves backward | `advance_cursor` monotonicity check | Return `CursorError::NonMonotonic` | Caller reconciles its own progress state |
| Corrupt cursor file on load | JSON parse on restart | Log explicit error; skip that cursor | Operator deletes or repairs the file |
| Duplicate cursor ID on create | Existence check before write | Return `CursorError::AlreadyExists` | Caller picks a fresh ID or calls advance on the existing one |
