# Materialization Contract

`transit` needs one explicit contract for stream processing and durable derived state.

This document defines the minimum boundary between `transit-core` and a future
`transit-materialize` layer.

## Design Center

The design center is simple:

- `transit-core` owns ordered history, lineage, segments, manifests, publication, and restore
- materializers consume replayable history and emit checkpoints or snapshots
- materializers do not change acknowledged stream history
- the same contract must work for embedded and server packaging
- the same contract must work whether source history is local, restored from object storage, or mixed

## Boundary

`transit-core` is responsible for:

- append, replay, and tail semantics
- stream, branch, and merge lineage
- manifest generation and segment identity
- explicit durability boundaries such as `memory`, `local`, and `tiered`
- local recovery and cold restore

A future `transit-materialize` layer is responsible for:

- consuming replayable history
- applying view-specific reduction logic
- storing materializer-owned checkpoint state
- optionally emitting reusable snapshots
- choosing how a specific view reacts to source-stream merges

That split is non-negotiable. Materialization is adjacent to the engine, not fused into the append acknowledgement path.

## Minimum Engine Contract

A materializer should rely on a small, stable set of source facts:

- `stream_id`: the stream being processed
- `offset`: the highest source offset reflected in the checkpoint
- `manifest_generation`: the manifest generation observed while producing the checkpoint
- `durability`: the source durability level at the checkpoint boundary
- `lineage position`: the branch or merge identity that explains how the current stream head was reached
- `replay semantics`: deterministic ordered replay from a chosen offset

The engine does not need to expose mutable internal indexes or active file layout in order for a materializer to resume safely.

## Checkpoint Envelope

A materialization checkpoint should be an explicit envelope that binds derived state to immutable source history.

Minimum recommended fields:

- `materialization_id`: stable identifier for the view or processor
- `view_kind`: projection, index, cache, feature-set, summary, or other explicit type
- `source_stream_id`: stream the view was derived from
- `source_offset`: highest fully applied source offset
- `source_manifest_generation`: manifest generation observed at checkpoint time
- `source_durability`: durability boundary of the source read path
- `lineage_ref`: explicit source position such as `stream_id@offset`
- `lineage_checkpoint_ref`: optional reference to a stronger lineage checkpoint from [INTEGRITY.md](INTEGRITY.md)
- `opaque_state_ref`: materializer-owned durable state or blob reference
- `snapshot_ref`: optional reference to a reusable snapshot artifact
- `produced_at`: checkpoint timestamp
- `materializer_version`: reducer or processor version that produced the state

Example shape:

```json
{
  "materialization_id": "channel-unread-counts",
  "view_kind": "projection",
  "source_stream_id": "chat.general",
  "source_offset": 1842,
  "source_manifest_generation": 12,
  "source_durability": "tiered",
  "lineage_ref": "chat.general@1842",
  "opaque_state_ref": "materialize/channel-unread-counts/checkpoints/000012/state.json",
  "snapshot_ref": "materialize/channel-unread-counts/snapshots/000012",
  "produced_at": "2026-03-12T06:40:00Z",
  "materializer_version": "unread-counter.v1"
}
```

## Resume Semantics

A materializer should resume according to explicit lineage rules:

1. If the source stream head is the same checkpointed lineage position, resume is a no-op.
2. If the source stream head is a descendant on the same stream, resume by replaying from `source_offset + 1`.
3. If the source history was cold-restored but preserves the same stream identity, lineage, and manifest generation semantics, the checkpoint remains valid.
4. If a source-stream merge appears after the checkpoint, the materializer replays the merge as an explicit source event.
5. If lineage no longer matches the checkpointed source assumptions, the materializer must reject blind resume and either rebuild or apply a view-specific recovery policy.

Resume should never depend on hidden mutable state in the engine.

For embedded helper layers, the preferred implementation shape is an explicit
resume cursor derived from the checkpoint itself. That cursor should expose the
checkpoint anchor, the next replay offset, and the current replay boundary so
applications can inspect or resume derived state without inventing side caches
or shadow indexes.

## Durability And Packaging Invariants

This contract must preserve the repo's current invariants:

- processors do not participate in default append acknowledgements
- checkpoint creation is off the hot write path
- the same semantics apply in embedded and server packaging
- restore from object storage does not create a second-class replay path
- derived state may cite lineage checkpoints, but stronger proof generation is still staged outside normal append latency

## Branch-Aware Snapshot Model

Snapshots should be explicit, durable artifacts rather than hidden mutable indexes.

The default design center is:

- checkpoint envelope: binds a materializer to source lineage
- snapshot manifest: describes one reusable derived-state snapshot
- content-addressed snapshot data: stores the actual derived-state structure

