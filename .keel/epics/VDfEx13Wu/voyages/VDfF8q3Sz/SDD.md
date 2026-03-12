# Wire Protocol Hardening And Mission Proof - Software Design Description

> Stabilize the first server wire contract, client ergonomics, and operator mission proof while keeping transport underlay and replication concerns explicit.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage turns the daemon from "reachable" into "usable." It defines the first stable protocol envelope, makes remote acknowledgement and streaming semantics explicit, adds a CLI client surface, and upgrades `just mission` so humans can verify server mode without reverse-engineering transport details. It also encodes the architectural boundary that WireGuard or similar tooling may secure the network path but do not replace the `transit` protocol.

## Context & Boundaries

In scope: the application protocol envelope, streaming-tail session model, CLI client workflows, and mission proof automation.

Out of scope: replication, public ingress, browser protocol work, and implementing WireGuard as an application transport.

```
┌────────────────────────────────────────────────────────────┐
│                 Wire Contract And Proof                   │
│                                                            │
│  protocol envelope -> session control -> CLI client        │
│                              \\-> just mission proof        │
└────────────────────────────────────────────────────────────┘
          ↑                                     ↑
   transport underlay                    human/operator proof
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| Voyage `VDfF629DK` daemon surface | internal board dependency | Provides the server lifecycle and core remote operations to harden | planned |
| CLI crate | internal crate | Hosts client commands and mission proof entrypoints | workspace |
| Transport runtime | implementation choice | Carries framed requests, responses, and streaming sessions | TBD during implementation |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Protocol framing | Use an explicit request and response envelope with correlation IDs | Prevents implicit socket behavior from becoming protocol contract |
| Tail lifecycle | Treat tail as a long-lived session with explicit flow control and cancellation | Streaming needs first-class lifecycle semantics |
| Underlay boundary | Keep WireGuard as optional secure deployment underlay only | Preserves a clean application protocol for broader deployment choices |
| Proof path | Exercise server mode through CLI plus `just mission` | Keeps human verification aligned with repo norms |

## Architecture

The voyage adds four reinforcing layers:

- a protocol envelope shared by client and server
- a session-control layer for streaming tail behavior
- a CLI client surface for remote workflows
- a mission proof that boots the server, runs client operations, and validates the transport boundary assumptions

## Components

- `protocol envelope`
  Defines request IDs, operation payloads, success acknowledgements, and error responses.
- `tail session controller`
  Tracks subscriptions, delivery pacing, cancellation, and reconnect boundaries.
- `CLI client`
  Exposes remote workflows through operator-friendly commands and proof scripts.
- `mission proof harness`
  Orchestrates server startup, remote operations, and verification that the protocol remains single-node and underlay-agnostic.

## Interfaces

Primary interface families:

- unary request/response operations for append, read, branch, merge, and inspect
- streaming tail sessions with explicit session identifiers or equivalent correlation
- CLI commands that mirror the remote operation set closely enough for proof and debugging

The protocol should carry durability and error information explicitly instead of requiring clients to infer commit state from transport success alone.

## Data Flow

1. CLI or client builds a protocol envelope and sends it over the selected transport.
2. Server correlates the request, performs the engine operation, and returns an explicit acknowledgement or error.
3. For tail sessions, the client establishes a streaming context and the server emits records under explicit flow-control rules.
4. `just mission` runs the daemon and CLI end to end, then validates that the proof did not depend on replication or a specific secure underlay.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Framing or correlation mismatch | Protocol decode or validation failure | Return protocol error or terminate session | Client rebuilds request with valid envelope |
| Tail subscriber overload | Backpressure thresholds or send failure | Pause, drop, or terminate session per explicit policy | Client reconnects from known position |
| Client/server version drift | Capability or decode mismatch | Return explicit incompatibility error | Upgrade client or server |
| Underlay assumption leak | Mission proof or docs show protocol depends on one secure mesh | Fail verification and document boundary violation | Refine transport abstraction before release |
