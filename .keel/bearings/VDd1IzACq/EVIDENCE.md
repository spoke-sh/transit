---
id: VDd1IzACq
---

# Research High-Throughput CRDT And Collaborative State Overlays — Evidence

## Sources

| ID | Class | Provenance | Location | Observed / Published | Retrieved | Authority | Freshness | Notes |
|----|-------|------------|----------|----------------------|-----------|-----------|-----------|-------|
| SRC-01 | manual | manual:repo-read | README.md | 2026-03-11 | 2026-03-11 | high | high | The README treats merge as a first-class lineage primitive and positions materialization as an adjacent layer rather than as extra semantics in the append path. |
| SRC-02 | manual | manual:repo-read | ARCHITECTURE.md | 2026-03-11 | 2026-03-11 | high | high | The architecture document says materialized views must remain explicit artifacts and that processors should start adjacent to the core engine. |
| SRC-03 | manual | manual:repo-read | CONSTITUTION.md | 2026-03-11 | 2026-03-11 | high | high | The constitution emphasizes immutable acknowledged history, scope discipline, and explicit lineage rather than hidden mutable-state systems. |
| SRC-04 | manual | manual:repo-read | EVALUATIONS.md | 2026-03-11 | 2026-03-11 | high | high | The evaluation plan focuses on append, replay, branch correctness, and lineage-heavy workloads, which implies any CRDT strategy must preserve fast hot-path behavior. |

## Technical Research

### Feasibility
CRDT overlays are feasible, but the evidence points toward treating them as optional derived-state machinery rather than as part of the core storage semantics. The core engine is optimized for explicit lineage, not for making every record participate in collaborative-state convergence [SRC-01] [SRC-02] [SRC-03] [SRC-04].

## Key Findings

1. The repo’s design center is explicit branch and merge lineage, which already gives collaboration workloads a strong primitive without forcing CRDT metadata into every record [SRC-01] [SRC-03].
2. Because derived views are meant to be explicit artifacts in an adjacent layer, CRDTs fit more naturally as materialized overlays or workload-specific reducers than as base-engine semantics [SRC-02] [SRC-03].
3. Any CRDT adoption has to clear a high throughput bar, because the evaluation plan centers append, replay, branch correctness, and classifier-driven workloads rather than collaborative editing alone [SRC-04].

## Unknowns

- Which concrete workload actually needs CRDT semantics instead of explicit merge artifacts: shared documents, presence, counters, or something else?
- Can CRDT deltas be checkpointed and replayed cheaply on top of lineage-aware snapshots, or do they create unacceptable metadata growth?
