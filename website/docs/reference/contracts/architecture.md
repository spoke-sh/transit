---
title: "Architecture"
sidebar_label: "Architecture"
description: "Reference architecture and system model."
---
# Architecture

This document defines the reference architecture for `transit`. It is intentionally product-facing as well as implementation-facing because the storage model is the product.

## Architecture Thesis

`transit` is one lineage-aware storage engine exposed in two modes:

- embedded: linked directly into an application or runtime
- server: exposed over the network as a shared service

Those are packaging choices, not two different databases.

The engine is built around immutable segments, explicit branch-and-merge lineage, a hot local write/read path, and object storage as the normal home for colder history.

## Architecture Invariants

These invariants are the shortest way to evaluate whether a design still belongs in Transit.

| Boundary | Required property | Why it matters |
|----------|-------------------|----------------|
| Delivery modes | Embedded and server mode call the same storage engine. | Transit cannot drift into two databases with different semantics. |
| Lineage | Branches and merges are durable storage operations, not UI conventions. | Replay, audit, and derived-state correctness depend on explicit ancestry. |
| Durability language | `local`, `replicated`, `quorum`, and `tiered` stay literal. | Operators need comparable latency and safety claims. |
| Storage layers | The local head is hot working state; the remote tier is explicit immutable history. | Restore, failover, and cache behavior must stay inspectable. |
| Derived state | Materialization and projections consume replay; they do not rewrite acknowledged history. | Transit stays append-only at its core. |

## System Model

### Record

A `record` is the unit of append. It contains:

- opaque payload bytes
- typed headers or metadata
- timestamp and writer metadata
- an offset assigned by the stream head

Records are immutable once acknowledged.

### Stream

A `stream` is an ordered append-only log. It has:

- a stable identifier
- one active head
- a segment manifest
- optional ancestry metadata

### Branch

A `branch` is a stream created from another stream at a chosen offset.

Branch creation should be a metadata operation:

- the child references ancestor history up to the fork offset
- the child gets its own head after the fork point
- new appends land only on the child after the fork

The parent never changes because the child exists.

Offset identity should stay explicit:

- a child branch logically inherits the parent prefix through the fork offset
- offset identity is therefore `(stream_id, offset)`, not a bare offset alone
- parent and child may share the same offset numbers for shared ancestry while remaining different streams

### Merge

A `merge` is an explicit reconciliation of two or more stream heads.

Merge should preserve the same append-only discipline as every other operation:

- the merge result is a new lineage state, not a rewrite of source history
- fast-forward merge is allowed when ancestry permits it
- non-fast-forward merge should record all parent heads, merge base if any, and the merge policy used
- merge metadata should record actor, reason, classifier or processor identity, and conflict notes when relevant

### Lineage

Lineage is the DAG of branch and merge relationships.

Each lineage node should preserve:

- parent stream ids
- fork or merge base metadata
- creation timestamp
- lineage metadata such as actor, reason, merge policy, or classifier evidence

### Segment

A `segment` is an immutable block of contiguous records plus indexes and checksums.

Segments are the unit of:

- local disk layout
- object storage upload
- cold replay
- cache hydration

### Manifest

A `manifest` maps a stream head and its lineage to concrete segment objects. It is the authoritative metadata surface for replay beyond the live head.

## Verifiable Lineage

Integrity should follow immutable storage artifacts instead of slowing every append.

The intended first contract has four layers:

- fast segment checksums for accidental corruption detection
- cryptographic segment digests for sealed immutable objects
- manifest roots that bind ordered segment descriptors and lineage metadata
- lineage checkpoints that bind a stream head or derived state to a verified manifest root

This keeps the hot path lean while still making remote restore and lineage inspection explicit.

## Runtime Modes

### Embedded Mode

Embedded mode is for low-latency application-local use:

- one process owns append and read operations directly
- local files and caches are controlled by the embedding application
- the engine can still tier segments into object storage

This mode matters for agent runtimes, local-first tools, and model harnesses that do not want a mandatory sidecar.

### Server Mode

Server mode exposes the same storage engine behind a network API:

- multiple clients can append, read, tail, and branch
- the server owns durability policy and object-store credentials
- operational concerns such as auth, quotas, and metrics live here

The server should not invent a second storage format or branch model.

The server bootstrap is a thin daemon that opens the shared engine and binds a listener. On top of that bootstrap the server layers provisional remote root creation, append, read, snapshot-tail, branch creation, merge creation, and lineage inspection operations, wrapped in a framed request/response envelope with correlation IDs plus explicit acknowledgement and error semantics. Tail streaming uses logical session IDs with `open/poll/cancel` operations and credit-based delivery so the semantics do not collapse into one socket or underlay assumption. The CLI client surface mirrors those remote workflows directly, while richer client surfaces remain downstream. The shared engine has a full failover stack: controlled handoff, automatic leader election via `ElectionMonitor`, quorum-based durability, and cluster membership. Multi-primary behavior remains explicitly out of scope.

