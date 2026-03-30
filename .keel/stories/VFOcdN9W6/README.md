---
# system-managed
id: VFOcdN9W6
status: backlog
created_at: 2026-03-30T15:43:41
updated_at: 2026-03-30T16:26:48
# authored
title: Implement Automatic Lease Acquisition
type: feat
operator-signal:
scope: VFOPrFVvq/VFOPyDxnf
index: 3
---

# Implement Automatic Lease Acquisition

## Summary

Allow followers to automatically attempt to acquire the primary lease once it is observed as expired.

## Acceptance Criteria

- [ ] [SRS-02/AC-01] Eligible followers attempt to acquire the lease when the monitor signals expiration. <!-- verify: automated, SRS-02:start, SRS-02:end -->
- [ ] [SRS-02/AC-02] Verify that only one node succeeds in acquiring the lease via optimistic locking. <!-- verify: automated, SRS-02:continues, SRS-02:end -->
- [ ] [SRS-03/AC-01] The engine verifies its lease ownership before every write to ensure fencing. <!-- verify: automated, SRS-03:start, SRS-03:end -->
