# Re-skin Transit Public Docs - SRS

## Summary

Epic: VFC1jEl3d
Goal: Match the Keel docs visual system while swapping in a subway-network palette and differentiated Transit navigation chrome.

## Scope

### In Scope

- [SCOPE-01] Shared Docusaurus theme-shell updates needed to mirror the upstream Keel docs chrome in Transit.
- [SCOPE-02] Palette and accent updates that make the shell feel like Transit via subway-inspired colors and a differentiated top nav/header.
- [SCOPE-03] Homepage layout and style updates that preserve Transit’s copy and routes while matching the Keel aesthetic more closely.

### Out of Scope

- [SCOPE-04] Rewriting the documentation information architecture or adding major new MDX content.
- [SCOPE-05] Redesigning Transit’s logo or deploy pipeline.
- [SCOPE-06] Porting Keel-specific homepage components that are unnecessary for the shared shell and homepage feel.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Port the upstream Keel docs shell patterns required for Transit’s Docusaurus theme, including the navbar layout treatment and shared doc-surface chrome. | SCOPE-01 | FR-01 | build + manual |
| SRS-02 | Apply a subway-inspired Transit palette to the shared shell and give the top navigation/header a clearly distinct color treatment from the upstream Keel site. | SCOPE-01, SCOPE-02 | FR-02 | manual |
| SRS-03 | Restyle the Transit homepage to use the Keel visual language for hero, CTA, panel, and section presentation while preserving Transit copy and docs routes. | SCOPE-03 | FR-03 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Maintain strong readability and contrast across the refreshed docs shell, especially in navigation, buttons, and doc body surfaces. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-01 | manual |
| SRS-NFR-02 | Keep the public docs build working through the existing repo workflow without manual syncing outside committed files. | SCOPE-01, SCOPE-03 | NFR-02 | build |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
