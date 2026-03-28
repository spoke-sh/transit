# Tune Transit Network Shape Contrast - SRS

## Summary

Epic: VFC8awXmb
Goal: Increase the readability of the Transit Network Shape panel without changing the docs route structure or broader theme language.

## Scope

### In Scope

- [SCOPE-01] CSS changes for the Transit Network Shape diagram block itself.
- [SCOPE-02] Small related hero-panel styling changes needed to support the readability improvement.

### Out of Scope

- [SCOPE-03] Reworking the broader homepage layout or public docs information architecture.
- [SCOPE-04] Revisiting the recent docs shell palette outside the immediate hero panel context.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Increase foreground/background separation and glyph clarity in the Transit Network Shape diagram so the monospace content reads comfortably. | SCOPE-01, SCOPE-02 | FR-01 | manual |
| SRS-02 | Keep the adjusted panel visually consistent with the current Transit subway-theme hero. | SCOPE-02 | FR-02 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Keep the existing docs build path passing through `just docs-build`. | SCOPE-01, SCOPE-02 | NFR-01 | just docs-build |
| SRS-NFR-02 | Improve readability without making the hero panel feel visually detached from the rest of the page. | SCOPE-01, SCOPE-02 | NFR-02 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
