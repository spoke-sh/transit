---
id: VDd0u3PFg
---

# Research Branch-Aware Materialization And Processing — Evidence

## Sources

| ID | Class | Provenance | Location | Observed / Published | Retrieved | Authority | Freshness | Notes |
|----|-------|------------|----------|----------------------|-----------|-----------|-----------|-------|
| SRC-01 | manual | manual:repo-read | README.md | 2026-03-11 | 2026-03-11 | high | high | The README makes branch, merge, and materialization a core thesis and says materializers may start as an adjacent first-party layer using the same manifests, checkpoints, and lineage model. |
| SRC-02 | manual | manual:repo-read | ARCHITECTURE.md | 2026-03-11 | 2026-03-11 | high | high | The architecture document says the core engine owns ordered history and lineage while processors/materializers should begin as an adjacent layer, and it explicitly calls out prolly trees as promising for branch-local reuse and content-addressed snapshots. |
| SRC-03 | manual | manual:repo-read | .keel/missions/VDcx0jbsJ/CHARTER.md | 2026-03-11 | 2026-03-11 | high | high | The active delivery mission constrains current implementation scope to the single-node kernel and says materialization must not invent a separate storage model. |

## Technical Research

## Feasibility
Feasibility looks strong as a follow-on initiative. The repo already treats materialization as a first-party-adjacent layer rather than a speculative add-on, and the existing architecture gives it the exact primitives it needs: deterministic replay, explicit lineage, manifests, and checkpoints [SRC-01] [SRC-02].

## Key Findings

1. The docs already imply the correct boundary: keep append, lineage, manifests, and recovery in the core, and put processors and derived-state logic in an adjacent layer that shares the same storage model [SRC-01] [SRC-02].
2. Prolly trees are explicitly named as a promising structure for snapshots, reuse, and diffs, which makes them the leading candidate for branch-aware materialized views rather than a speculative aside [SRC-02].
3. Materialization work should not start before the kernel types and storage scaffolding land, because the current delivery mission makes those the dependency surface for any adjacent layer [SRC-03].

## Unknowns

- What is the smallest checkpoint contract that lets a materializer resume without exposing unstable internal segment details?
- Should derived-state merge be standardized across views, or should `transit` only model source-stream merges and let views decide locally?
