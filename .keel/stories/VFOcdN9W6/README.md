---
# system-managed
id: VFOcdN9W6
status: done
created_at: 2026-03-30T15:43:41
updated_at: 2026-03-30T17:13:54
# authored
title: Implement Automatic Lease Acquisition
type: feat
operator-signal:
scope: VFOPrFVvq/VFOPyDxnf
index: 3
started_at: 2026-03-30T16:39:41
completed_at: 2026-03-30T17:13:54
---

# Implement Automatic Lease Acquisition

## Summary

Allow followers to automatically attempt to acquire the primary lease once it is observed as expired.

## Acceptance Criteria

- [x] [SRS-02/AC-01] Eligible followers attempt to acquire the lease when the monitor signals expiration. <!-- verify: cargo nextest run -E 'test(test_election_monitor_triggers_on_expiration)', SRS-02:start, SRS-02:end, proof: ac-1.log-->
- [x] [SRS-02/AC-02] Verify that only one node succeeds in acquiring the lease via optimistic locking. <!-- verify: cargo nextest run -E 'test(object_store_consensus_manages_exclusive_leases)', SRS-02:continues, SRS-02:end, proof: ac-2.log-->
- [x] [SRS-03/AC-01] The engine verifies its lease ownership before every write to ensure fencing. <!-- verify: cargo nextest run -E 'test(engine_enforces_leadership_for_appends)', SRS-03:start, SRS-03:end, proof: ac-3.log-->
