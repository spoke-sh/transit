# Replay-Driven Projection Consumer API - Software Design Description

> Publish a generic transit-client projection consumer surface that derives replaceable views from authoritative replay without creating a projection-only server truth path.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage extends the canonical Rust hosted client with a generic
projection-consumer helper. The helper composes the existing hosted read
surface with a consumer-supplied reducer so downstream Rust repos can derive
replaceable views from authoritative replay without needing a private
projection-read wrapper or a projection-only server truth path.

## Context & Boundaries

Transit already publishes hosted append, replay, lineage, and tail operations
plus local reference-projection proofs. The missing piece is a reusable Rust
client helper that lets downstream code consume replay into projection views
through the upstream client boundary itself.

In scope: generic projection-consumer request/outcome types, reducer traits,
and proof coverage against the hosted server.

Out of scope: consumer-specific schema, reducer policy, or a server-owned
mutable projection database.

```
┌──────────────────────────────────────────────────────────────┐
│                    Hosted Transit Server                    │
│              authoritative stream replay surface            │
└───────────────────────────────┬──────────────────────────────┘
                                │ hosted read
┌───────────────────────────────┴──────────────────────────────┐
│                  transit-client projection API               │
│        request + ack-preserving replay + consumer reducer    │
└───────────────────────────────┬──────────────────────────────┘
                                │ current view
┌───────────────────────────────┴──────────────────────────────┐
│                 Downstream Consumer Read Model               │
│         consumer-owned projection payload and semantics      │
└──────────────────────────────────────────────────────────────┘
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `transit-core::server::RemoteClient` | existing crate surface | Supplies the authoritative hosted read request/ack boundary that the helper composes. | current |
| `transit-client` proof example and tests | existing verification surface | Demonstrates the new helper against a running hosted server. | current |
| Reference projection workload fixture | local test-only fixture | Proves the helper stays generic while still exercising a real projection flow. | voyage-local |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Server contract | Reuse the existing hosted replay/read operation instead of adding a projection-only server API | Keeps projection reads replay-anchored and avoids a second mutable truth path |
| API ownership | Publish the helper in `transit-client` rather than forcing each downstream repo to author its own wrapper | Makes the upstream cutover contract literal and reusable |
| Projection semantics | Require callers to supply the reducer and output view type | Preserves consumer ownership of schema and policy |
| Response posture | Preserve hosted acknowledgement/request metadata while enriching the body with projection outcome details | Keeps the helper aligned with the canonical hosted contract |

## Architecture

The voyage adds two client-side components:

- `ProjectionReadConsumer`
  Consumer-owned reducer contract applied over hosted replay.
- `ProjectionReadRequest` / `ProjectionReadOutcome`
  Generic request and result vocabulary for replay-driven projection reads.

## Components

- `ProjectionReadConsumer`
  Purpose: define how a downstream caller initializes and reduces a current
  view from hosted replay records.
- `TransitClient::read_projection`
  Purpose: compose hosted replay with a consumer reducer, then return the
  reduced view together with authoritative acknowledgement metadata.
- `Projection proof fixture`
  Purpose: prove a hosted client can derive a representative reference view
  through the new helper without embedded authority.

## Interfaces

- Input: projection stream reference plus optional consumer checkpoint/revision
  token if the caller wants to carry one.
- Reducer: caller-supplied logic that initializes view state and applies each
  replayed record.
- Output: reduced current view plus projection revision/head metadata wrapped in
  the hosted acknowledgement envelope.

## Data Flow

1. Downstream code calls `TransitClient::read_projection(...)` for a projection
   stream.
2. `transit-client` issues the existing hosted read request to the server.
3. The helper walks the authoritative replay in order and invokes the
   caller-supplied reducer.
4. The helper derives projection revision/head metadata from the replay
   frontier.
5. The helper returns the reduced view inside the same hosted acknowledgement
   wrapper used by other `transit-client` operations.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Consumer reducer rejects a payload | Reducer returns an error while processing replay | Surface a client-side protocol error with the failing replay context | Fix the consumer reducer or payload contract |
| Helper starts depending on server-owned projection truth | Design requires a new mutable server API or hidden state | Treat the voyage as incorrect | Keep projection reads composed from hosted replay only |
| API starts codifying consumer schema | Review finds auth- or product-specific payload meaning inside Transit | Reject the implementation | Push schema semantics back to the consumer reducer |
