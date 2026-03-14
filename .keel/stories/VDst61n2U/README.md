---
id: VDst61n2U
title: Implement Object Store Lease Provider
type: feat
status: done
created_at: 2026-03-14T15:41:23
updated_at: 2026-03-14T15:44:41
operator-signal: 
scope: VDssrPWoX/VDsswMQlJ
index: 2
started_at: 2026-03-14T15:42:53
completed_at: 2026-03-14T15:44:41
---

# Implement Object Store Lease Provider

## Summary

Implement a `ObjectStoreConsensus` provider that uses object storage conditional writes to manage distributed leases.

## Acceptance Criteria

- [x] [SRS-02/AC-01] Implement `ObjectStoreConsensus` with lease acquisition and heartbeating. <!-- [SRS-02/AC-01] verify: cargo test -p transit-core consensus::tests::object_store_consensus_manages_exclusive_leases, SRS-02:start, SRS-02:end -->
- [x] [SRS-04/AC-01] Implement lease fencing to prevent concurrent manifest updates. <!-- [SRS-04/AC-01] verify: cargo test -p transit-core consensus::tests::object_store_consensus_manages_exclusive_leases, SRS-04:start, SRS-04:end -->
