---
# system-managed
id: VICkiiHB4
status: backlog
created_at: 2026-04-29T11:09:04
updated_at: 2026-04-29T15:20:00
# authored
title: Implement CatalogProvider For Multi-Table Prolly Discovery
type: feat
operator-signal:
scope: VICkg4FuI/VICkpNoeV
index: 2
---

# Implement CatalogProvider For Multi-Table Prolly Discovery

## Summary

This story adds multi-table support by implementing DataFusion's `CatalogProvider` and `SchemaProvider`.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] Implement `ProllySchema` as a `SchemaProvider` that manages a collection of `ProllyTable`s. <!-- [SRS-03/AC-01] verify: manual -->
- [ ] [SRS-03/AC-02] Implement `ProllyCatalog` as a `CatalogProvider`. <!-- [SRS-03/AC-02] verify: manual -->
- [ ] [SRS-03/AC-03] Verify that DataFusion can resolve table names to Prolly Trees via the catalog. <!-- [SRS-03/AC-03] verify: manual -->
