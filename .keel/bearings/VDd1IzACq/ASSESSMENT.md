---
id: VDd1IzACq
---

# Research High-Throughput CRDT And Collaborative State Overlays — Assessment

## Scoring Factors

| Factor | Score | Rationale |
|--------|-------|-----------|
| Impact | 3 | CRDT support could help selected collaborative workloads, but it is not yet central to the product thesis. |
| Confidence | 4 | The current docs strongly indicate CRDTs should stay out of the core path. |
| Effort | 4 | Getting CRDT semantics right without compromising throughput would require substantial additional design and benchmarking. |
| Risk | 4 | Pulling CRDT semantics into the engine too early would blur lineage, durability, and performance guarantees. |

*Scores range from 1-5:*
- 1 = Very Low
- 2 = Low
- 3 = Medium
- 4 = High
- 5 = Very High

## Analysis

### Findings

- The strongest current conclusion is negative scope guidance: CRDTs do not belong in the base engine today, because the product thesis is explicit append, branch, merge, and lineage rather than generalized convergent mutable state [SRC-01] [SRC-03].
- If CRDTs become useful at all, they fit best as optional overlays or materialized views built on top of the core log and its checkpoints [SRC-02].

### Opportunity Cost

Pursuing CRDT-heavy design now would steal attention from the single-node kernel and materialization substrate while adding complexity to performance-sensitive code paths that the evaluation plan says must stay fast [SRC-04].

### Dependencies

- A stable materialization layer and concrete collaborative workload are prerequisites before CRDT overlays can be judged on real merit instead of abstraction appeal [SRC-02] [SRC-04].

### Alternatives Considered

- Lean on explicit branch and merge artifacts plus workload-specific reducers, which keeps the core engine simpler and may already solve most collaboration cases the project currently targets [SRC-01] [SRC-03].

## Recommendation

[ ] Proceed → convert to epic [SRC-01]
[x] Park → revisit later [SRC-01] [SRC-02]
[ ] Decline → document learnings [SRC-01]