The transport boundary is also explicit: `transit` defines an application protocol above the transport layer. TCP, QUIC, or other ordinary transports can carry that protocol, and secure meshes such as WireGuard remain optional deployment underlays rather than protocol replacements.

## Current Capability Baseline

The architecture contract is anchored to the slices that exist today.

| Slice | Current shape | Explicit boundary |
|-------|---------------|-------------------|
| Embedded engine | durable local append, replay, branch, merge, status inspection, and crash recovery | pre-`1.0` formats are still allowed to evolve |
| Server surface | single-node daemon, framed request/response protocol, logical tail sessions, and kcat-style operator commands | the server must not invent a separate storage model |
| Storage and recovery | tiered publication, cold restore, warm-cache recovery, and effective-config storage verification | `transit storage probe` verifies the effective local/filesystem guarantee only |
| Failover and distributed durability | controlled handoff, automatic lease election, quorum acknowledgement, and former-primary fencing | multi-primary and dynamic rebalancing remain out of scope |
| Integrity and materialization | checksums, digests, manifest roots, checkpoints, Prolly snapshots, and reference projections | compact partial proofs and attestation are later layers |

## Storage Architecture

`transit` is tiered by default.

### Local Head

The hot path lives on local disk:

- active writable segment
- local index files
- recent immutable segments
- recovery metadata needed after crash or restart

The local head is responsible for low-latency append and tail behavior.

### Remote Tier

Older immutable segments are persisted to object storage with manifests and checksums.

Object storage is not just backup:

- cold replay depends on it
- branch ancestry may reference remote-only segments
- restore and catch-up must work from remote state alone
- remote state should eventually be verifiable through manifest roots and segment digests

### Cache

Each node may keep a local cache of remote segments. Cache eviction must never change logical history.

For hosted server deployments, the configuration boundary should stay explicit:
object-store coordinates identify the authoritative tier for rolled segments
and manifests, while `data_dir` and `cache_dir` remain replaceable warm working
state around the same shared engine and lineage model.

## Write Path

The intended write path is:

1. validate append against the current stream or branch head
2. append the record to the active local segment
3. update the local index and durability metadata
4. acknowledge according to the configured durability mode
5. roll and publish immutable segments plus manifests into object storage

Integrity boundaries should line up with that path:

- append updates stream state and, at most, incremental checksum state
- segment roll finalizes checksums and cryptographic digests
- publish computes or updates the manifest root
- stronger checkpoint signing remains a later layer, not a default append precondition

The first release should make durability policy explicit instead of implicit.

Suggested durability modes:

- `memory`: acknowledged after in-memory acceptance, for tests only
- `local`: acknowledged after local durable write
- `replicated`: acknowledged after the published handoff frontier is durable enough for read-only replica catch-up and promotion readiness
- `quorum`: acknowledged after a majority of configured cluster peers have confirmed receipt
- `tiered`: acknowledged only after the relevant segment state is durable in the remote tier

## Read Path

The intended read path is:

1. serve from the live local head when possible
2. resolve segment ownership through stream and lineage manifests
3. hydrate missing segments from object storage when needed
4. return records in logical stream order

Restore-time verification belongs here:

- verify manifest-root integrity before trusting remote history
- verify segment digests before or during replay
- surface checkpoint proofs when inspecting lineage or resuming materialized state

Clients should not need to care whether bytes came from the local head, local cache, or remote tier.

## Branching, Merging, And Lineage Semantics

Branching and merging are first-class storage operations, not overlays.

Required semantics:

- creating a branch must not copy ancestor data eagerly
- replay of a child stream before the fork offset must exactly match the parent
- child appends must never appear on the parent
- offsets must remain monotonic within one stream identity
- lineage traversal must be explicit and inspectable
- merge must be explicit and inspectable, never implicit background reconciliation
- merge result must preserve references to all input heads
- merge policy must be declared, not hidden inside application code

Materializations and other derived views must remain explicit artifacts. They must not silently rewrite ancestor history.

## Consistency Model

The initial reference model should be simple:

- one logical writer per stream head
- append order defines stream order
- acknowledged records are immutable
- recovery must never expose unacknowledged bytes as committed history

The failover model preserves that invariant through three complementary components:

- **ClusterMembership:** Nodes discover each other and maintain heartbeats to calculate quorum size.
- **ElectionMonitor:** A background worker that polls for lease expiration and triggers automatic leader election via the `ConsensusProvider`.
- **ObjectStoreConsensus:** A provider that uses optimistic locking on the remote tier to ensure that only one node can acquire a writable lease at a time.

Failover is supported through two paths:

- **Controlled failover:** A caught-up read-only replica becomes the writable primary through explicit lease handoff. The former primary is fenced after handoff.
- **Automatic failover:** The `ElectionMonitor` detects primary failure (lease expiry) and triggers automatic acquisition by an eligible follower.

Both paths preserve the one-writer-per-stream-head invariant. Multi-primary behavior remains explicitly out of scope.

