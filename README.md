# transit

[Architecture](ARCHITECTURE.md) | [Communication](COMMUNICATION.md) | [Integrity](INTEGRITY.md) | [AI Traces](AI_TRACES.md) | [AI Artifacts](AI_ARTIFACTS.md) | [Constitution](CONSTITUTION.md) | [Configuration](CONFIGURATION.md) | [Guide](GUIDE.md) | [Evaluations](EVALUATIONS.md) | [Release](RELEASE.md)

`transit` is a fresh take on message streaming: a Rust-first, object-storage-native append-only log with native tiered storage, stream lineage, and explicit branch-and-merge semantics.

The project thesis is simple:

- the same engine should run embedded in-process or as a networked server
- object storage should be a first-class persistence layer, not an archival afterthought
- branching and merging streams should be primitives, not application hacks
- append-only history should stay immutable while new branches diverge cheaply
- verifiable lineage should attach to segments, manifests, and checkpoints without bloating every append
- AI agents, model harnesses, and human communication systems should be first-class workloads

## Why Transit

Most streaming systems make a strong trade:

- they are excellent at ordered append and fan-out
- they are weak at representing divergence, experimentation, and conversational lineage
- they rarely treat merge and reconciliation as first-class dataflow operations
- they treat object storage as backup or offload instead of as part of the normal storage plan

`transit` aims at a different center:

- low-latency local append and tail for the hot path
- immutable segments persisted into object storage as part of the normal lifecycle
- stream branches and merges that reuse history without copying bytes
- one storage model that works for embedded runtimes, servers, agents, processors, and operator tools

## Core Model

- `record`: immutable bytes plus headers and timestamps
- `stream`: an ordered append-only sequence of records
- `branch`: a child stream created from a parent stream at a specific offset
- `merge`: an explicit reconciliation of two or more stream heads under a declared merge policy
- `lineage`: the DAG formed by branch and merge relationships
- `segment`: an immutable block of ordered records
- `manifest`: metadata that maps streams and branches to their segments across local and remote storage
- `checkpoint`: a proof-bearing envelope that binds a stream head or derived state to immutable history

In `transit`, a branch is not a filtered consumer view. It is its own stream head with explicit ancestry.

In `transit`, a merge should also be explicit. It should create new lineage state with declared parents and merge policy, not silently rewrite history behind the scenes.

## What It Should Enable

The initial target use cases are direct:

- AI model harnesses that need replayable traces, retries, forks, and evaluation provenance
- agent runtimes where one interaction can branch into parallel tool-use or planning paths
- a Slack-like communication system where channels are root streams and threads are native branches
- systems that need to merge branch results back into a mainline without losing provenance
- stream processing and incremental materialization over branching and merging event histories
- classifier-driven auto-threading, where a model can fork a new branch when a conversation diverges
- remote restore and audit flows that can verify immutable history instead of trusting remote storage implicitly

That auto-threading path is a core design motivator. A classifier should be able to observe a root stream, identify a new thread boundary, and create a child branch anchored to the triggering record without rewriting history.

## Branching, Merging, Materialization

The deeper thesis is not just "logs that can fork." It is "logs that can branch, merge, and feed deterministic derived state."

- Branches let a system diverge cheaply for retries, thread splits, alternate plans, or hypothetical work.
- Merges let those paths reconcile explicitly instead of forcing the application to pretend divergence never happened.
- Materialization lets processors build durable derived state, indexes, views, and caches from that lineage-rich history.

That suggests a product direction beyond a flat append-only log:

- the core engine should own append, branch, merge, lineage, and tiered storage
- materializers and processors may start as an adjacent first-party layer, but they should use the same manifests, checkpoints, and lineage model
- branch and merge semantics should make incremental recompute and branch-local derived state practical instead of expensive
- integrity should bind immutable segments and manifests, then grow into checkpoints and proofs without contaminating the hottest append path

## Design Goals

- Embedded-first core with a server mode layered on the same engine
- Native tiered storage with explicit local-head and remote-object responsibilities
- O(1)-style branch creation relative to ancestor history size
- explicit, inspectable merge operations with deterministic merge policies
- Immutable acknowledged history with no silent rewrites
- staged verifiable lineage from checksums to manifest roots to checkpoints
- incremental materialization over ordered, branching, and merging histories
- Clear durability modes so latency claims and safety claims are comparable
- Benchmarkable behavior for append, replay, cold restore, tailing, and branch-heavy workloads

## Non-Goals

`transit` is not trying to be a general mutable database, a hidden background compactor that rewrites acknowledged history, or a queue that destroys provenance once a consumer advances.

## Current State

This repository is at the bootstrap stage.

Today it contains:

- [README.md](README.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [CONSTITUTION.md](CONSTITUTION.md)
- [CONFIGURATION.md](CONFIGURATION.md)
- [GUIDE.md](GUIDE.md)
- [EVALUATIONS.md](EVALUATIONS.md)
- [RELEASE.md](RELEASE.md)
- [AGENTS.md](AGENTS.md)
- a Rust workspace with `transit-core` and `transit-cli`
- a Nix flake and Rust toolchain bootstrap
- a `Justfile` with a human-facing `just mission` verification path for local-engine proof, tiered publication/restore proof, and object-store probing
- a local durable engine that can append, replay, branch, merge, recover from trailing uncommitted active-head bytes, publish rolled immutable segments to object storage, and cold-restore published history from remote manifests
- an initial shared-engine server bootstrap that can open the same local engine, bind a daemon listener, shut down deterministically, and serve provisional remote append/read/tail/branch/merge/lineage-inspection operations through a framed request/response envelope with correlation IDs plus explicit acknowledgement and error semantics, without introducing a second storage path
- an initial `object_store` integration with a filesystem probe command

The implementation work now has a real scaffold to grow from instead of needing to reverse-engineer direction later.

The first canonical AI workload contract now lives in [AI_TRACES.md](AI_TRACES.md).

The first canonical communication workload contract now lives in [COMMUNICATION.md](COMMUNICATION.md).

The first verifiable-lineage contract now lives in [INTEGRITY.md](INTEGRITY.md).

## Planned Surfaces

The intended surface area is:

- an embedded library for in-process append, read, tail, and branch operations
- a server daemon exposing the same semantics over a network API, starting from the shared-engine bootstrap and provisional remote append/read/tail/branch/merge/lineage-inspection support with explicit request correlation and acknowledgement envelopes
- a client library and CLI for operators, application runtimes, and benchmarks

## First Principles

If a future design choice conflicts with one of these, the docs should be updated explicitly before code drifts:

1. The embedded and server products share one storage engine.
2. Tiered storage is a default architecture, not a premium add-on.
3. Stream lineage is a product primitive.
4. Durability, consistency, and benchmark scope must be explicit.
5. AI and communication workloads are reference workloads, not edge cases.
