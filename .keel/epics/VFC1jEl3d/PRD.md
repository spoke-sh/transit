# Adopt Keel Docs Theme With Subway Palette - Product Requirements

## Problem Statement

Transit's public docs already have strong content, but the visual shell diverges from the Keel docs aesthetic the operator wants to reuse. The site needs the same structural theme language as Keel while shifting the palette toward subway-system colors and giving the top navigation a distinct transit-native header treatment.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Reuse the upstream Keel docs shell so Transit’s public site benefits from the same proven visual structure across navbar, docs chrome, and homepage sections. | Manual review confirms the Transit site shares the same structural theme language as Keel instead of the previous lighter local shell. | Shared shell refresh shipped |
| GOAL-02 | Differentiate Transit from Keel through a subway-inspired palette and Transit-specific navigation chrome, especially in the top header. | Manual review confirms the shell uses a new route-inspired palette and a distinct top nav/header color treatment. | Palette refresh shipped |
| GOAL-03 | Preserve the current public-docs routes and delivery workflow while improving first-impression clarity. | `just docs-build` passes and all existing public docs routes remain intact after the restyle. | Refresh lands without workflow regression |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| First-Time Reader | The engineer, architect, or evaluator landing on Transit docs for the first time. | A polished first impression that signals product coherence before they dive into the content. |
| Returning Contributor | The maintainer or teammate already using the docs site. | A visual refresh that improves readability and identity without disrupting the existing route structure. |

## Scope

### In Scope

- [SCOPE-01] Port the upstream Keel docs shell patterns needed for Transit’s Docusaurus theme, including the differentiated navbar/header structure.
- [SCOPE-02] Replace the current palette with a subway-inspired Transit scheme across shared docs chrome, accents, and CTA treatments.
- [SCOPE-03] Restyle the public homepage to match the Keel aesthetic while preserving Transit-specific copy, links, and product framing.

### Out of Scope

- [SCOPE-04] Rewriting the public docs information architecture or adding new MDX content beyond small copy adjustments required by the visual refresh.
- [SCOPE-05] Redesigning the Transit logo, publishing pipeline, or foundational-doc sync workflow.
- [SCOPE-06] Porting Keel-specific interactive homepage components that are not needed to achieve the shared visual language.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Reuse the upstream Keel docs shell in Transit’s Docusaurus theme so navbar, docs surfaces, and supporting chrome share one visual system. | GOAL-01 | must | The operator explicitly wants the Keel documentation aesthetic, not another bespoke Transit-only shell. |
| FR-02 | Apply a subway-inspired Transit palette, with a distinct top nav/header color treatment that differs from Keel’s default blue shell. | GOAL-02 | must | The site should feel like Transit, not a clone with the old colors left intact. |
| FR-03 | Refresh the public homepage to match the Keel visual language while preserving Transit product messaging and route links. | GOAL-01, GOAL-03 | must | The landing page is the most visible part of the public docs experience. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Maintain clear readability and contrast across the refreshed shell, especially in navigation, buttons, and doc surfaces. | GOAL-02, GOAL-03 | must | The visual refresh must improve perception without making the docs harder to read. |
| NFR-02 | Keep the docs site buildable through the existing repo workflow without adding manual theme sync steps outside the repo. | GOAL-03 | must | This slice should not create a fragile maintenance burden. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Shared shell and homepage | Manual visual review plus docs build | Story-level verification artifacts linked during execution |
| Workflow preservation | Repo docs build path | `just docs-build` output linked from story evidence |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The upstream Keel docs shell can be reused in Transit with limited adaptation rather than a full component-for-component port. | The restyle may balloon into a larger frontend rewrite. | Validate during implementation by porting only the shared shell and Transit homepage surface. |
| The current public docs content and route structure are already strong enough that a visual refresh materially improves first-impression clarity. | The site may still feel hard to approach even after the restyle. | Reassess after the themed shell lands. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Which subway routes/colors should dominate the palette if the initial scheme feels too transit-authority-neutral? | Epic owner | Open |
| How much of Keel’s homepage interaction language should be mirrored before Transit stops feeling like itself? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Transit’s public docs share the upstream Keel shell structure across navbar and doc surfaces.
- [ ] The top navigation/header and accent system visibly shift to a subway-inspired Transit palette.
- [ ] The site builds successfully through `just docs-build` without route or workflow regressions.
<!-- END SUCCESS_CRITERIA -->
