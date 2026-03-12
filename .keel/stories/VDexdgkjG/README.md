---
id: VDexdgkjG
title: Define Branch-Aware Snapshot And Merge Semantics
type: feat
status: done
created_at: 2026-03-12T06:31:37
updated_at: 2026-03-12T06:43:58
operator-signal: 
scope: VDd0u3PFg/VDexXBU7g
index: 2
started_at: 2026-03-12T06:42:24
submitted_at: 2026-03-12T06:43:50
completed_at: 2026-03-12T06:43:58
---

# Define Branch-Aware Snapshot And Merge Semantics

## Summary

Define the first branch-aware snapshot and merge model for materialized views so `transit` has a concrete design center for derived state instead of vague processing claims.

## Acceptance Criteria

- [x] [SRS-02/AC-01] The story defines the branch-aware snapshot model and names prolly trees as the leading structure, while also documenting supporting structures such as content-addressed snapshot manifests and segment-local summary filters. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-1.log -->
- [x] [SRS-03/AC-01] The story defines how source-stream merges relate to derived-state merge policy, including optional derived merge artifacts and view-specific reconciliation. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-2.log -->
- [x] [SRS-NFR-03/AC-01] The snapshot and merge model stays auditable and benchmarkable rather than depending on implicit mutable state. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log -->
