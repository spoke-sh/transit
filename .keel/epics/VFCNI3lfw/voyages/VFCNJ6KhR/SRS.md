# Add Spoke Header Nav Link - SRS

## Summary

Epic: VFCNI3lfw
Goal: Add a right-side Spoke link immediately to the left of GitHub in the public docs header while preserving the existing docs build workflow.

## Scope

### In Scope

- [SCOPE-01] Navbar item configuration in `website/docusaurus.config.ts`.
- [SCOPE-02] Use of the upstream Spoke target URL and right-side placement pattern.

### Out of Scope

- [SCOPE-03] Broader header redesign, footer work, or route changes.
- [SCOPE-04] Changes to the Spoke site content or other external destinations.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Add a `Spoke` navbar item that targets the upstream Spoke site URL and sits immediately to the left of `GitHub` on the right side of the header. | SCOPE-01, SCOPE-02 | FR-01 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Keep the public docs build path passing through `just docs-build`. | SCOPE-01 | NFR-01 | just docs-build |
| SRS-NFR-02 | Keep Transit aligned with the upstream Spoke-family header pattern. | SCOPE-01, SCOPE-02 | NFR-02 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
