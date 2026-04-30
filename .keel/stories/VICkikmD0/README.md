---
# system-managed
id: VICkikmD0
status: done
created_at: 2026-04-29T11:09:05
updated_at: 2026-04-29T18:01:35
# authored
title: Implement SqlMaterializer Using DataFusion And Prolly Trees
type: feat
operator-signal:
scope: VICkg6QuJ/VICkpQ4eS
index: 1
started_at: 2026-04-29T17:57:11
submitted_at: 2026-04-29T18:01:33
completed_at: 2026-04-29T18:01:35
---

# Implement SqlMaterializer Using DataFusion And Prolly Trees

## Summary

This story involves building the materializer that uses DataFusion to apply stream updates to Prolly Trees.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Implement `SqlMaterializer` struct implementing `transit_materialize::Reducer`. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, proof: ac-1.log-->
- [x] [SRS-01/AC-02] Materializer should use a DataFusion `SessionContext` with the `ProllyCatalog` registered. <!-- [SRS-01/AC-02] verify: manual, SRS-01:continues, proof: ac-2.log-->
- [x] [SRS-01/AC-03] Implement basic INSERT materialization using `ProllyTreeBuilder`. <!-- [SRS-01/AC-03] verify: manual, SRS-01:end, proof: ac-3.log-->
