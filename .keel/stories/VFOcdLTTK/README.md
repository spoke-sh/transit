---
# system-managed
id: VFOcdLTTK
status: backlog
created_at: 2026-03-30T15:43:41
updated_at: 2026-03-30T16:26:48
# authored
title: Implement Lease Expiration In Consensus
type: feat
operator-signal:
scope: VFOPrFVvq/VFOPyDxnf
index: 1
---

# Implement Lease Expiration In Consensus

## Summary

Ensure the `ObjectStoreLease` correctly reflects expiration state and can be checked by followers.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] Update `ObjectStoreLeaseHandle` to expose expiration status. <!-- verify: automated, SRS-01:start, SRS-01:end -->
- [ ] [SRS-01/AC-02] The `ConsensusHandle` can report the current owner even if the lease is expired. <!-- verify: automated, SRS-01:continues, SRS-01:end -->
