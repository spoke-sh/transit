# Override Docs Hover Link Accent - Product Requirements

## Problem Statement

The public docs still show a blue hover underline/link hover accent in markdown content, which clashes with the intended Transit link treatment. Hover state should use a non-blue accent while preserving clear affordance.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Remove the remaining blue hover underline/accent from markdown docs links. | Manual review confirms hovered markdown links no longer read blue. | Hover-accent fix shipped |
| GOAL-02 | Preserve obvious hover affordance and the docs build workflow after the override. | Hover state still feels interactive and `just docs-build` passes. | Focused hover override shipped |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Docs Reader | Someone reading public docs content and hovering links in long-form pages. | A hover treatment that feels intentional and not off-palette. |
| Returning Evaluator | Someone comparing the recent docs polish passes. | Removal of the last unwanted blue accent without more theme churn. |

## Scope

### In Scope

- [SCOPE-01] Shared markdown hover link styling in `website/src/css/custom.css`.
- [SCOPE-02] Small related focus/hover refinements needed to preserve clear affordance.

### Out of Scope

- [SCOPE-03] Broader link color or homepage theme changes outside markdown hover treatment.
- [SCOPE-04] Reworking navbar or non-markdown link states.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Override markdown hover link styling so hovered docs links no longer present a blue accent. | GOAL-01 | must | This is the specific remaining issue. |
| FR-02 | Keep hovered links clearly interactive after the accent override. | GOAL-02 | must | The fix must preserve usability. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve the existing docs build path and route structure. | GOAL-02 | must | This is a narrow shared-CSS fix. |
| NFR-02 | Keep the hover treatment aligned with the Transit theme rather than introducing a stray accent. | GOAL-01, GOAL-02 | must | The goal is theme consistency. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Hover accent tone | Manual review | Story-level evidence logs |
| Workflow preservation | `just docs-build` | Story-level build evidence |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| A direct markdown hover override is enough to eliminate the remaining blue accent. | The unwanted blue may come from a broader Docusaurus selector. | Validate during implementation. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should hover move to a warm Transit accent or stay purely ink-toned? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Hovered markdown links no longer show the unwanted blue accent.
- [ ] Hover affordance remains clear.
- [ ] `just docs-build` still passes.
<!-- END SUCCESS_CRITERIA -->
