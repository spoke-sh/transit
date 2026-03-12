---
id: VDd1F1tUe
---

# Research Verifiable Lineage And Cryptographic Integrity — Assessment

## Scoring Factors

| Factor | Score | Rationale |
|--------|-------|-----------|
| Impact | 4 | Verifiable lineage would make `transit` materially stronger for audit, remote restore, and AI trace provenance. |
| Confidence | 4 | The existing storage model already exposes natural verification boundaries. |
| Effort | 3 | Segment hashes and manifest roots are tractable; signing and attestation can layer later. |
| Risk | 2 | The main risk is bad sequencing, not conceptual mismatch. |

*Scores range from 1-5:*
- 1 = Very Low
- 2 = Low
- 3 = Medium
- 4 = High
- 5 = Very High

## Analysis

### Findings

- Integrity work is structurally aligned with `transit` because the engine already centers immutable segments, manifests, and explicit lineage rather than mutable records or hidden rewrites [SRC-01] [SRC-02] [SRC-03].
- The best path is staged hardening: start with content integrity for segments and manifests, then decide later whether signed checkpoints or attestations belong in the product surface [SRC-02] [SRC-03].

### Opportunity Cost

Hardening verification too early would compete with delivery of the kernel itself, and integrity layers are only as good as the manifest and segment model they sit on top of [SRC-02].

### Dependencies

- Stable segment layout, manifest structure, and object-store publication flow are prerequisites for meaningful cryptographic hardening [SRC-02].

### Alternatives Considered

- Rely only on storage-provider checksums and local filesystem integrity, but that would leave lineage proofs and remote restore trust implicit rather than explicit [SRC-01] [SRC-03].

## Recommendation

[x] Proceed → convert to epic [SRC-01] [SRC-02]
[ ] Park → revisit later [SRC-01]
[ ] Decline → document learnings [SRC-01]
