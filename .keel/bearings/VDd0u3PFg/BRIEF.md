# Research Branch-Aware Materialization And Processing — Brief

## Hypothesis

`transit` already claims branch-aware materialization and durable derived state as part of its product direction, but the docs intentionally place that work adjacent to the core append path. This bearing exists to define the contract between the lineage engine and a future `transit-materialize` layer, with prolly trees currently the leading candidate for branch-local snapshots and diffs.

## Problem Space

- Define the minimal core API needed for deterministic replay, lineage inspection, and checkpoint exchange.
- Decide whether prolly trees should be the default snapshot structure or one implementation behind a materialization abstraction.

## Success Criteria

- [ ] Define the minimal replay, lineage, and checkpoint contract between the engine and a future materialization layer.
- [ ] Make an explicit recommendation on whether prolly trees are the default snapshot design center or just one interchangeable implementation.

## Scope

### In Scope

- Checkpoint and replay boundaries between the storage engine and derived-state processors.
- Snapshot structures for branch-local state reuse, diffing, and incremental recompute.
- The effect of stream merges on derived-state semantics.

### Out Of Scope

- Building a production materialization runtime during the current single-node kernel mission.
- Changing the core append path to run processors inline.
- Inventing a second storage model that ignores segments, manifests, or lineage.

## Research Questions

- How should merge events affect derived state: replay-only, view-specific reducers, or explicit derived-state merge artifacts?
- Which indexing or checkpoint metadata belongs in `transit-core` versus a future `transit-materialize` crate?

## Open Questions

- What is the smallest checkpoint contract that preserves reuse without leaking unstable storage internals?
- Should derived-state merge be standardized across views or remain view-specific above the source-stream merge model?
