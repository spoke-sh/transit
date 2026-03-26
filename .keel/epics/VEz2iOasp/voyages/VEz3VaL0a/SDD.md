# Rust Client Library And Proof - Software Design Description

> Deliver a Rust client crate covering append, read, tail, branch, merge, and lineage inspection with an end-to-end proof example against a local server.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage extends the Rust client crate at `crates/transit-client/src/client.rs` to cover the full transit operation set and delivers a comprehensive proof example. The replacement step for this mission introduced a thin Rust wrapper with `create_root`, `append`, `read`, `create_branch`, and `create_merge`. This voyage fills the remaining gaps: tail sessions with credit-based delivery, lineage inspection, and a proof example that exercises everything.

## Context & Boundaries

The Rust client communicates with a running transit server over the framed wire protocol. It is a thin wrapper: all storage, lineage, and durability semantics live on the server.

```
┌─────────────────────────────────────────────────────────┐
│                   Rust Client                            │
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
| `crates/transit-client/src/client.rs` | existing code | Rust client wrapper with create_root, append, read, create_branch, create_merge | current |
| `transit-cli` server | binary | `transit server run` for local proof | current |
| Transit wire protocol | framed TCP | Request/response envelopes with correlation IDs | current |
| `transit-core::server::RemoteClient` | library | Shared wire-protocol transport used by the Rust wrapper | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| API foundation | Thin wrapper around `transit_core::server::RemoteClient` | Preserves shared wire semantics and avoids a second client protocol implementation |
| Tail session model | Explicit `tail_open()`, `poll()`, `grant_credit()`, and `cancel()` methods | Matches the server's credit-based delivery model |
| Lineage inspection | Single `lineage()` method returning the full DAG for a stream | Matches the server's lineage-inspect operation |
| Proof structure | Single `examples/proof.rs` program that starts a server, exercises all ops, and reports pass/fail | Keeps proof native to the Rust workspace |

## Architecture

The client crate exposes one primary wrapper type:

### TransitClient

Already implements:
- `create_root(stream_id, metadata)` → acknowledged stream status
- `append(stream_id, payload)` → acknowledged append outcome
- `read(stream_id)` → acknowledged read outcome
- `create_branch(stream_id, parent, metadata)` → acknowledged stream status
- `create_merge(stream_id, merge)` → acknowledged stream status

Needs addition:
- `tail_open(stream_id, from_offset, credit)` → tail session handle with explicit lifecycle
- `lineage(stream_id)` → acknowledged lineage outcome with branch/merge DAG

### Wire Protocol Mapping

Each method:
1. `TransitClient` forwards operations to `transit_core::server::RemoteClient`.
2. The shared transport serializes the request envelope and sends it over the framed TCP protocol.
3. The server returns an acknowledgement or error envelope with the operation outcome.
4. The Rust wrapper returns that acknowledgement without reinterpreting server semantics.

## Components

### Tail Session

The tail session follows the server's credit-based model:

1. Client sends `tail-open` with `stream_id`, `from_offset`, and initial `credit`.
2. Server sends records as they become available, decrementing credit.
3. Client sends `tail-grant-credit` to extend the session.
4. Client sends `tail-cancel` to end the session.

The Rust API exposes this as:
```rust
let mut session = client.tail_open(&stream_id, 0, 10)?;
let batch = session.poll()?;
session.grant_credit(10)?;
session.cancel()?;
```

### Lineage Inspection

```rust
let lineage = client.lineage(&stream_id)?;
```

## Interfaces

Public API:

- `TransitClient::new(server_addr)` — constructor
- `create_root(stream_id, metadata)` — create root stream
- `append(stream_id, payload)` — append record
- `read(stream_id)` — full stream replay
- `tail_open(stream_id, from_offset, credit)` — open tail session
- `create_branch(stream_id, parent, metadata)` — branch
- `create_merge(stream_id, merge)` — merge
- `lineage(stream_id)` — lineage DAG inspection

## Data Flow

1. Proof example starts transit server via `cargo run -- server run`.
2. Client connects via TCP.
3. Exercises: create_root → append → read → tail → branch → append to branch → merge → lineage.
4. Each operation verifies the server response matches expectations.
5. Example exits 0 on success, non-zero on failure.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Server not ready | Connection refused on TCP connect | Return transport error; proof helper retries during startup | Server started by proof example with `--serve-for-ms` |
| Server error envelope | Remote error response | Return the server error envelope unchanged | Caller handles based on operation |
| Tail session exhaustion | Empty or exhausted batch state | Return acknowledged batch; caller decides whether to continue | Grant more credit or cancel |
| Unexpected wire format | Decode failure in shared transport | Return protocol/decode error | Investigate wire protocol mismatch |
