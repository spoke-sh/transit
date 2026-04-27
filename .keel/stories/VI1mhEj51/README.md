---
# system-managed
id: VI1mhEj51
status: backlog
created_at: 2026-04-27T14:07:56
updated_at: 2026-04-27T14:11:45
# authored
title: Harden Prolly Snapshot Builder And Diff Primitives
type: feat
operator-signal:
scope: VI1mae3rd/VI1meNvzJ
index: 3
---

# Harden Prolly Snapshot Builder And Diff Primitives

## Summary

Harden the Prolly snapshot implementation so branch-aware materializers can rely on deterministic roots, correct separator keys, lookup, diff, and explicit snapshot manifests.

## Acceptance Criteria

- [ ] [SRS-05/AC-01] Prolly tree construction sorts or validates entry order, uses stable canonical encoding, and preserves correct separator keys across leaf and internal chunks. <!-- [SRS-05/AC-01] verify: automated, SRS-05:start, SRS-05:end -->
- [ ] [SRS-05/AC-02] Prolly APIs expose lookup and diff behavior with tests for single-layer, multi-layer, and object-store-backed trees. <!-- [SRS-05/AC-02] verify: automated, SRS-05:start, SRS-05:end -->
- [ ] [SRS-NFR-03/AC-01] Snapshot manifest docs or proof output explain source lineage, root digest, parent snapshot references, and verification expectations. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end -->
