---
# system-managed
id: VICkihAAE
status: backlog
created_at: 2026-04-29T11:09:03
updated_at: 2026-04-29T15:20:00
# authored
title: Define ProllyTable And Implement DataFusion TableProvider Trait
type: feat
operator-signal:
scope: VICkg4FuI/VICkpNoeV
index: 1
---

# Define ProllyTable And Implement DataFusion TableProvider Trait

## Summary

This story involves defining the core storage bridge for Apache DataFusion.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] Implement mapping from Prolly Tree entries to Arrow `RecordBatch`es. <!-- [SRS-01/AC-01] verify: manual -->
- [ ] [SRS-02/AC-01] Define `ProllyTable` struct wrapping a Prolly Tree root. <!-- [SRS-02/AC-01] verify: manual -->
- [ ] [SRS-02/AC-02] Implement `TableProvider` for `ProllyTable`, including `schema()` and `scan()`. <!-- [SRS-02/AC-02] verify: manual -->
