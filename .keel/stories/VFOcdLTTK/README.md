---
# system-managed
id: VFOcdLTTK
status: done
created_at: 2026-03-30T15:43:41
updated_at: 2026-03-30T16:34:07
# authored
title: Implement Lease Expiration In Consensus
type: feat
operator-signal:
scope: VFOPrFVvq/VFOPyDxnf
index: 1
started_at: 2026-03-30T15:44:12
completed_at: 2026-03-30T16:34:07
---

# Implement Lease Expiration In Consensus

## Summary

Ensure the `ObjectStoreLease` correctly reflects expiration state and can be checked by followers.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Update `ObjectStoreLeaseHandle` to expose expiration status. <!-- verify: cargo test -p transit-core --lib consensus::tests, SRS-01:start, SRS-01:end, proof: ac-1.log -->
- [x] [SRS-01/AC-02] The `ConsensusHandle` can report the current owner even if the lease is expired. <!-- verify: cargo test -p transit-core --lib consensus::tests, SRS-01:continues, SRS-01:end, proof: ac-2.log -->
