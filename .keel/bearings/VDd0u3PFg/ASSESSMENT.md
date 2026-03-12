---
id: VDd0u3PFg
---

# Research Branch-Aware Materialization And Processing — Assessment

## Scoring Factors

| Factor | Score | Rationale |
|--------|-------|-----------|
| Impact | 5 | Branch-aware materialization turns lineage from an interesting storage primitive into a useful application platform. |
| Confidence | 4 | The repo thesis already provides a clear architectural boundary and names promising data structures. |
| Effort | 4 | A real materialization substrate needs checkpoints, snapshot structures, replay discipline, and view ergonomics. |
| Risk | 3 | The main risk is pulling processing concerns into the hot path too early, not feasibility. |

*Scores range from 1-5:*
- 1 = Very Low
- 2 = Low
- 3 = Medium
- 4 = High
- 5 = Very High

## Analysis

### Findings

- The architectural direction is already coherent: materialization should be first-party and lineage-aware, but adjacent to the core engine rather than fused into append/recovery internals [SRC-01] [SRC-02].
- Prolly-tree-backed snapshots are the strongest current candidate for branch-local reuse and diffing, giving this bearing a concrete design center instead of a vague processing story [SRC-02].

### Opportunity Cost

Pursuing this immediately would compete with the current single-node kernel work, which is explicitly the prerequisite surface for shared manifests, lineage, and checkpoint contracts [SRC-03].

### Dependencies

- Stable stream, branch, merge, segment, and manifest types from the active single-node mission are required before the materialization contract can be trusted [SRC-02] [SRC-03].

### Alternatives Considered

- Keep processing fully external and replay raw streams into ad hoc mutable indexes, but that gives up branch-aware checkpoints and undercuts the product thesis around lineage-rich derived state [SRC-01] [SRC-02].

## Recommendation

[x] Proceed → convert to epic [SRC-01] [SRC-02]
[ ] Park → revisit later [SRC-01]
[ ] Decline → document learnings [SRC-01]
