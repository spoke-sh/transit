# Neutralize Markdown Hover Underline - SRS

## Summary

Epic: VFCAdyu9b
Goal: Remove the blue hover underline treatment from markdown docs links while keeping hover affordance explicit and the docs build workflow intact.

## Scope

### In Scope

- [SCOPE-01] Shared markdown hover link styling in `website/src/css/custom.css`.
- [SCOPE-02] Small related hover/focus refinements needed to keep link affordance clear.

### Out of Scope

- [SCOPE-03] Broader non-markdown link styling or theme changes.
- [SCOPE-04] Reworking default resting-state docs link styling unless required by the hover override.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Override markdown hover link styling so hovered docs links no longer read blue. | SCOPE-01, SCOPE-02 | FR-01 | manual |
| SRS-02 | Keep hover/focus link affordance clear after removing the blue accent. | SCOPE-01, SCOPE-02 | FR-02 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Keep the docs build path passing through `just docs-build`. | SCOPE-01, SCOPE-02 | NFR-01 | just docs-build |
| SRS-NFR-02 | Keep the hover treatment visually aligned with the Transit theme. | SCOPE-01, SCOPE-02 | NFR-02 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
