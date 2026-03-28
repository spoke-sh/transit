# Refine Transit Hero Panel - Product Requirements

## Problem Statement

The Transit Network Shape lineage panel is too dark to read comfortably, and the four linked items below do not visually match the lineage box width in the homepage hero card.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Restore first-read legibility in the hero lineage panel. | The monospace lineage reads clearly against its background in the shipped hero card. | Achieve within the existing Transit docs shell. |
| GOAL-02 | Make the route links below the diagram feel structurally aligned with the lineage box. | The four linked items occupy the same usable width as the lineage panel within the hero frame. | No narrower step-row treatment remains. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| First-Time Reader | Someone landing on the Transit homepage to decide whether to keep reading. | A hero panel that is immediately readable and visually intentional. |
| Returning Reader | Someone scanning the homepage for the next documentation step. | Route links that are easy to scan and feel aligned with the diagram above them. |

## Scope

### In Scope

- [SCOPE-01] Hero panel styling changes needed to brighten the lineage diagram text and box treatment.
- [SCOPE-02] Layout changes needed to make the four route links below the diagram span the same usable width as the lineage box.
- [SCOPE-03] Docs proof-path verification for the hero-card update.

### Out of Scope

- [SCOPE-04] Broader homepage redesign work outside the hero card.
- [SCOPE-05] Documentation information architecture or route changes.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Increase the hero lineage panel contrast so the monospace network diagram is comfortably readable. | GOAL-01 | must | The current diagram under-serves the first-read purpose of the hero card. |
| FR-02 | Make the four linked route items below the diagram match the lineage box width treatment. | GOAL-02 | must | The hero card reads as mismatched when the links occupy a narrower track than the diagram above them. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Keep the docs verification path passing through `just docs-build`. | GOAL-01, GOAL-02 | must | Maintains the repo’s current public-docs proof path. |
| NFR-02 | Preserve the existing Transit hero structure and overall docs visual language. | GOAL-01, GOAL-02 | must | This is a refinement pass, not a redesign. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Problem outcome | Tests, CLI proofs, or manual review chosen during planning | Story-level verification artifacts linked during execution |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The unreadability comes from current color and panel styling rather than the diagram content itself. | A styling-only fix might under-correct the issue. | Validate the shipped contrast change against the rendered hero card. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| How bright can the diagram panel become before it stops fitting the Transit shell? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] The lineage diagram is visibly easier to read in the hero panel.
- [ ] The route-link list visually matches the diagram width treatment below it.
<!-- END SUCCESS_CRITERIA -->