### Default Snapshot Structure

Prolly trees are the leading default structure for materialized snapshots.

They fit `transit` well because they provide:

- efficient branch-local reuse when two views share most history
- cheap diffs between branch snapshots
- content-addressed nodes that work well with object storage
- deterministic rebuild and inspection semantics

A snapshot should therefore prefer:

- a prolly-tree root as the primary derived-state structure
- content-addressed nodes or shards beneath that root
- immutable snapshot manifests that bind the snapshot to source lineage

### Snapshot Manifest

A reusable snapshot should have a small manifest with fields such as:

- `materialization_id`
- `snapshot_id`
- `snapshot_kind`
- `source_stream_id`
- `source_lineage_ref`
- `source_manifest_generation`
- `source_checkpoint_ref`
- `parent_snapshot_refs`
- `snapshot_root_ref`
- `snapshot_stats_ref`
- `created_at`
- `materializer_version`

The manifest is the stable inspection surface. It should let operators answer:

- which source lineage this snapshot reflects
- whether it descends from another snapshot on the same branch
- which checkpoint or manifest generation it trusts
- where the actual snapshot data lives

### Supporting Structures

Prolly trees are the design center, but supporting structures are useful:

- content-addressed snapshot manifests for stable references and dedupe
- segment-local summary filters for pruning and negative lookups during replay or rebuild
- optional Merkle roots for stronger snapshot verification later

The role of segment-local summary filters is narrow and practical:

- avoid touching obviously irrelevant source segments during snapshot refresh
- speed branch-local recompute for selective projections
- remain advisory rather than semantic, so false positives cost work but not correctness

## Derived Merge Semantics

Source-stream merges are first-class lineage events. Materialized views must react to those explicit source events instead of hiding reconciliation in mutable state.

The default rule is:

- source merges are canonical
- derived-state merge policy is view-specific
- when a view makes a merge decision that matters operationally, it should emit an explicit derived merge artifact

### Recommended Merge Policy Categories

A materializer may choose one of these policy shapes:

- `replay-through`: replay the merged source history and let the reducer converge naturally
- `branch-reuse-plus-recompute`: reuse branch-local snapshots and recompute only the affected frontier
- `explicit-derived-merge`: produce a new derived-state artifact that records how parent snapshots were reconciled
- `full-rebuild`: discard branch-local reuse and rebuild from a known source checkpoint when correctness is simpler than reconciliation

No single policy should be forced across all views.

### Derived Merge Artifact

When a view needs explicit reconciliation, the merge result should be inspectable.

Recommended fields:

- `materialization_id`
- `merge_artifact_id`
- `source_merge_ref`
- `parent_snapshot_refs`
- `merge_base_snapshot_ref`
- `merge_policy`
- `merge_reason`
- `output_snapshot_ref`
- `conflict_notes_ref`
- `produced_at`
- `materializer_version`

This keeps reconciliation auditable without pretending every projection follows the same reducer.

## Auditability And Benchmarkability

The snapshot and merge model must remain measurable and inspectable.

That means:

- snapshots are explicit artifacts with stable ids and source lineage references
- derived merges are explicit artifacts when they are semantically meaningful
- summary filters and snapshot stats are advisory data, not hidden correctness dependencies
- replay, reuse, rebuild, and merge costs can be measured independently

Useful benchmark dimensions include:

- snapshot build time
- snapshot bytes written
- branch-local reuse ratio
- incremental recompute range
- merge rebuild rate
- summary filter false-positive rate

The contract should not rely on in-memory mutable indexes that disappear from operator view.

## CRDT Overlays

CRDTs are useful for some materialized views, but they should remain overlays rather than base stream semantics.

Good fits include:

- presence or liveness views
- collaborative cursors or lightweight shared state
- counters, sets, or document fragments that benefit from commutative merge behavior

The recommended stance is:

- keep source records and lineage semantics unchanged
- implement op-based or delta-style CRDT behavior inside specific materializers
- persist CRDT state through the same checkpoint and snapshot envelope
- emit explicit derived merge artifacts when CRDT reconciliation needs auditability

This preserves throughput in the base engine while still allowing high-concurrency collaborative views where they are actually useful.

## What This Contract Deliberately Leaves To Later Slices

This document does not yet standardize:

- a production runtime graph for processors
- concrete on-disk formats for snapshot manifests or prolly-tree node encoding
- one universal schema for every derived-state artifact
- which views should default to replay-through, explicit-derived-merge, or CRDT overlay behavior

Those questions belong in later implementation slices. The current contract now defines the snapshot and merge design center without freezing every runtime detail prematurely.
