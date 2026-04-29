---
# system-managed
id: VIDbZ2Pqr
status: backlog
created_at: 2026-04-29T15:00:00
updated_at: 2026-04-29T15:20:00
# authored
title: Implement Transit SQL CLI Surface
type: feat
operator-signal:
scope: VICkg6QuJ/VICkpQ4eS
index: 3
---

# Implement Transit SQL CLI Surface

## Summary

This story adds a CLI command to execute SQL queries against a materialized state using Apache DataFusion and Prolly Trees.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] Implement `transit sql -c <query>` command in `transit-cli`. <!-- [SRS-03/AC-01] verify: manual -->
- [ ] [SRS-03/AC-02] Command should initialize a DataFusion `SessionContext` with a Prolly Tree backend. <!-- [SRS-03/AC-02] verify: manual -->
- [ ] [SRS-03/AC-03] Command should output query results using DataFusion's pretty printers. <!-- [SRS-03/AC-03] verify: manual -->