## Processing And Materialization

`transit` should be usable as a storage substrate for stream processing and materialization.

The detailed materialization model lives in [Materialization](./materialization.md).

The likely boundary is:

- the core engine owns ordered history, branch and merge lineage, manifests, and recovery
- processors and materializers may start as a first-party adjacent layer instead of inflating the hot append path immediately
- both layers should share checkpoints, lineage metadata, deterministic replay semantics, and the same embedded/server contract

Materialization should support:

- incremental recompute from persisted checkpoints
- branch-local derived state
- checkpoint envelopes that bind derived state to `stream_id`, offset, manifest generation, and lineage position
- durable, inspectable snapshots of derived state
- explicit merge of derived states when source streams reconcile
- view-specific merge policies instead of one universal reconciliation rule

Persistent structures such as **Prolly Trees** (Probabilistic B-Trees) are the current design center because they make branch-local reuse, diffing, and content-addressed snapshots much cheaper than rebuilding mutable indexes from scratch.

### Prolly Trees in Materialization

Prolly Trees use **Content-Defined Chunking** to split state into immutable, content-addressed nodes. This provides several critical properties for `transit`:

1.  **Structural Sharing:** If two branches share most of their history, their materialized Prolly Trees will share most of the same underlying nodes in object storage.
2.  **Partial Hydration:** Nodes are identified by their `ContentDigest`. A materializer can fetch only the specific nodes needed for a query or update, rather than downloading a monolithic snapshot.
3.  **Efficient Diffing:** Two snapshots can be compared by comparing their root digests and recursively traversing only the diverging nodes.

#### Prolly Tree Structure and Branching

```text
[Stream Root] ─────────────────► [Snapshot A (Root Digest: 0x123)]
      │                               │
      │                               ├─► [Node 1 (Shared)]
      │                               ├─► [Node 2 (Shared)]
      │                               └─► [Node 3 (A-Local)]
      │
[Branch Root (Fork @ 10)] ─────► [Snapshot B (Root Digest: 0x456)]
                                      │
                                      ├─► [Node 1 (Shared)]
                                      ├─► [Node 2 (Shared)]
                                      └─► [Node 4 (B-Local)]
```

In the diagram above, Snapshot A and B share Node 1 and Node 2 because the underlying data at those offsets is identical. Only Node 3 and Node 4 differ, representing the divergence after the fork point.

Snapshot manifests and segment-local summary filters should remain explicit supporting artifacts rather than hidden mutable indexes.

Integrity and materialization should meet at checkpoints:

- a materialized snapshot should be able to cite the lineage checkpoint it was derived from
- verified manifests and segment digests become the stable base for durable derived state
- more compact proof structures such as Merkle manifests or Merkle Mountain Ranges can layer later if partial proofs become important

CRDTs may be useful for selected collaborative views, but they should remain optional overlays inside materializers rather than changing base stream semantics.

## Current Surface Map

These named surfaces are the current architecture boundary the repo should keep coherent.

| Surface | Primary role | Must preserve |
|---------|--------------|---------------|
| `transit-core` | shared engine, lineage, manifests, recovery, consensus, and protocol types | one-engine semantics across embedded and server mode |
| `transit-server` | daemon packaging around the shared engine | no server-only storage model |
| `transit-client` | thin Rust hosted-client surface | literal remote acknowledgements, request IDs, and errors |
| `transit-cli` | operator proofs and human-facing commands | explicit durability labels and proof-backed workflows |
| `transit-materialize` | derived-state and snapshot layer | replay-anchored checkpoints instead of hidden mutable truth |

## Suggested Package Layout

The likely package split is:

- `transit-core`: record, segment, manifest, lineage, and storage traits
- `transit-engine`: append, read, tail, recovery, and branch logic
- `transit-storage`: local disk and object-store implementations
- `transit-server`: network-facing daemon
- `transit-client`: client bindings
- `transit-cli`: operator and benchmark tools
- `transit-materialize`: first-party processing and materialization layer

This is guidance, not a locked module tree.

## AI And Communication Pattern

`transit` should treat AI and communication systems as reference workloads.

The communication model lives in [Communication](./communication.md).

Examples:

- a conversation channel is a root stream
- a thread is a child branch anchored to a message offset
- an agent plan can fork into multiple branches for retries or alternative tool paths
- classifier metadata can be recorded on branch creation for auto-threading and auditability

For ordinary communication workflows, root visibility should usually use backlinks or summaries. Explicit merges should stay reserved for real reconciliation workflows such as resolution, synthesis, moderation, or archival convergence.

That means lineage metadata should be cheap to create and easy to query.

## Deferred Scope

These areas are important but should stay explicit future work until designed:

- multi-primary or multi-writer semantics
- dynamic cluster rebalancing and automatic data sharding
- compaction or projection layers above immutable history
- authn/authz and multi-tenant isolation
- query surfaces beyond ordered log replay and tailing
