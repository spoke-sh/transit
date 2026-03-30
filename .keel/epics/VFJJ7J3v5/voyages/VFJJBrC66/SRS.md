# Sync Controlled Failover Contracts And Guides - SRS

## Summary

Epic: VFJJ7J3v5
Goal: Align the foundational documents and public MDX docs with the shipped controlled failover proof so first-time users and operators see one consistent contract for promotion readiness, explicit lease handoff, former-primary fencing, and the bounded non-claims around durability, quorum, and multi-primary behavior.

## Scope

### In Scope

- [SCOPE-01] Update foundational documents that define durability, consistency, and deployment semantics to include the shipped controlled failover slice.
- [SCOPE-02] Update public MDX concept and first-run pages so first-time users can understand controlled failover and the proof commands that demonstrate it.
- [SCOPE-03] Sync generated reference docs after the foundational-doc changes land.

### Out of Scope

- [SCOPE-04] Any new failover engine behavior, protocol changes, or server mechanics.
- [SCOPE-05] Quorum acknowledgement, election, or multi-primary design expansion.
- [SCOPE-06] Large-scale docs IA or theme work unrelated to this contract sync.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Update the foundational documents so the canonical durability and consistency contract explicitly includes promotion readiness, explicit lease handoff, former-primary fencing, and the bounded non-claims for controlled failover. | SCOPE-01 | FR-01 | manual |
| SRS-02 | Update public MDX concept and first-run pages so first-time users can understand the controlled failover slice and find the relevant proof commands. | SCOPE-02 | FR-02 | manual |
| SRS-03 | Resync the generated reference docs after the foundational-doc edits so the public reference surface matches the root contracts. | SCOPE-03 | FR-03 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The updated docs must keep `local`, `replicated`, and `tiered` language explicit and non-overlapping. | SCOPE-01, SCOPE-02 | NFR-01 | manual |
| SRS-NFR-02 | The updated docs must not imply quorum acknowledgement, automatic election, or multi-primary behavior. | SCOPE-01, SCOPE-02 | NFR-02 | manual |
| SRS-NFR-03 | The docs site must build successfully after the MDX and synced reference changes. | SCOPE-02, SCOPE-03 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
