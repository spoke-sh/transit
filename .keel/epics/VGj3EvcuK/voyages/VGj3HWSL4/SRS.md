# Publish Upstream Consumer Client And Direct Cutover Proof - SRS

## Summary

Epic: VGj3EvcuK
Goal: Define the reusable upstream client surface and the proof path Spoke will follow to cut directly off its duplicate transit-server runtime and local hosted client semantics.

## Scope

### In Scope

- [SCOPE-01] Define the reusable upstream client surface that downstream repos
  such as Spoke should consume for hosted operations.
- [SCOPE-02] Define the direct-cutover proof path for Spoke's duplicate local
  runtime and hosted client surface.

### Out of Scope

- [SCOPE-03] Landing the Spoke-side implementation changes that remove the
  local runtime and client.
- [SCOPE-04] Consumer-owned schema or policy above the hosted client boundary.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Define the upstream client surface that downstream repos should import for hosted append, replay, branch, and related consumer operations. | SCOPE-01 | FR-02 | story: VGj3noOTn |
| SRS-02 | Define the Spoke direct-cutover proof path so downstream duplicate runtimes or hosted clients can be removed safely. | SCOPE-02 | FR-03 | story: VGj3no4T3 |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The upstream client boundary must preserve generic Transit semantics rather than codifying Spoke-specific behavior. | SCOPE-01, SCOPE-02 | NFR-01 | story: VGj3noOTn, VGj3no4T3 |
| SRS-NFR-02 | The cutover proof must be inspectable enough for downstream repos to cite during runtime/client replacement work. | SCOPE-02 | NFR-03 | story: VGj3no4T3 |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
