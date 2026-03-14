---
id: VDqidQ9E2
title: Implement Prolly Tree Chunking And Construction
type: feat
status: done
created_at: 2026-03-14T06:47:17
updated_at: 2026-03-14T06:48:39
operator-signal: 
scope: VDoZWCfw3/VDoaYfn6o
index: 4
started_at: 2026-03-14T06:47:52
completed_at: 2026-03-14T06:48:39
---

# Implement Prolly Tree Chunking And Construction

## Summary

Implement content-defined chunking and the construction logic for Prolly Trees.

## Acceptance Criteria

- [x] [SRS-04/AC-01] Implement content-defined chunking using a rolling hash. <!-- [SRS-04/AC-01] verify: cargo test -p transit-materialize prolly::tests::prolly_tree_builder_forces_multi_layer_construction, SRS-04:start, SRS-04:end -->
- [x] [SRS-04/AC-02] Implement tree construction logic from leaf to root. <!-- [SRS-04/AC-02] verify: cargo test -p transit-materialize prolly::tests::prolly_tree_builder_constructs_root_from_entries, SRS-04:continues, SRS-04:end -->
