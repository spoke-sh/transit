# Stabilize Docs Navbar Shell - Product Requirements

## Problem Statement

The public docs header wraps after the Spoke link addition, so body content overlaps the bottom of the header and the header shell no longer reads as full-width.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Restore a stable docs header for readers arriving on the public site. | Header stays single-line and page content clears the navbar at supported desktop widths. | Achieve with the Transit docs shell and current nav set intact. |
| GOAL-02 | Preserve access to project navigation while fixing the shell. | `Spoke` and `GitHub` remain reachable and the mobile navbar appears before the desktop shell wraps. | No wrapped desktop state remains in the repaired layout. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| First-Time Reader | Someone landing on Transit docs to understand the product and choose a starting path. | A stable, readable site shell that does not obscure content. |
| Returning Operator | Someone revisiting docs or reference material from a laptop-width browser. | Reliable header navigation without layout breakage. |

## Scope

### In Scope

- [SCOPE-01] Navbar shell CSS and theme behavior needed to keep the header full-width and non-overlapping.
- [SCOPE-02] Responsive breakpoint or layout adjustments required to hand off to the mobile navbar before wrapping occurs.
- [SCOPE-03] Verification that `Spoke` remains present and positioned immediately to the left of `GitHub`.

### Out of Scope

- [SCOPE-04] Broader information architecture or nav label changes.
- [SCOPE-05] Visual redesign work beyond the regression fix.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Keep the public docs navbar on a single line and full width for supported desktop layouts. | GOAL-01 | must | Prevents content overlap and restores a stable first-run reading experience. |
| FR-02 | Preserve `Spoke` and `GitHub` navigation while shifting smaller layouts to the mobile navbar before wrap occurs. | GOAL-02 | must | Fixes the regression without backing out the new project link. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Keep the docs build path passing through `just docs-build`. | GOAL-01, GOAL-02 | must | Maintains the existing proof path for the public docs site. |
| NFR-02 | Preserve the existing Transit docs theme and upstream-inspired navbar structure. | GOAL-01, GOAL-02 | must | Keeps the fix aligned with the current documentation shell instead of introducing a second pattern. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Problem outcome | Tests, CLI proofs, or manual review chosen during planning | Story-level verification artifacts linked during execution |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The regression is caused by navbar layout pressure rather than incorrect content routing. | A CSS-only fix might miss a deeper theme integration issue. | Validate the repair against the current Docusaurus navbar shell and config. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Which viewport range most commonly triggers the wrap today? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] The public docs header no longer wraps into an overlapping multi-line state.
- [ ] `Spoke` remains available in the repaired navigation model.
<!-- END SUCCESS_CRITERIA -->
