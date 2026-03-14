---
id: VDqidwBDM
title: Implement Reference Materializer For Count Projection
type: feat
status: done
created_at: 2026-03-14T06:47:19
updated_at: 2026-03-14T06:49:51
operator-signal: 
scope: VDoZWCfw3/VDoaYfn6o
index: 5
started_at: 2026-03-14T06:48:45
completed_at: 2026-03-14T06:49:51
---

# Implement Reference Materializer For Count Projection

## Summary

Implement a reference materializer that proves the full loop: replay, reduce, snapshot, and checkpoint.

## Acceptance Criteria

- [x] [SRS-05/AC-01] Implement a `CountMaterializer` using the materialization engine. <!-- [SRS-05/AC-01] verify: cargo test -p transit-materialize engine::tests::materializer_can_catch_up_and_checkpoint, SRS-05:start, SRS-05:end -->
- [x] [SRS-05/AC-02] Prove end-to-end materialization from a core engine stream. <!-- [SRS-05/AC-02] verify: cargo test -p transit-materialize engine::tests::materializer_can_catch_up_and_checkpoint, SRS-05:continues, SRS-05:end -->
