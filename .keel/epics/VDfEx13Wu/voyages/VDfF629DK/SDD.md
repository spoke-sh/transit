# Server Daemon And Core Lineage RPCs - Software Design Description

> Deliver the first single-node transit daemon on the shared engine with remote append, read, tail, branch, merge, and lineage inspection semantics.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage establishes the first network boundary around the existing engine. The daemon is responsible for process lifecycle, listener setup, request dispatch, and response emission, but the storage and lineage semantics remain in `transit-core`. The voyage proves that `transit` can be used across a client/server boundary without changing append, branch, merge, or replay meaning.

## Context & Boundaries

In scope: a single-node server runtime, a request dispatcher for the first remote operations, and minimal configuration needed to boot the server against the existing local and tiered engine paths.

Out of scope: replication, consensus, public ingress, policy-heavy auth, and any server-only storage path.

```
┌─────────────────────────────────────────────────────────┐
│                    Server Daemon                        │
│                                                         │
│  listener -> session -> dispatcher -> engine adapter    │
│                                   -> manifest/storage   │
└─────────────────────────────────────────────────────────┘
         ↑                                ↑
   remote client                    transit-core engine
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `transit-core` | internal crate | Owns append, replay, branch, merge, manifest, and durability semantics | workspace |
| Server runtime | implementation choice | Runs listener, sessions, and request dispatch | TBD during implementation |
| Serialization codec | implementation choice | Encodes request and response bodies for the first protocol | TBD during implementation |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Server packaging | Wrap the existing engine in a daemon | Preserves the one-engine thesis and keeps semantics shared |
| Remote command surface | Start with append, read, tail, branch, merge, and lineage inspect | These operations prove the product story before replication |
| Replication boundary | Keep replication and multi-node ownership out of the voyage | Prevents distributed assumptions from distorting the first server |

## Architecture

The daemon should layer cleanly:

- listener/runtime accepts connections and creates sessions
- session layer decodes requests and enforces request ordering per connection
- dispatcher maps protocol operations to engine calls
- engine adapter converts wire requests into existing local engine APIs and returns explicit durability and lineage results

## Components

- `server bootstrap`
  Loads configuration, opens the engine, and starts or stops the listener deterministically.
- `session handler`
  Owns one client connection, decodes requests, and serializes responses.
- `request dispatcher`
  Validates operation shape and routes append/read/tail/branch/merge/inspect calls to the engine.
- `engine adapter`
  Translates between protocol payloads and current engine-facing types without changing storage semantics.

## Interfaces

The voyage exposes a minimal remote command set:

- `append`
- `read`
- `tail`
- `branch`
- `merge`
- `inspect_lineage`

All interfaces must return explicit status and lineage-relevant positions rather than hiding server behavior behind generic success codes.

## Data Flow

1. Client connects to the daemon over the chosen transport.
2. Session handler decodes a request envelope and passes it to the dispatcher.
3. Dispatcher validates the operation and calls the engine adapter.
4. Engine adapter invokes `transit-core` APIs and captures durability and lineage results.
5. Session handler serializes a response back to the client.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Malformed request | Decode or validation failure | Return protocol error and keep or close session based on severity | Client resubmits a valid request |
| Unknown stream or invalid lineage reference | Engine validation failure | Return explicit application error | Client inspects lineage and retries with valid identifiers |
| Local durability failure | Engine/storage error | Return failure with no implied commit guarantee | Operator or client retries after remediation |
| Listener/session shutdown | Runtime signal or connection close | Stop accepting work or terminate the session cleanly | Client reconnects after server restart |
