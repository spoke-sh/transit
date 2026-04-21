# Deliver Hosted Batch Append Surface - Software Design Description

> Add single-stream batch append across the hosted protocol, server, Rust client, and CLI so downstream producers can amortize remote append overhead while preserving ordinary Transit record semantics.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage extends the existing append path rather than inventing a second producer contract. The shared engine gains a single-stream batch append primitive that persists multiple payloads atomically as ordinary records. The hosted server protocol exposes that primitive through `AppendBatch`, the Rust client publishes `append_batch(...)`, and the CLI exposes the same capability through the existing remote append surface. Centralized batch limits keep failure behavior explicit and testable.

## Context & Boundaries

The batching slice sits entirely inside the existing hosted request/response boundary. It changes write-path throughput characteristics for one stream but does not change how records are stored, replayed, tailed, checkpointed, or materialized after acknowledgement.

```text
┌─────────────────────────────────────────────────────────────┐
│                    Hosted Batch Append                      │
│                                                             │
│  CLI / TransitClient  ->  RemoteClient / protocol  -> server│
│                                         -> LocalEngine      │
│                                                             │
│  read/tail/checkpoint/materialize continue per-record       │
└─────────────────────────────────────────────────────────────┘
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `crates/transit-core/src/engine.rs` | shared engine | authoritative append semantics and persisted record layout | current |
| `crates/transit-core/src/server.rs` | hosted protocol | request/response envelopes, remote client, server dispatch | current |
| `crates/transit-client` | Rust wrapper | canonical downstream Rust surface for hosted operations | current |
| `crates/transit-cli` | operator/proof surface | CLI coverage for remote append flows and proof/test usage | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Batch ownership | Add a shared-engine batch append primitive instead of looping record-at-a-time in the server or client | Preserves one authoritative write semantic path and allows atomic success/failure at the stream batch boundary |
| Scope | Support one stream per batch request only | Matches the upstream request and avoids accidental drift into cross-stream transactions |
| Limits | Centralize record-count and byte limits in the hosted protocol layer and reuse them from server/client surfaces | Keeps failure behavior explicit and aligned across wrappers |
| CLI shape | Extend the existing remote append surface to accept multiple payload values rather than creating a second semantically-overlapping command | Keeps the operator surface small while making batching testable |

## Architecture

The voyage touches four layers:

1. `LocalEngine` provides `append_batch(...)` for one stream and returns batch acknowledgement metadata.
2. The hosted protocol adds `AppendBatch` / `AppendBatchOk` plus validation helpers for centralized limits.
3. `TransitClient` forwards batch requests as a thin wrapper over the hosted protocol client.
4. The CLI maps repeated payload input onto the batch surface and reports batch acknowledgement data in human and JSON output.

## Components

### Shared Engine

- Persists multiple payloads to the active segment as ordinary records.
- Rolls segments as needed while preserving contiguous offsets.
- Commits the batch atomically for one stream by surfacing success only after the full batch is durably appended.

### Hosted Protocol

- Adds `OperationRequest::AppendBatch { stream_id, payloads }`.
- Adds `OperationResponse::AppendBatchOk(...)`.
- Validates record-count and byte limits before execution and returns normal hosted invalid-request envelopes on limit failure.

### Rust Client

- Adds `TransitClient::append_batch(...)`.
- Preserves the outer `RemoteAcknowledged<_>` envelope and hosted error surface literally.

### CLI

- Reuses the remote append workflow with repeated payload input so proofs and tests can drive batching through the published operator surface.
- Reports first position, last position, record count, and rolled segments in output/JSON.

## Interfaces

Public surfaces introduced or changed by this voyage:

- `LocalEngine::append_batch(&StreamId, payloads)`
- `OperationRequest::AppendBatch { stream_id, payloads }`
- `OperationResponse::AppendBatchOk(RemoteBatchAppendOutcome)`
- `TransitClient::append_batch(&StreamId, payloads)`
- CLI remote append path with repeated payload input for batching

The response contract remains single-stream and returns:

- `first_position`
- `last_position`
- `record_count`
- `manifest_generation`
- `rolled_segment_ids`

## Data Flow

1. Caller supplies one stream id plus `N` payloads through the CLI or `TransitClient`.
2. The hosted client validates limits and sends one `AppendBatch` request.
3. The server validates limits again, then calls the shared-engine batch append primitive.
4. The shared engine writes `N` persisted records in order, rolling segments if thresholds are crossed.
5. The server returns one acknowledgement containing the batch outcome metadata.
6. Subsequent read/tail calls observe the newly committed records individually.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Empty batch | Input validation before execution | Reject as invalid request | Caller submits at least one payload |
| Batch exceeds count limit | Client/server validation helper | Return hosted invalid-request error | Caller splits the workload into smaller batches |
| Batch exceeds byte limit | Client/server validation helper | Return hosted invalid-request error | Caller reduces payload volume per request |
| Missing stream or leadership rejection | Existing engine validation | Return normal hosted error envelope | Caller creates the stream or retries against the writable leader |
| Partial persistence risk during batch execution | Shared-engine batch append design | Surface success only for a fully committed batch | Investigate implementation/test failure; no alternative partial-success contract is introduced |
