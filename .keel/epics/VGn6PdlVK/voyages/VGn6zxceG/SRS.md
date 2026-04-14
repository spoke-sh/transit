# Published Cutover Surface - SRS

## Summary

Epic: VGn6PdlVK
Goal: Publish the runtime and client surface downstream repos need for a hard cutover without private adapters.

## Scope

### In Scope

- [SCOPE-01] Publish the canonical hosted runtime contract downstream repos
  should target.
- [SCOPE-02] Keep `transit-client` and related docs aligned with the real
  hosted runtime.
- [SCOPE-03] Define the direct-cutover expectations for deleting downstream
  private adapters.

### Out of Scope

- [SCOPE-04] Downstream implementation work.
- [SCOPE-05] Consumer-specific protocol wrappers or business semantics.
- [SCOPE-06] Deployment-repo rollout details.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | The published runtime contract must describe the canonical endpoint grammar, runtime posture, and durability/non-claim boundary downstream repos should consume. | SCOPE-01 | FR-04 | review |
| SRS-02 | The upstream client surface must remain the documented Rust import path for hosted consumers. | SCOPE-02 | FR-04 | tests |
| SRS-03 | Direct-cutover guidance must make it explicit that downstream duplicate adapters should be removed rather than preserved as a compatibility lane. | SCOPE-03 | FR-04 | review |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Published guidance must stay generic and avoid naming one downstream product as Transit’s concern. | SCOPE-01, SCOPE-03 | NFR-03 | review |
| SRS-NFR-02 | Docs and client examples must match the actual shipped runtime posture after the object-store and proof work lands. | SCOPE-01, SCOPE-02 | NFR-01 | review |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
