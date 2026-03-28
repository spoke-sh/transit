# Adjust Docs Link Decoration Tone - Product Requirements

## Problem Statement

The current public docs link underline uses a light blue decoration that reads as distracting in the refreshed Transit theme. The underline should feel more intentional and less bright without weakening link affordance.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Replace the current light blue underline with a less distracting default link-decoration treatment. | Manual review confirms the underline no longer reads as bright light blue in docs content. | Underline tone fix shipped |
| GOAL-02 | Preserve link affordance and the existing docs workflow while refining the underline tone. | Links remain clearly readable and `just docs-build` passes after the CSS change. | Focused style fix shipped |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Docs Reader | Someone reading public MDX and foundational docs pages. | Links that feel intentional and readable without a visually noisy underline treatment. |
| Returning Evaluator | Someone revisiting the recently refreshed Transit docs. | Small polish improvements without broader theme churn. |

## Scope

### In Scope

- [SCOPE-01] Shared docs link-decoration styling in the public Docusaurus theme.
- [SCOPE-02] Small related hover-decoration refinements needed to keep link affordance clear.

### Out of Scope

- [SCOPE-03] Broader changes to the docs color palette, navbar, footer, or homepage layout.
- [SCOPE-04] Rewriting link text colors across the entire theme unless required to preserve readability.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Replace the default light blue underline with a subtler decoration treatment for docs-body links. | GOAL-01 | must | This is the direct user-facing issue. |
| FR-02 | Keep hover/active link affordance clear after the underline change. | GOAL-02 | must | The fix should not reduce usability. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve the existing docs build path and route structure while applying the change. | GOAL-02 | must | A styling refinement should not destabilize the site. |
| NFR-02 | Keep the decoration visually aligned with the Transit theme rather than introducing a new accent language. | GOAL-01, GOAL-02 | must | The fix should feel like polish, not a new design branch. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Underline tone | Manual review | Story-level evidence logs |
| Workflow preservation | `just docs-build` | Story-level build evidence |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| A small shared-CSS adjustment is enough to make the underline feel less distracting. | The issue may reflect a broader color-system concern. | Validate during implementation. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should hover state shift toward a warmer accent or simply darken the neutral underline? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Docs-body links no longer carry the bright light blue underline treatment.
- [ ] Link affordance remains clear after the underline refinement.
- [ ] `just docs-build` still passes.
<!-- END SUCCESS_CRITERIA -->
