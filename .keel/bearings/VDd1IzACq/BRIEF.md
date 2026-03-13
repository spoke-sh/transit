# Research High-Throughput CRDT And Collaborative State Overlays — Brief

## Hypothesis

`transit` targets communication and collaborative workflows, so CRDTs are an obvious question. The current architecture, however, is optimized for explicit append, branch, merge, lineage, and materialized artifacts rather than for carrying convergence metadata in every event.

## Problem Space

- Decide whether CRDT support belongs in the core engine, a materialization layer, or external application logic.
- Identify at least one high-value workload where CRDT overlays beat explicit merge artifacts enough to justify the complexity.

## Success Criteria

- [ ] Make an explicit recommendation on whether CRDT support belongs in core semantics, a materialization layer, or application-level overlays.
- [ ] Identify at least one concrete workload where CRDT overlays are materially better than explicit merge artifacts, or conclude that the bearing should stay parked.

## Scope

### In Scope

- CRDTs as optional overlays for documents, counters, presence, or other collaborative views.
- Throughput and metadata tradeoffs relative to explicit branch and merge semantics.
- Interactions between CRDT checkpoints and a future branch-aware materialization layer.

### Out Of Scope

- Adding CRDT semantics to the base append protocol today.
- Replacing explicit lineage with convergent mutable state as the default model.
- Solving every collaborative product problem before the core engine and materialization substrate exist.

## Research Questions

- Can op-based or delta CRDTs ride on append-only records without inflating the storage and latency costs of all workloads?
- How do CRDT convergence semantics interact with `transit`'s explicit branch and merge lineage without blurring provenance?

## Open Questions

- Which concrete workload actually needs CRDT semantics instead of explicit merge artifacts: shared documents, presence, counters, or something else?
- Can CRDT deltas be checkpointed and replayed cheaply on top of lineage-aware snapshots, or do they create unacceptable metadata growth?
