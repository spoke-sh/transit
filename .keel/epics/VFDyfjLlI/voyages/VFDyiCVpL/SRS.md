# Enable Controlled Primary Transfer - SRS

## Summary

Epic: VFDyfjLlI
Goal: Promote a caught-up follower into the writable primary role through explicit lease transfer and frontier checks while fencing the former primary and keeping failover guarantees below quorum and multi-primary behavior.

## Scope

### In Scope

- [SCOPE-01] Surface promotion eligibility from published replication frontier state and current ownership posture.
- [SCOPE-02] Transfer writable ownership through an explicit lease-backed handoff to an eligible follower.
- [SCOPE-03] Fence and demote the former primary after handoff.
- [SCOPE-04] Extend proof and inspection surfaces so humans can verify readiness, handoff result, and bounded failover semantics.

### Out of Scope

- [SCOPE-05] Quorum acknowledgement, majority elections, or generalized distributed scheduling.
- [SCOPE-06] Multi-primary behavior or concurrent writable followers.
- [SCOPE-07] Server-only replicated logs, alternate storage engines, or record-by-record push replication.
- [SCOPE-08] Cross-region failover or unrelated operator UX redesign.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Surface promotion eligibility in terms of follower frontier position and current ownership posture so operators and runtime checks can determine whether a follower is promotable. | SCOPE-01 | FR-01 | manual |
| SRS-02 | Transfer writable ownership only through an explicit lease-backed handoff path and reject promotion targets that are not eligible. | SCOPE-02 | FR-02 | manual |
| SRS-03 | Fence the former primary after handoff so stale leaders cannot continue producing acknowledged writes. | SCOPE-03 | FR-03 | manual |
| SRS-04 | Extend proof and inspection surfaces so humans can verify readiness, handoff result, and the bounded failover contract without inferring quorum or multi-primary guarantees. | SCOPE-04 | FR-03 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The voyage must preserve the shared engine, lineage semantics, immutable acknowledged history, and object-storage-native design across promotion checks and handoff behavior. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-01 | manual |
| SRS-NFR-02 | The first controlled failover slice must remain explicitly below quorum acknowledgement, majority election, and multi-primary behavior. | SCOPE-02, SCOPE-03, SCOPE-04 | NFR-02 | manual |
| SRS-NFR-03 | Operator-facing guarantees must remain explicit about publication, follower hydration, ownership transfer readiness, and the limits of failover automation. | SCOPE-01, SCOPE-02, SCOPE-04 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
