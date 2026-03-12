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

## Durability And Packaging Invariants

This contract must preserve the repo's current invariants:

- processors do not participate in default append acknowledgements
- checkpoint creation is off the hot write path
- the same semantics apply in embedded and server packaging
- restore from object storage does not create a second-class replay path
- derived state may cite lineage checkpoints, but stronger proof generation is still staged outside normal append latency

## What This Contract Deliberately Leaves To Later Slices

This document does not yet standardize:

- the default snapshot structure
- one universal derived-state merge policy
- CRDT-specific metadata or reducers
- a production runtime graph for processors

Those questions belong in the next materialization slices. The current contract only defines how materializers bind themselves to source history safely and explicitly.
