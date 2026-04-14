---
title: "Constitution"
sidebar_label: "Constitution"
description: "Non-negotiable product principles for Transit."
custom_edit_url: "https://github.com/spoke-sh/transit/blob/main/CONSTITUTION.md"
---
# Constitution

This document defines the non-negotiable principles for `transit`. It is the default decision authority for architecture, implementation, review, and scope tradeoffs unless a more specific document is intentionally updated first.

## 1. One Engine, Two Products

`transit` is one storage engine exposed as an embedded library and as a server.

- Server mode must not become a separate database with different lineage semantics.
- Embedded mode must not become a toy path that lacks tiered storage or branch correctness.
- Shared behavior belongs in shared core components.

## 2. Object Storage Is Native

Tiered storage is not optional architecture.

- Object storage is part of the normal persistence model.
- Cold replay, recovery, and lineage traversal must work with remote-backed history.
- Designs that only work with large local disks are incomplete.

## 3. Lineage Is A Primitive

Branching and merging are first-class.

- A branch is a real stream with ancestry, not a client-side convention.
- A merge is a real lineage event with declared parents and merge policy, not a hidden side effect.
- Branch creation must preserve immutable ancestor history.
- Merge must preserve immutable source history.
- Lineage metadata must be queryable and auditable.

## 4. Acknowledged History Is Immutable

Once a record is acknowledged, it is part of durable history.

- No silent in-place mutation of acknowledged records.
- No background rewrite that changes logical history while pretending nothing happened.
- Derived views, projections, and merges must be explicit artifacts.

## 5. Durability And Consistency Must Be Explicit

Performance claims and safety claims are meaningless without scope.

- Every append guarantee must state its durability mode.
- Recovery behavior must clearly separate committed and uncommitted data.
- Multi-writer or replicated behavior must define ordering and conflict rules directly.

## 6. Hot Path Local, Cold Path Remote

The system must optimize for both low-latency local behavior and object-store-backed history.

- The hot write and tail path should stay close to local disk or memory.
- Cold replay must not require full rehydration of all history.
- Cache eviction must never change logical stream contents.

## 7. Rust-First Reference Implementation

The reference implementation should be Rust-first.

- Core engine, storage, and server behavior belong in Rust.
- Additional language bindings are allowed, but they should wrap the core instead of redefining it.
- Dependency choices should favor predictable performance and operational simplicity.

## 8. AI And Communication Are Reference Workloads

`transit` is not an abstract storage exercise.

- Agent runtimes, model harnesses, and communication systems are primary product targets.
- Features that help classifier-driven auto-threading, replayable tool traces, and branch-heavy workflows should be treated as core requirements.
- Designs that work for generic queue traffic but fail for lineage-heavy workloads are insufficient.

## 9. Benchmark Claims Require Evidence

Every meaningful systems claim must be backed by reproducible evidence.

- Append, read, tail, branch, and tiered replay behavior should be benchmarked with clear hardware and backend context.
- Correctness and durability tests are required alongside throughput numbers.
- Comparisons against Kafka, Iggy, or any other system must state workload assumptions and durability scope.

## 10. Scope Discipline Over Feature Creep

`transit` starts as a lineage-aware append-only log with native tiered storage.

- Mutable database features are out of scope unless they preserve the append-only core.
- Compaction, search, and indexing layers should be built as explicit secondary systems when needed.
- Every scope expansion must explain how it keeps the core model simpler rather than blurrier.

