---
# system-managed
id: VFOQ1oxsg
status: done
created_at: 2026-03-30T15:35:31
updated_at: 2026-03-30T15:41:22
# authored
title: Implement ObjectStoreMembership Provider
type: feat
operator-signal:
scope: VFOPrFVvq/VFOPuiaUH
index: 2
started_at: 2026-03-30T15:37:12
completed_at: 2026-03-30T15:41:22
---

# Implement ObjectStoreMembership Provider

## Summary

Implement an initial `ObjectStoreMembership` provider that uses heartbeats in object storage for node discovery.

## Acceptance Criteria

- [x] [SRS-02/AC-01] Implement `ObjectStoreMembership` using the existing `ObjectStore` trait. <!-- verify: cargo test -p transit-core --lib membership::tests, SRS-02:start, SRS-02:end, proof: ac-1.log -->
- [x] [SRS-02/AC-02] Nodes can register and heartbeat their presence via files in a discovery directory. <!-- verify: cargo test -p transit-core --lib membership::tests, SRS-02:continues, SRS-02:end, proof: ac-2.log -->
- [x] [SRS-02/AC-03] Membership provider can list all active nodes based on valid heartbeats. <!-- verify: cargo test -p transit-core --lib membership::tests, SRS-02:continues, SRS-02:end, proof: ac-3.log -->
