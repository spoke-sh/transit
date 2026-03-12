# transit

[Architecture](ARCHITECTURE.md) | [Constitution](CONSTITUTION.md) | [Configuration](CONFIGURATION.md) | [Guide](GUIDE.md) | [Evaluations](EVALUATIONS.md) | [Release](RELEASE.md)

`transit` is a fresh take on message streaming: a Rust-first, object-storage-native append-only log with native tiered storage and stream lineage.

The project thesis is simple:

- the same engine should run embedded in-process or as a networked server
- object storage should be a first-class persistence layer, not an archival afterthought
- forking a stream should be a primitive, not an application hack
- append-only history should stay immutable while new branches diverge cheaply
- AI agents, model harnesses, and human communication systems should be first-class workloads

## Why Transit

Most streaming systems make a strong trade:

- they are excellent at ordered append and fan-out
- they are weak at representing divergence, experimentation, and conversational lineage
- they treat object storage as backup or offload instead of as part of the normal storage plan

`transit` aims at a different center:

- low-latency local append and tail for the hot path
- immutable segments persisted into object storage as part of the normal lifecycle
- stream forks that reuse ancestor history without copying bytes
- one storage model that works for embedded runtimes, servers, agents, and operator tools

## Core Model

- `record`: immutable bytes plus headers and timestamps
- `stream`: an ordered append-only sequence of records
- `branch`: a child stream created from a parent stream at a specific offset
- `lineage`: the DAG formed by parent and child streams
- `segment`: an immutable block of ordered records
- `manifest`: metadata that maps streams and branches to their segments across local and remote storage

In `transit`, a branch is not a filtered consumer view. It is its own stream head with explicit ancestry.

## What It Should Enable

The initial target use cases are direct:

- AI model harnesses that need replayable traces, retries, forks, and evaluation provenance
- agent runtimes where one interaction can branch into parallel tool-use or planning paths
- a Slack-like communication system where channels are root streams and threads are native branches
- classifier-driven auto-threading, where a model can fork a new branch when a conversation diverges

That auto-threading path is a core design motivator. A classifier should be able to observe a root stream, identify a new thread boundary, and create a child branch anchored to the triggering record without rewriting history.

## Design Goals

- Embedded-first core with a server mode layered on the same engine
- Native tiered storage with explicit local-head and remote-object responsibilities
- O(1)-style branch creation relative to ancestor history size
- Immutable acknowledged history with no silent rewrites
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
- a `Justfile` with a human-facing `just mission` verification path
- an initial `object_store` integration with a filesystem probe command

The implementation work now has a real scaffold to grow from instead of needing to reverse-engineer direction later.

## Planned Surfaces

The intended surface area is:

- an embedded library for in-process append, read, tail, and branch operations
- a server daemon exposing the same semantics over a network API
- a client library and CLI for operators, application runtimes, and benchmarks

## First Principles

If a future design choice conflicts with one of these, the docs should be updated explicitly before code drifts:

1. The embedded and server products share one storage engine.
2. Tiered storage is a default architecture, not a premium add-on.
3. Stream lineage is a product primitive.
4. Durability, consistency, and benchmark scope must be explicit.
5. AI and communication workloads are reference workloads, not edge cases.
