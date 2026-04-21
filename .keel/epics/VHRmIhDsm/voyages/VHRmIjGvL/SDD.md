# Deliver Hosted Transport Robustness Improvements - Software Design Description

> Add configurable hosted I/O timeouts and concurrent connection handling so sustained producer/consumer workloads stop routinely failing with 1s transport timeouts.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage hardens the hosted transport runtime without changing protocol meaning. The hosted server gains configurable connection I/O timeout and concurrent connection serving, the Rust client surfaces matching timeout configuration, and the CLI/server proof path exercises a mixed producer/consumer workload with raised timeouts. The existing request/response model, append semantics, and tail semantics remain unchanged.

## Context & Boundaries

The robustness slice sits entirely inside the current hosted boundary. It changes how long sockets wait and how accepted connections are scheduled, but it does not change what an append, read, or tail request means once it is processed.

```text
┌─────────────────────────────────────────────────────────────┐
│             Hosted Transport Robustness Slice              │
│                                                             │
│  CLI / TransitClient -> RemoteClient -> server accept loop  │
│                                        -> connection worker │
│                                        -> LocalEngine       │
│                                                             │
│  append/read/tail semantics remain unchanged                │
└─────────────────────────────────────────────────────────────┘
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `crates/transit-core/src/server.rs` | hosted runtime | socket timeout configuration, accept loop, request dispatch, remote client | current |
| `crates/transit-client` | Rust wrapper | canonical downstream timeout configuration surface over the hosted client | current |
| `crates/transit-cli` | operator/proof surface | CLI/server proof coverage and operator-facing timeout configuration | current |
| `std::net::TcpListener` / `TcpStream` | transport runtime | accepted connection handling and socket timeout enforcement | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Timeout ownership | Add explicit timeout setters to server and client wrappers instead of silently bumping the default only | Keeps the contract explicit for downstream users who need to tune the hosted boundary deliberately |
| Concurrency model | Hand accepted connections off for concurrent serving rather than processing them inline in the listener loop | Removes producer/consumer head-of-line blocking without requiring a larger protocol redesign |
| Scope boundary | Keep one connection per request and do not add pooling/reuse in this voyage | Matches the upstream request and keeps the fix bounded to the current failure mode |
| Proof strategy | Drive a mixed producer/consumer workload through CLI/server proof coverage with raised timeouts | Demonstrates operational robustness on the published surface rather than only in unit tests |

## Architecture

The voyage changes three layers:

1. Hosted server runtime: configurable socket timeouts plus concurrent accepted-connection handling.
2. Hosted Rust client surfaces: configurable client-side socket timeout at both `RemoteClient` and `TransitClient`.
3. Operator proof surface: CLI/server proof path that applies raised timeouts and exercises mixed producer/consumer traffic.

## Components

### Hosted Server Runtime

- Owns accepted TCP connections and request dispatch into `LocalEngine`.
- Adds explicit connection I/O timeout configuration to `ServerConfig`.
- Stops processing accepted connections strictly inline in the listener thread.

### Hosted Rust Client

- Adds explicit client-side I/O timeout configuration to `RemoteClient`.
- Mirrors that surface through `TransitClient` so downstream callers do not need to drop into `transit-core::server`.

### CLI / Proof Surface

- Publishes a proof/test path that configures raised hosted timeouts.
- Exercises producer append and consumer poll/tail traffic concurrently against the same hosted server.
- Documents that the knobs change runtime behavior, not protocol semantics.

## Interfaces

Public or semi-public interfaces introduced or changed by this voyage:

- `ServerConfig::with_connection_io_timeout(Duration)`
- `RemoteClient::with_io_timeout(Duration)`
- `TransitClient::with_io_timeout(Duration)` or an equivalent wrapper constructor path
- CLI/server proof configuration that can raise hosted timeout values explicitly

The wire protocol itself is intentionally unchanged. Requests and responses remain the same append/read/tail shapes.

## Data Flow

1. Caller configures raised client and server timeouts through the supported API or proof surface.
2. The server listener accepts a connection and immediately hands it to a concurrent worker path.
3. Additional producer or consumer connections continue to be accepted while earlier requests are in flight.
4. Each worker serves the existing hosted request/response protocol against the shared engine.
5. Producer append and consumer poll/tail traffic complete without routine 1s transport timeout failure when the configured timeout exceeds the actual work duration.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Timeout left at the default 1s for a heavier workload | Transport error or proof failure under sustained load | Preserve the explicit failure rather than hiding it | Caller raises the supported timeout knobs for that deployment |
| Server timeout configured but client timeout left too low | Client-side socket timeout expires before response arrives | Surface normal transport error | Tune the client and server timeouts coherently |
| Concurrent worker handoff fails | Listener/runtime error | Surface server failure and fail targeted tests | Fix worker lifecycle/dispatch handling before rollout |
| Protocol semantics accidentally drift while hardening transport | Targeted append/read/tail regression tests fail | Block rollout | Rework implementation to keep protocol meaning unchanged |
