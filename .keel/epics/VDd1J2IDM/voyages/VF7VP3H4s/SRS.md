# Deliver Remote-Tier Replication Handoff Foundations - SRS

## Summary

Epic: VDd1J2IDM
Goal: Implement the first clustered handoff path by reusing shared-engine publication and restore semantics, adding explicit follower catch-up and replicated acknowledgement boundaries without consensus or multi-primary behavior.

## Scope

### In Scope

- [SCOPE-01] Surface the published segment-plus-manifest frontier that acts as the first clustered replication handoff boundary.
- [SCOPE-02] Reuse shared-engine restore semantics to bootstrap and advance read-only followers from published remote-tier history.
- [SCOPE-03] Add an explicit `replicated` acknowledgement mode that waits for publication of the clustered handoff unit.
- [SCOPE-04] Upgrade proof and inspection surfaces so operators can distinguish local, replicated, and tiered commitments without inferring consensus or failover semantics.

### Out of Scope

- [SCOPE-05] Consensus, quorum writes, leader election, or lease-transfer workflows.
- [SCOPE-06] Multi-primary or follower-write semantics.
- [SCOPE-07] Record-by-record push replication, follower-only logs, or any server-only storage format.
- [SCOPE-08] Browser/public ingress, cross-language client work, or unrelated operator UX.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Surface the latest published segment and manifest frontier as the shared replication handoff boundary future clustered nodes inspect and consume. | SCOPE-01 | FR-02 | manual |
| SRS-02 | Allow followers to bootstrap and catch up from published remote-tier history using the shared restore path while remaining read-only. | SCOPE-02 | FR-01 | manual |
| SRS-03 | Add an explicit `replicated` acknowledgement mode that waits for publication of the relevant replication unit and states that boundary clearly to operators and clients. | SCOPE-03 | FR-03 | manual |
| SRS-04 | Extend proof and inspection surfaces so humans can verify published frontier, follower catch-up posture, and local versus replicated versus tiered commitment meaning end to end. | SCOPE-04 | FR-03 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The voyage must preserve one-engine, lineage, and object-storage-native semantics; clustered work cannot invent a second persistence or ancestry model. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-01 | manual |
| SRS-NFR-02 | The first execution slice must remain explicitly below consensus, failover, lease transfer, and multi-primary behavior. | SCOPE-02, SCOPE-03, SCOPE-04 | NFR-02 | manual |
| SRS-NFR-03 | Operator-facing guarantees must remain explicit about what `local`, `replicated`, and `tiered` mean and must not equate publication with follower hydration or ownership transfer. | SCOPE-03, SCOPE-04 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
