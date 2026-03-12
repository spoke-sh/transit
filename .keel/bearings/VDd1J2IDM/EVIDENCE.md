---
id: VDd1J2IDM
---

# Research Multi-Node Replication And Server Semantics — Evidence

## Sources

| ID | Class | Provenance | Location | Observed / Published | Retrieved | Authority | Freshness | Notes |
|----|-------|------------|----------|----------------------|-----------|-----------|-----------|-------|
| SRC-01 | manual | manual:repo-read | README.md | 2026-03-11 | 2026-03-11 | high | high | The README says the same engine should run embedded and server mode, and it lists server mode as a planned surface while keeping the current repo at bootstrap stage. |
| SRC-02 | manual | manual:repo-read | ARCHITECTURE.md | 2026-03-11 | 2026-03-11 | high | high | The architecture document defines embedded and server as packaging choices on one engine, keeps one logical writer per stream head, and explicitly defers distributed consensus and cross-node replication. |
| SRC-03 | manual | manual:repo-read | CONSTITUTION.md | 2026-03-11 | 2026-03-11 | high | high | The constitution requires one engine across products and says durability and multi-writer semantics must be explicit rather than implied. |
| SRC-04 | manual | manual:repo-read | .keel/missions/VDcx0jbsJ/CHARTER.md | 2026-03-11 | 2026-03-11 | high | high | The active delivery mission is intentionally single-node only and excludes replication or consensus work from the current execution scope. |

## Technical Research

### Feasibility
Feasibility is good if this bearing is split into stages. The docs already justify server mode as a direct extension of the same engine, while also making it clear that distributed replication should wait until the single-node semantics are sharp [SRC-01] [SRC-02] [SRC-03] [SRC-04].

## Key Findings

1. Server mode is part of the product surface today, but replication is explicitly deferred, which means these should be treated as related but different follow-on efforts [SRC-01] [SRC-02] [SRC-04].
2. Any future multi-node design must preserve the same lineage, durability, and ordering semantics the constitution demands for the single-node engine [SRC-02] [SRC-03].
3. The best immediate conclusion is sequencing guidance: build a server on the shared engine first, then use that experience to bound replication research instead of doing distributed design in the abstract [SRC-01] [SRC-02].

## Unknowns

- Which wire protocol and client contract should be stabilized before discussing replication?
- Does object-store-backed history change the most sensible replication unit from records to segments or manifests?
