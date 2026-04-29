---
# system-managed
id: VICkilz8p
status: backlog
created_at: 2026-04-29T11:09:05
updated_at: 2026-04-29T11:18:49
# authored
title: Create Proof Path For Branch-Local SQL Materialization
type: feat
operator-signal:
scope: VICkg6QuJ/VICkpQ4eS
index: 2
---

# Create Proof Path For Branch-Local SQL Materialization

## Summary

This story provides the end-to-end proof for SQL materialization.

## Acceptance Criteria

- [ ] [SRS-02/AC-01] Create a proof path demonstrating a root stream materializing into a SQL view. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-1.log -->
- [ ] [SRS-02/AC-02] Demonstrate a child branch inheriting and diverging the SQL view. <!-- verify: manual, SRS-02:start, SRS-02:end, proof: ac-2.log -->
- [ ] [SRS-NFR-01/AC-01] Verify Prolly Tree node sharing between the two branches. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log -->
