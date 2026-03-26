# Python Client Library And Proof - Software Design Description

> Deliver a Python client covering append, read, tail, branch, merge, and lineage inspection with an end-to-end proof script against a local server.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage extends the existing Python client at `clients/python/transit_client.py` to cover the full transit operation set (including tail sessions, merge, and lineage inspection) and delivers a comprehensive proof script. The existing client already covers `create_root`, `append`, `read`, `create_branch`, and `create_merge`. This voyage fills the gaps: tail sessions with credit-based delivery, lineage inspection, and a proof script that exercises everything.

## Context & Boundaries

The Python client communicates with a running transit server over the framed wire protocol. It is a thin wrapper — all storage, lineage, and durability semantics live on the server.

```
┌─────────────────────────────────────────────────────────┐
│                  Python Client                           │
│                                                         │
│  create_root  append  read  tail  branch  merge lineage │
└────────────────────────┬────────────────────────────────┘
                         │ TCP framed protocol
┌────────────────────────┴────────────────────────────────┐
│                  Transit Server                          │
│                                                         │
│               SharedEngine (transit-core)                │
└─────────────────────────────────────────────────────────┘
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `clients/python/transit_client.py` | existing code | Existing client with create_root, append, read, create_branch, create_merge | current |
| `transit-cli` server | binary | `transit server run` for local proof | current |
| Transit wire protocol | framed TCP | Request/response envelopes with correlation IDs | current |
| Python 3 standard library | runtime | `socket`, `struct`, `json` | 3.x |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| IO model | Synchronous sockets | Simplest first client; async can come later without changing the API shape |
| Tail session model | Synchronous poll loop with explicit credit grants | Matches the server's credit-based delivery model |
| Lineage inspection | Single `lineage()` method returning the full DAG for a stream | Matches the server's lineage-inspect operation |
| Proof structure | Single `proof.py` script that starts server, exercises all ops, reports pass/fail | Follows the existing `just python-client-proof` pattern |

## Architecture

The client is a single Python module with one class:

### TransitClient

Already implements:
- `create_root(stream_id, actor, reason)` → `(ack, outcome)`
- `append(stream_id, payload)` → `(ack, outcome)`
- `read(stream_id)` → `(ack, outcome)`
- `create_branch(stream_id, parent_stream_id, parent_offset, actor, reason)` → `(ack, outcome)`
- `create_merge(stream_id, parents)` → `(ack, outcome)`

Needs addition:
- `tail(stream_id, from_offset, max_records)` → iterator of `(ack, outcome)` with explicit session lifecycle
- `lineage(stream_id)` → `(ack, outcome)` with branch/merge DAG

### Wire Protocol Mapping

Each method:
1. Builds a request envelope with `correlation_id`, `operation`, and operation-specific fields.
2. Serializes to JSON, prepends a 4-byte big-endian length frame.
3. Sends over TCP socket.
4. Reads 4-byte length frame, deserializes JSON response.
5. Returns `(ack_envelope, operation_outcome)` without reinterpreting server semantics.

## Components

### Tail Session

The tail session follows the server's credit-based model:

1. Client sends `tail-open` with `stream_id`, `from_offset`, and initial `credit`.
2. Server sends records as they become available, decrementing credit.
3. Client sends `tail-grant-credit` to extend the session.
4. Client sends `tail-cancel` to end the session.

The Python API exposes this as:
```python
session = client.tail_open(stream_id, from_offset=0, credit=10)
records = session.poll()       # returns available records
session.grant_credit(10)       # extend
session.cancel()               # close
```

### Lineage Inspection

```python
result = client.lineage(stream_id)
# result.outcome contains branch/merge DAG
```

## Interfaces

Public API:

- `TransitClient(host, port)` — constructor
- `create_root(stream_id, actor=None, reason=None)` — create root stream
- `append(stream_id, payload)` — append record
- `read(stream_id)` — full stream replay
- `tail_open(stream_id, from_offset, credit)` — open tail session
- `create_branch(stream_id, parent_stream_id, parent_offset, actor=None, reason=None)` — branch
- `create_merge(stream_id, parents)` — merge
- `lineage(stream_id)` — lineage DAG inspection

## Data Flow

1. Proof script starts transit server via `cargo run -- server run`.
2. Client connects via TCP.
3. Exercises: create_root → append → read → tail → branch → append to branch → merge → lineage.
4. Each operation verifies the server response matches expectations.
5. Script exits 0 on success, non-zero on failure.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Server not ready | Connection refused on TCP connect | Retry with backoff (proof script waits for server startup) | Server started by proof script with `--serve-for-ms` |
| Server error envelope | `ack.status` is not `ok` | Raise exception with server error details | Caller handles based on operation |
| Tail session timeout | No records received within poll window | Return empty batch; caller decides whether to continue | Grant more credit or cancel |
| Unexpected wire format | JSON decode error on response | Raise protocol error with raw bytes | Investigate wire protocol mismatch |
