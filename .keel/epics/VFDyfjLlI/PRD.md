# Deliver Replicated Primary Handoff - Product Requirements

## Problem Statement

Transit now has lease-backed stream ownership plus published replication frontier, read-only follower catch-up, and explicit replicated acknowledgements, but it still lacks a safe way to transfer writable ownership to a caught-up follower or express failover semantics without overclaiming quorum or multi-primary behavior.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Enable a caught-up follower to take over the writable primary role through an explicit, inspectable handoff path. | A bounded end-to-end handoff path exists and can be proven without manual state surgery. | One controlled promotion path is delivered. |
| GOAL-02 | Fence stale primaries and keep failover semantics explicit to operators and clients. | Proof surfaces show that the former primary cannot continue acknowledged writes after handoff. | Former-primary fencing is visible and testable. |
| GOAL-03 | Preserve the staged replication model below quorum acknowledgement and multi-primary behavior. | The delivered slice states what it does not guarantee and avoids consensus overclaims. | No quorum or multi-primary semantics are introduced. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Core Transit Maintainer | The engineer extending Transit's clustered behavior while preserving the shared-engine thesis. | A safe, architecture-aligned way to transfer writable ownership to a replica without inventing a second storage or consensus model. |
| Operator | The human running a small replicated Transit deployment. | A clear failover and handoff contract that states when a follower is promotable and what happens to the previous primary. |

## Scope

### In Scope

- [SCOPE-01] Define and deliver the first controlled failover mission boundary for a single writable primary and a caught-up follower.
- [SCOPE-02] Surface promotion readiness in terms of published frontier position and ownership state.
- [SCOPE-03] Implement explicit lease-backed writable-role transfer and former-primary fencing.
- [SCOPE-04] Extend proof and inspection surfaces so operators can see what handoff guarantees and what it does not.

### Out of Scope

- [SCOPE-05] Quorum acknowledgement, majority elections, or multi-primary replication.
- [SCOPE-06] Cross-region failover, follower writes before promotion, or a second replicated storage format.
- [SCOPE-07] Generalized distributed scheduling, automatic orchestration, or cluster-management features beyond direct ownership transfer.
- [SCOPE-08] Broad operator UX beyond the first explicit handoff and fencing contract.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Define the promotion-readiness surface that identifies when a follower is caught up enough to receive writable ownership. | GOAL-01 | must | A transfer flow is unsafe unless promotion eligibility is explicit and inspectable. |
| FR-02 | Deliver an explicit lease-backed primary-transfer path that hands writable ownership to an eligible follower. | GOAL-01, GOAL-02 | must | Writable-role transfer is the core outcome of the epic. |
| FR-03 | Fence the former primary and expose proof surfaces that show the resulting failover posture without implying quorum or multi-primary behavior. | GOAL-02, GOAL-03 | must | Operators need visible stale-primary protection and bounded guarantees. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve the one-engine thesis, lineage semantics, immutable acknowledged history, and object-storage-native design throughout the handoff path. | GOAL-01, GOAL-02 | must | Replication work cannot create a separate semantic world for server nodes. |
| NFR-02 | Keep the first failover slice explicitly below quorum acknowledgement, majority election, and multi-primary behavior. | GOAL-02, GOAL-03 | must | The mission is a bounded handoff slice, not a hidden consensus expansion. |
| NFR-03 | Make guarantee language explicit about publication, hydration, transfer readiness, and the limits of failover automation. | GOAL-01, GOAL-02, GOAL-03 | must | Operators need precise contract language to trust the behavior. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Problem outcome | Tests, CLI proofs, or manual review chosen during planning | Story-level verification artifacts linked during execution |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The published frontier and read-only follower catch-up path from the previous voyage are sufficient foundations for a first controlled handoff slice. | The epic may need additional groundwork before transfer can be made safe. | Validate against the prior replication voyage and implementation evidence during execution. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| How automatic should the first failover path be versus requiring an explicit operator-triggered transfer? | Epic owner | Open |
| What is the minimum follower catch-up condition required before a handoff is safe to allow? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] A caught-up follower can be promoted through one explicit handoff path without introducing quorum acknowledgement or multi-primary behavior.
- [ ] The former primary is fenced from further acknowledged writes after transfer.
- [ ] Proof and inspection surfaces make the resulting failover guarantees and non-guarantees explicit.
<!-- END SUCCESS_CRITERIA -->
