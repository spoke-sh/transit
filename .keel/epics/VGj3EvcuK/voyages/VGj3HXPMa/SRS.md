# Define Hosted Consumer Endpoint Contract - SRS

## Summary

Epic: VGj3EvcuK
Goal: Make the authoritative hosted endpoint, auth, acknowledgement, and error contract explicit for downstream consumers such as Spoke so new semantics land only in Transit-owned contract surfaces.

## Scope

### In Scope

- [SCOPE-01] Define the authoritative hosted consumer endpoint grammar and
  auth posture for downstream repos.
- [SCOPE-02] Define acknowledgement, durability, and error semantics that
  downstream consumers must observe literally.

### Out of Scope

- [SCOPE-03] Spoke-side code changes that consume the resulting upstream
  contract.
- [SCOPE-04] Consumer-owned schema, projection, or policy semantics.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Define the canonical hosted consumer endpoint and auth posture so downstream repos know where hosted authority semantics live and how credentials are presented. | SCOPE-01 | FR-01 | story: VGj3nmhSJ |
| SRS-02 | Define the acknowledgement, durability, and error surface that hosted consumers must preserve literally as the canonical hosted contract. | SCOPE-02 | FR-01 | story: VGj3nnHSG |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The hosted consumer endpoint contract must remain generic and must not absorb Spoke-specific business semantics. | SCOPE-01, SCOPE-02 | NFR-01 | story: VGj3nmhSJ, VGj3nnHSG |
| SRS-NFR-02 | Contract vocabulary and replacement posture must be explicit enough that downstream repos do not redefine endpoint or acknowledgement behavior locally. | SCOPE-01, SCOPE-02 | NFR-02 | story: VGj3nmhSJ, VGj3nnHSG |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
