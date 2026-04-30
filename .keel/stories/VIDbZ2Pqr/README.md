---
# system-managed
id: VIDbZ2Pqr
status: done
created_at: 2026-04-29T15:00:00
updated_at: 2026-04-29T18:11:28
# authored
title: Implement Transit SQL CLI Surface
type: feat
operator-signal:
scope: VICkg6QuJ/VICkpQ4eS
index: 3
started_at: 2026-04-29T18:07:55
submitted_at: 2026-04-29T18:11:22
completed_at: 2026-04-29T18:11:28
---

# Implement Transit SQL CLI Surface

## Summary

This story adds a CLI command to execute SQL queries against a materialized state using Apache DataFusion and Prolly Trees.

## Acceptance Criteria

- [x] [SRS-03/AC-01] Implement `transit sql -c <query>` command in `transit-cli`. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, proof: ac-1.log-->
- [x] [SRS-03/AC-02] Command should initialize a DataFusion `SessionContext` with a Prolly Tree backend. <!-- [SRS-03/AC-02] verify: manual, SRS-03:continues, proof: ac-2.log-->
- [x] [SRS-03/AC-03] Command should output query results using DataFusion's pretty printers. <!-- [SRS-03/AC-03] verify: manual, SRS-03:end, proof: ac-3.log-->
