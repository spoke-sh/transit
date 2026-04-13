# Object-Store Authority With Warm Cache - SRS

## Summary

Epic: VGh59soBt
Goal: Make server durability explicit with object storage as the long-term authority and warm local filesystem state as cache and working set rather than the only persistence path.

## Scope

### In Scope

- [SCOPE-01] transit-server configuration and startup rules for object-store-backed authority plus warm local cache.
- [SCOPE-02] Hydration and recovery behavior when the warm cache is missing, stale, or deliberately cleared.
- [SCOPE-03] Proof surfaces that show authoritative recovery and keep `local` versus `tiered` durability explicit.

### Out of Scope

- [SCOPE-04] Consumer-side workload wiring covered by voyage `VGh5B5qMT`.
- [SCOPE-05] Multi-node replication, quorum, or automatic failover changes outside the current hosted authority slice.
- [SCOPE-06] Mutable local-disk authority paths that bypass object-store publication once `tiered` durability is claimed.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Define the server configuration contract that binds object storage as the long-term authority tier and warm filesystem state as cache or working set. | SCOPE-01 | FR-02 | docs + test |
| SRS-02 | Ensure transit-server can hydrate authoritative history from the remote tier when warm local state is absent or discarded. | SCOPE-02 | FR-02 | test + proof |
| SRS-03 | Keep acknowledgement and proof surfaces explicit about whether a write is only `local` or safely `tiered`. | SCOPE-03 | FR-02 | test + proof |
| SRS-04 | Extend repo-native proof surfaces to demonstrate restart or cache-loss recovery from the authoritative remote tier. | SCOPE-03 | FR-04 | proof |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Server mode must preserve the same manifest and lineage semantics as the embedded engine while changing the durability authority boundary. | SCOPE-01 | NFR-01 | code review |
| SRS-NFR-02 | Loss of warm cache must not imply loss of acknowledged `tiered` history. | SCOPE-02 | NFR-02 | proof |
| SRS-NFR-03 | The warm cache design must not silently degrade a `tiered` proof into a filesystem-only guarantee. | SCOPE-03 | NFR-02 | proof |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
