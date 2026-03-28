# Tune Public Docs Link Decoration - SRS

## Summary

Epic: VFC9XEYwI
Goal: Replace the light blue docs link underline with a less distracting treatment while preserving clear link affordance and the existing docs build workflow.

## Scope

### In Scope

- [SCOPE-01] Shared docs-body link-decoration styling in `website/src/css/custom.css`.
- [SCOPE-02] Small hover-decoration refinements needed to keep links visibly interactive.

### Out of Scope

- [SCOPE-03] Broader changes to the docs palette, homepage, navbar, or footer.
- [SCOPE-04] Reworking link text color across the site unless necessary to preserve readability.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Replace the bright light blue default underline with a subtler docs-link decoration treatment. | SCOPE-01 | FR-01 | manual |
| SRS-02 | Keep hover state affordance clear after the underline change. | SCOPE-01, SCOPE-02 | FR-02 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Keep the docs build path passing through `just docs-build`. | SCOPE-01, SCOPE-02 | NFR-01 | just docs-build |
| SRS-NFR-02 | Keep the decoration treatment visually consistent with the current Transit theme. | SCOPE-01, SCOPE-02 | NFR-02 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
