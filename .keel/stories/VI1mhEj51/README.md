---
# system-managed
id: VI1mhEj51
status: done
created_at: 2026-04-27T14:07:56
updated_at: 2026-04-27T14:37:39
# authored
title: Harden Prolly Snapshot Builder And Diff Primitives
type: feat
operator-signal:
scope: VI1mae3rd/VI1meNvzJ
index: 3
started_at: 2026-04-27T14:30:39
submitted_at: 2026-04-27T14:37:34
completed_at: 2026-04-27T14:37:39
---

# Harden Prolly Snapshot Builder And Diff Primitives

## Summary

Harden the Prolly snapshot implementation so branch-aware materializers can rely on deterministic roots, correct separator keys, lookup, diff, and explicit snapshot manifests.

## Acceptance Criteria

- [x] [SRS-05/AC-01] Prolly tree construction sorts or validates entry order, uses stable canonical encoding, and preserves correct separator keys across leaf and internal chunks. <!-- [SRS-05/AC-01] verify: cargo test -p transit-materialize prolly_tree_builder -- --nocapture, SRS-05:start, SRS-05:end, proof: ac-1.log-->
- [x] [SRS-05/AC-02] Prolly APIs expose lookup and diff behavior with tests for single-layer, multi-layer, and object-store-backed trees. <!-- [SRS-05/AC-02] verify: cargo test -p transit-materialize prolly_lookup -- --nocapture && cargo test -p transit-materialize object_store_backed_prolly_tree_supports_lookup_and_diff -- --nocapture, SRS-05:start, SRS-05:end, proof: ac-2.log-->
- [x] [SRS-NFR-03/AC-01] Snapshot manifest docs or proof output explain source lineage, root digest, parent snapshot references, and verification expectations. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log-->
