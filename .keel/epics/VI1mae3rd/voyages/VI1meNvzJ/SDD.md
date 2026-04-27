# Deliver Streaming Replay And Snapshot-Safe Materialization - Software Design Description

> Expose range replay, resume-ready checkpoint metadata, and Prolly snapshot correctness so downstream applications can build derived state without side stores or full-history scans.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage hardens the downstream read and derived-state boundary. The shared engine remains the source of ordered history and lineage. Materializers, hosted clients, and snapshot builders consume bounded replay windows and create explicit checkpoints or snapshots outside the append path.

## Context & Boundaries

The design touches `transit-core`, `transit-client`, `transit-materialize`, `transit-cli`, and docs. It does not introduce a server-only storage model or a materializer scheduler.

```text
LocalEngine range replay
  -> hosted protocol/client paged reads
  -> materializer checkpoint resume
  -> Prolly snapshot lookup/diff
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `transit-core::engine` | internal Rust API | Source of replay, tail, manifest, and checkpoint state | workspace |
| `transit-core::server` | internal protocol | Hosted request/response envelope | workspace |
| `transit-materialize::prolly` | internal Rust API | Snapshot construction and reuse | workspace |
| `object_store` | crate | Snapshot and segment persistence | workspace |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Bounded reads are shared-engine first | Add the primitive in `LocalEngine`, then map it through hosted protocol/client surfaces | Preserves one-engine semantics. |
| Checkpoints are explicit envelopes | Add source manifest and materializer metadata rather than hiding it in opaque state | Lets resume reject unsafe anchors. |
| Prolly correctness precedes optimization | Fix determinism, separators, lookup, and diff before advanced caching | Snapshot reuse is only valuable if the structure is trustworthy. |

## Architecture

Range replay should separate logical planning from record delivery. The implementation can start with existing segment readers but must expose a bounded public contract and avoid returning full-stream vectors to callers that ask for a page.

Materialization checkpoints should be a first-class type shared by local and hosted surfaces. If storage format changes are required, use the repository's hard-cutover policy and update tests and docs in the same slice.

Prolly snapshot APIs should canonicalize input ordering, use stable encoding for digests, preserve separator keys before chunk buffers are cleared, and provide lookup/diff operations that can work from content-addressed nodes.

## Components

| Component | Purpose | Behavior |
|-----------|---------|----------|
| Range replay API | Return bounded logical history | Accepts stream id, start offset, max records; returns records plus next-page metadata. |
| Hosted range request | Expose bounded reads over the server boundary | Preserves `RemoteAcknowledged<T>` and remote error envelopes. |
| Checkpoint envelope | Bind derived state to source lineage | Carries manifest generation/root, durability, lineage ref, state/snapshot refs, and materializer version. |
| Prolly snapshot layer | Reusable branch-aware derived-state structure | Supports deterministic build, lookup, diff, and snapshot manifest inspection. |

## Interfaces

Expected public surfaces include:

- `LocalEngine::replay_range(...)` or equivalent.
- `RemoteClient` and `TransitClient` paged read methods.
- A richer materialization checkpoint type shared across hosted and local materialization flows.
- Prolly tree lookup and diff methods plus snapshot manifest helpers.

## Data Flow

```text
append -> local/rolled segments -> range replay page
range replay page -> materializer reducer -> checkpoint envelope
checkpoint envelope -> resume validation -> next range replay page
materialized state entries -> Prolly snapshot -> snapshot manifest
```

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Range starts before retained history | Compare requested offset to retained frontier | Return invalid request with retained start offset context | Rebuild from available checkpoint or remote tier if present |
| Checkpoint manifest mismatch | Compare persisted envelope to current manifest/checkpoint identity | Reject resume | Rebuild or choose view-specific recovery |
| Prolly digest mismatch | Recompute node digest during load | Reject node | Re-fetch from authoritative store or rebuild snapshot |
