---
# system-managed
id: VICkilz8p
status: done
created_at: 2026-04-29T11:09:05
updated_at: 2026-04-29T18:07:07
# authored
title: Create Proof Path For Branch-Local SQL Materialization
type: feat
operator-signal:
scope: VICkg6QuJ/VICkpQ4eS
index: 2
started_at: 2026-04-29T18:04:02
submitted_at: 2026-04-29T18:07:04
completed_at: 2026-04-29T18:07:07
---

# Create Proof Path For Branch-Local SQL Materialization

## Summary

This story provides the end-to-end proof for SQL materialization.

## Acceptance Criteria

- [x] [SRS-02/AC-01] Create a proof path demonstrating a root stream materializing into a SQL view. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, proof: ac-1.log -->
- [x] [SRS-02/AC-02] Demonstrate a child branch inheriting and diverging the SQL view. <!-- [SRS-02/AC-02] verify: manual, SRS-02:end, proof: ac-2.log -->
- [x] [SRS-NFR-01/AC-01] Verify Prolly Tree node sharing between the two branches. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log -->
