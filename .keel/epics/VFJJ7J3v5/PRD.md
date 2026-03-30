# Sync Controlled Failover Foundational And User Docs - Product Requirements

## Problem Statement

The controlled failover slice landed in code and proof output, but the foundational docs and public MDX guides do not yet describe promotion readiness, explicit lease handoff, former-primary fencing, and the bounded non-claims around local, replicated, tiered, quorum, and multi-primary behavior with one consistent contract.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Give first-time users and operators one consistent explanation of the controlled failover slice across root docs and public guides. | Foundational docs and MDX guides all describe the same readiness, handoff, fencing, and non-claim contract. | All touched docs align with the shipped proof surface in one execution slice. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| First-Time User | Someone evaluating Transit through the public docs before reading the full repo planning history. | A clear explanation of what controlled failover is and what it is not. |
| Operator | Someone using `just screen` and CLI proofs to understand the replicated handoff boundary. | A trustworthy contract for readiness, handoff, fencing, and durability language. |

## Scope

### In Scope

- [SCOPE-01] Update foundational root docs where the durability, consistency, and server/deployment contract must reflect the shipped controlled failover slice.
- [SCOPE-02] Update public MDX concept and first-run guides so the user-facing docs expose the same bounded failover contract and proof commands.
- [SCOPE-03] Sync generated reference docs from the foundational documents after the root-doc changes land.

### Out of Scope

- [SCOPE-04] New engine, protocol, or failover behavior beyond the already shipped slice.
- [SCOPE-05] Quorum, election, or multi-primary design work.
- [SCOPE-06] Broad information-architecture redesign of the docs site.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Foundational docs must state the controlled failover slice in the same terms as the shipped proof surface: promotion readiness, explicit lease handoff, former-primary fencing, and bounded non-claims. | GOAL-01 | must | The root contracts are the canonical repo source of truth. |
| FR-02 | Public MDX pages must explain the same failover contract in first-time-user language and point readers to the relevant proof commands. | GOAL-01 | must | The public site is the user-facing onramp. |
| FR-03 | Generated reference docs must be resynced after root-doc edits so the public reference surface stays aligned. | GOAL-01 | must | Prevents drift between repo contracts and published reference docs. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | The updated docs must remain explicit about what `local`, `replicated`, and `tiered` do and do not mean. | GOAL-01 | must | Durability language is part of the product contract. |
| NFR-02 | The updated docs must not imply quorum acknowledgement, automatic election, or multi-primary behavior. | GOAL-01 | must | The bounded failover slice must stay below those guarantees. |
| NFR-03 | The docs changes must build cleanly through the supported Docusaurus workflow. | GOAL-01 | must | The public docs need a verified publishable artifact. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Foundational docs | Manual review plus synced reference output | Git diff plus synced reference docs |
| User-facing docs | `just docs-build` | Successful docs build output |
| Contract alignment | Manual review of proof-command references and bounded language | Story-level evidence logs |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The shipped controlled failover slice is already the intended public contract for this stage of Transit. | The docs could present unstable or incomplete semantics. | Keep the wording anchored to the existing proof output and foundational docs. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Overstating the failover slice beyond the shipped proof boundary. | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Foundational docs, public MDX guides, and synced reference docs all describe the same controlled failover contract and proof path.
<!-- END SUCCESS_CRITERIA -->
