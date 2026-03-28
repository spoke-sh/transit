# Repair Docs Header Layout - SRS

## Summary

Epic: VFCvzGZeD
Goal: Keep the docs header single-line and full-width on desktop while handing off cleanly to the mobile navbar before layout overlap occurs.

## Scope

### In Scope

- [SCOPE-01] Adjust the custom navbar shell and supporting CSS so the header stays full-width and single-line on desktop.
- [SCOPE-02] Add the responsive handoff needed to avoid navbar wrapping before the mobile sidebar takes over.
- [SCOPE-03] Preserve the current `Spoke` and `GitHub` navigation arrangement.

### Out of Scope

- [SCOPE-04] Rewriting docs navigation labels or information architecture.
- [SCOPE-05] Broader homepage or footer styling work.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | The public docs navbar surface MUST remain full-width and single-line on supported desktop layouts so page content does not overlap the header. | SCOPE-01 | FR-01 | manual |
| SRS-02 | The docs shell MUST switch to the mobile navbar state before desktop nav items wrap or force a broken second row. | SCOPE-02 | FR-02 | manual |
| SRS-03 | The available navigation MUST continue to expose `Spoke` immediately to the left of `GitHub`. | SCOPE-03 | FR-02 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The repair MUST keep the docs verification path passing through `just docs-build`. | SCOPE-01 | NFR-01 | just docs-build |
| SRS-NFR-02 | The repair MUST preserve the existing Transit docs theme and custom navbar shell pattern. | SCOPE-01 | NFR-02 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
