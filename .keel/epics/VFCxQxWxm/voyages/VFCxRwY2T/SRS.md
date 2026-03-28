# Tune Hero Diagram Card - SRS

## Summary

Epic: VFCxQxWxm
Goal: Raise the hero diagram contrast and align the four route links below it to the same usable width as the lineage panel without changing the broader docs shell.

## Scope

### In Scope

- [SCOPE-01] Adjust the hero lineage panel styling to improve text contrast and readability.
- [SCOPE-02] Adjust the hero route-link layout so the four items span the same usable width as the lineage box.
- [SCOPE-03] Keep the current hero content and route destinations intact.

### Out of Scope

- [SCOPE-04] Broader homepage or docs-shell redesign work.
- [SCOPE-05] Changes to docs routing, copy structure, or navigation destinations.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | The `Transit Network Shape` diagram panel MUST use a contrast treatment that makes the monospace lineage clearly readable in the homepage hero card. | SCOPE-01 | FR-01 | manual |
| SRS-02 | The four linked route items below the diagram MUST span the same usable width as the lineage box within the hero frame. | SCOPE-02 | FR-02 | manual |
| SRS-03 | The hero-card refinement MUST preserve the current route-link destinations and content structure. | SCOPE-03 | FR-02 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The refinement MUST keep the docs proof path passing through `just docs-build`. | SCOPE-03 | NFR-01 | just docs-build |
| SRS-NFR-02 | The refinement MUST preserve the existing Transit hero-card structure and overall docs visual language. | SCOPE-03 | NFR-02 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
