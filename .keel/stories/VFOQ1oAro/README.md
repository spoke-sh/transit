---
# system-managed
id: VFOQ1oAro
status: done
created_at: 2026-03-30T15:35:31
updated_at: 2026-03-30T15:38:31
# authored
title: Define ClusterMembership Trait
type: feat
operator-signal:
scope: VFOPrFVvq/VFOPuiaUH
index: 1
started_at: 2026-03-30T15:37:12
submitted_at: 2026-03-30T15:38:29
completed_at: 2026-03-30T15:38:31
---

# Define ClusterMembership Trait

## Summary

Define the core `ClusterMembership` trait that allows the engine to query the set of active peers and calculate quorum size.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Define `ClusterMembership` and `NodeIdentity` traits/structs in `transit-core`. <!-- verify: cargo test -p transit-core --lib membership::tests, SRS-01:start, SRS-01:end, proof: ac-1.log-->
- [x] [SRS-01/AC-02] Implement `quorum_size()` helper on the membership trait. <!-- verify: cargo test -p transit-core --lib membership::tests, SRS-01:continues, SRS-01:end, proof: ac-2.log-->
- [x] [SRS-NFR-02/AC-01] Ensure the trait supports efficient, asynchronous node lookups. <!-- verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log-->
