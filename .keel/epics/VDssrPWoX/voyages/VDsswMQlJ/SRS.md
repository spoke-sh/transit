# Implement Consensus Kernel - SRS

## Summary

Epic: VDssrPWoX
Goal: Deliver the core consensus traits and lease-based stream ownership mechanism.

## Scope

### In Scope

- [SCOPE-01] `ConsensusHandle` and `ConsensusProvider` traits.
- [SCOPE-02] `ObjectStoreLease` implementation.
- [SCOPE-03] Integration with `LocalEngine` to enforce leader status for appends.

### Out of Scope

- [SCOPE-04] Full Raft cluster implementation (deferred to later slice if needed).

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Define `ConsensusHandle` trait for stream head ownership. | SCOPE-01 | FR-01 | automated |
| SRS-02 | Implement lease-based ownership using Object Storage conditional writes. | SCOPE-02 | FR-02 | automated |
| SRS-03 | Enforce ownership check in `LocalEngine::append`. | SCOPE-03 | FR-03 | automated |
| SRS-04 | Implement lease heartbeating and fencing. | SCOPE-01 | FR-04 | automated |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Ensure consensus overhead is minimal for cached ownership. | SCOPE-03 | NFR-01 | automated |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
