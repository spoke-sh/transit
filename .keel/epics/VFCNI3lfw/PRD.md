# Expose Spoke In Header Navigation - Product Requirements

## Problem Statement

The Transit public docs header currently links to GitHub but not the broader Spoke site. The header should include a Spoke link immediately to the left of GitHub to match the upstream navigation pattern.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Add the missing `Spoke` link to the public docs header in the requested position. | Manual review confirms the right-side header shows `Spoke` immediately to the left of `GitHub`. | Header nav updated |
| GOAL-02 | Preserve the existing docs workflow and route behavior after the header update. | `just docs-build` passes and existing docs routes remain unchanged. | Nav change shipped without workflow regression |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Docs Visitor | Someone using the public Transit docs site header for orientation and navigation. | A direct path from Transit docs to the broader Spoke site. |
| Returning Reader | Someone familiar with Keel’s docs header. | A consistent Spoke/GitHub header pattern across Spoke projects. |

## Scope

### In Scope

- [SCOPE-01] Public docs navbar item configuration in `website/docusaurus.config.ts`.
- [SCOPE-02] Small generated board updates required to track the change.

### Out of Scope

- [SCOPE-03] Broader navbar redesign, footer changes, or other docs IA adjustments.
- [SCOPE-04] Changes to the target Spoke site itself.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Add a `Spoke` link to the docs header using the upstream Spoke-site target and place it immediately to the left of `GitHub` on the right side of the navbar. | GOAL-01 | must | This is the direct requested behavior. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve the existing docs build path and route structure while applying the navbar change. | GOAL-02 | must | A navigation addition should not destabilize the site. |
| NFR-02 | Match the established upstream label/placement pattern so Transit stays aligned with the broader Spoke docs family. | GOAL-01 | should | Consistency across project sites reduces surprise. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Header nav placement | Manual review | Story-level evidence logs |
| Workflow preservation | `just docs-build` | Story-level build evidence |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The correct Spoke target for Transit should match upstream Keel’s `https://www.spoke.sh`. | The header could point at the wrong public site. | Validate against local upstream config before implementation. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| None beyond verifying the upstream URL/placement contract locally. | Epic owner | Closed |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] The public docs header includes `Spoke` immediately to the left of `GitHub`.
- [ ] The `Spoke` link targets the upstream Spoke site URL.
- [ ] `just docs-build` still passes.
<!-- END SUCCESS_CRITERIA -->
