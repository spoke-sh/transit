# Architecture

This document defines the reference architecture for `transit`. It is intentionally product-facing as well as implementation-facing because the storage model is the product.

## Architecture Thesis

`transit` is one lineage-aware storage engine exposed in two modes:

- embedded: linked directly into an application or runtime
- server: exposed over the network as a shared service

Those are packaging choices, not two different databases.

The engine is built around immutable segments, explicit branch-and-merge lineage, a hot local write/read path, and object storage as the normal home for colder history.

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

The first implementation step is a thin daemon bootstrap that opens the shared engine and binds a listener. The current server slice now layers provisional remote append, read, snapshot-tail, branch creation, merge creation, and lineage inspection operations on top of that bootstrap, wrapped in a framed request/response envelope with correlation IDs plus explicit acknowledgement and error semantics. Richer streaming sessions and broader client surfaces remain downstream. It remains explicitly single-node and should not imply replication, quorum, or leader semantics.

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

Any move toward replicated or multi-writer semantics must preserve those invariants and define conflict rules directly.

## Processing And Materialization

`transit` should be usable as a storage substrate for stream processing and materialization.

The canonical contract for this boundary now lives in [MATERIALIZATION.md](MATERIALIZATION.md).

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

Persistent structures such as prolly trees are the current design center because they make branch-local reuse, diffing, and content-addressed snapshots much cheaper than rebuilding mutable indexes from scratch. Snapshot manifests and segment-local summary filters should remain explicit supporting artifacts rather than hidden mutable indexes.

Integrity and materialization should meet at checkpoints:

- a materialized snapshot should be able to cite the lineage checkpoint it was derived from
- verified manifests and segment digests become the stable base for durable derived state
- more compact proof structures such as Merkle manifests or Merkle Mountain Ranges can layer later if partial proofs become important

CRDTs may be useful for selected collaborative views, but they should remain optional overlays inside materializers rather than changing base stream semantics.

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

The canonical communication contract now lives in [COMMUNICATION.md](COMMUNICATION.md).

Examples:

- a conversation channel is a root stream
- a thread is a child branch anchored to a message offset
- an agent plan can fork into multiple branches for retries or alternative tool paths
- classifier metadata can be recorded on branch creation for auto-threading and auditability

For ordinary communication workflows, root visibility should usually use backlinks or summaries. Explicit merges should stay reserved for real reconciliation workflows such as resolution, synthesis, moderation, or archival convergence.

That means lineage metadata should be cheap to create and easy to query.

## Deferred Scope

These areas are important but should stay explicit future work until designed:

- distributed consensus and cross-node replication
- compaction or projection layers above immutable history
- authn/authz and multi-tenant isolation
- query surfaces beyond ordered log replay and tailing
