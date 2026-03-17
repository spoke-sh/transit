---
id: VDd1F1tUe
---

# Research Verifiable Lineage And Cryptographic Integrity — Evidence

## Sources

| ID | Class | Provenance | Location | Observed / Published | Retrieved | Authority | Freshness | Notes |
|----|-------|------------|----------|----------------------|-----------|-----------|-----------|-------|
| SRC-01 | manual | manual:repo-read | README.md | 2026-03-11 | 2026-03-11 | high | high | The README defines immutable segments, manifests, native tiered storage, and explicit branch/merge lineage as core product primitives. |
| SRC-02 | manual | manual:repo-read | ARCHITECTURE.md | 2026-03-11 | 2026-03-11 | high | high | The architecture document says segments are immutable blocks with checksums, manifests are authoritative metadata, and object storage is part of normal replay and restore. |
| SRC-03 | manual | manual:repo-read | CONSTITUTION.md | 2026-03-11 | 2026-03-11 | high | high | The constitution requires immutable acknowledged history, auditable lineage metadata, and explicit durability/consistency claims. |

## Technical Research

## Feasibility
Feasibility looks high because the storage design already has the right anchors for verification: immutable segment boundaries, manifest metadata, explicit lineage events, and remote-backed history [SRC-01] [SRC-02] [SRC-03].

## Key Findings

1. `transit` already has the structural units needed for cryptographic verification: immutable segments, checksummed manifests, and explicit lineage metadata [SRC-01] [SRC-02].
2. Integrity work aligns with the constitution because auditable lineage and explicit durability claims are already non-negotiable principles rather than optional hardening [SRC-03].
3. The main design question is sequencing, not desirability: verification must reinforce the storage model without forcing heavyweight cryptographic work into every append acknowledgement [SRC-02] [SRC-03].

## Unknowns

- What should be considered part of the minimum viable proof surface for remote restore: segment hashes, manifest roots, checkpoint signatures, or all three?
- How should trust and key management work if signed manifests or checkpoints are introduced later?
