# Deliver Hosted Materialization Cursor And Resume Surface - Software Design Description

> Let external-daemon Rust consumers checkpoint materialization progress, verify hosted resume anchors, and replay only records after the last acknowledged materialization checkpoint.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage extends the hosted Transit surface with materialization-aware progress primitives. The server remains the authoritative owner of stream history, lineage, manifests, and replay boundaries. Hosted consumers gain cursor and checkpoint metadata that are derived from those shared-engine facts and exposed through the remote protocol plus `transit-client`.

## Context & Boundaries

The design adds hosted metadata and APIs for materializer progress. It does not move materialized state into authoritative stream truth and does not require downstream applications to embed `LocalEngine`.

```
┌───────────────────────────────────────────────────────────────┐
│                  Hosted Materialization Plane                │
│                                                               │
│  transit-client  ->  hosted protocol  ->  transit-server      │
│       |                      |                    |            │
│       |                      |                    v            │
│       |                      |             shared engine       │
│       |                      |           lineage + replay      │
│       v                      v                                 │
│  client reducer state   cursor/checkpoint metadata            │
└───────────────────────────────────────────────────────────────┘
          ↑                                           ↑
   external daemon app                         authoritative log
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `transit-core` lineage and replay primitives | Internal library | Bind hosted checkpoints to source stream identity and replay boundaries. | Workspace |
| Hosted server protocol | Internal protocol | Carry cursor, checkpoint, and resume requests across the daemon boundary. | Current remote protocol |
| `transit-client` Rust SDK | Internal library | Expose the canonical client-first materialization workflow. | Workspace |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hosted progress model | Separate hosted cursor and checkpoint primitives, both bound to source stream identity. | Cursor lifecycle and opaque checkpoint state solve different user needs but can share verification facts. |
| Verification anchor | Bind hosted checkpoints to lineage or manifest identity plus an anchored source position. | Resume must reject drift instead of replaying blindly from a stale offset. |
| Authority split | Keep materializer state opaque and client-owned while keeping source-of-truth lineage and replay facts server-owned. | Preserves Transit's model that derived state is rebuildable and not part of stream truth. |
| Client entry point | `transit-client` is the canonical Rust surface for hosted materialization. | External-daemon consumers should not reach into local-engine APIs. |

## Architecture

The shared engine continues to own stream status, replay windows, manifests, and lineage checkpoints. The hosted server layer adds persistence and protocol handlers for cursor and checkpoint metadata. The Rust client wraps those operations in a materialization-oriented API that can obtain a checkpoint, validate resume, and fetch only post-anchor records.

## Components

- Hosted server materialization store:
  Persists cursor and checkpoint metadata keyed by materialization id and source stream id, and resolves them against shared-engine replay facts.
- Hosted protocol operations:
  Adds request and response shapes for cursor lifecycle, checkpoint creation or retrieval, and resume or pending-record fetch.
- `transit-client` hosted materialization API:
  Wraps remote operations in a client-first workflow that returns typed checkpoints, resume cursors, and pending records for reducers.
- Proof and documentation layer:
  Demonstrates the end-to-end external-daemon workflow and explains verification and failure behavior.

## Interfaces

- Cursor lifecycle:
  Create, inspect, advance, and delete cursor state for a materialization id and source stream.
- Checkpoint envelope:
  Return a typed hosted checkpoint containing materialization id, source stream id, anchored position, verification identity, opaque state bytes, and produced-at timestamp.
- Resume flow:
  Accept a hosted checkpoint or cursor reference, verify it against current source lineage or manifest state, and return pending records beginning strictly after the anchor position.

## Data Flow

1. The client reduces replayed records into opaque materializer state.
2. The client asks the hosted surface to checkpoint or advance cursor state for that materialization id and source stream.
3. The server binds that progress to current shared-engine replay and lineage facts and persists the hosted metadata.
4. On restart, the client loads the hosted checkpoint or cursor, asks the server to resume, and receives only records after the anchored position.
5. The client reduces new records and repeats the checkpoint cycle.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Hosted checkpoint anchor no longer verifies against current lineage or manifest state | Resume validation fails on the server | Reject resume with an explicit hosted verification error | Operator or client restarts from a new full replay or a newer valid checkpoint |
| Cursor or checkpoint metadata is missing for the requested materialization id | Lookup returns not found | Return a typed not-found response | Client creates a fresh cursor or performs an initial replay |
| Pending replay window cannot supply the anchor record | Resume detects missing anchor or truncated history | Reject incremental resume | Client performs a bounded or full rebuild based on current retained history |
| Client attempts to use hosted materialization APIs without staying on the daemon boundary | API composition would require `LocalEngine` | Keep the workflow in `transit-client` only | Redirect implementation to hosted primitives instead of local engine types |
