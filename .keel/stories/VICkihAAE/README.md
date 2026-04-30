---
# system-managed
id: VICkihAAE
status: done
created_at: 2026-04-29T11:09:03
updated_at: 2026-04-29T17:50:21
# authored
title: Define ProllyTable And Implement DataFusion TableProvider Trait
type: feat
operator-signal:
scope: VICkg4FuI/VICkpNoeV
index: 1
started_at: 2026-04-29T17:45:50
submitted_at: 2026-04-29T17:50:18
completed_at: 2026-04-29T17:50:21
---

# Define ProllyTable And Implement DataFusion TableProvider Trait

## Summary

This story involves defining the core storage bridge for Apache DataFusion.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Implement mapping from Prolly Tree entries to Arrow `RecordBatch`es. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log-->
- [x] [SRS-02/AC-01] Define `ProllyTable` struct wrapping a Prolly Tree root. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, proof: ac-2.log-->
- [x] [SRS-02/AC-02] Implement `TableProvider` for `ProllyTable`, including `schema()` and `scan()`. <!-- [SRS-02/AC-02] verify: manual, SRS-02:end, proof: ac-3.log-->
