---
id: VDqidwBDM
title: Implement Reference Materializer For Count Projection
type: feat
status: icebox
created_at: 2026-03-14T06:47:19
updated_at: 2026-03-14T06:47:19
operator-signal: 
scope: VDoZWCfw3/VDoaYfn6o
index: 5
---

# Implement Reference Materializer For Count Projection

## Summary

Implement a reference materializer that proves the full loop: replay, reduce, snapshot, and checkpoint.

## Acceptance Criteria

- [ ] [SRS-05/AC-01] Implement a `CountMaterializer` using the materialization engine. <!-- [SRS-05/AC-01] verify: cargo test -p transit-materialize, SRS-05:start, SRS-05:end -->
- [ ] [SRS-05/AC-02] Prove end-to-end materialization from a core engine stream. <!-- [SRS-05/AC-02] verify: cargo test -p transit-materialize, SRS-05:continues, SRS-05:end -->
