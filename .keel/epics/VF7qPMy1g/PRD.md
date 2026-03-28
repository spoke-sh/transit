# Public Docs Platform And First-Run Narrative - Product Requirements

## Problem Statement

Transit is powerful but still hard for first-time users to understand as either an embedded library or a networked server. The repo has strong internal contracts, but it lacks a public-facing docs surface that introduces the product, explains the transport metaphor, and gives new users a clear library/server onramp.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Give first-time users a clear narrative for what Transit is, why its model is different, and how the library and server modes relate. | Public docs intro and concept track explain product shape without requiring repo archaeology | Intro + concepts docs shipped |
| GOAL-02 | Provide runnable first-run paths for both embedded/library and server/operator users. | Separate library and server guides exist and point to the canonical proof paths | Onramp docs shipped |
| GOAL-03 | Publish the public docs and foundational repo contracts through one static documentation surface that can deploy to S3 and CloudFront. | Docusaurus site builds locally, includes foundational docs, and has an automated deployment path | Launch voyage completed |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Library Builder | The engineer evaluating Transit as an embedded Rust library. | A quick path from product explanation to local proof and core concepts. |
| Server Operator | The engineer evaluating Transit as a networked service. | A clear explanation of server mode, its boundaries, and how to run it. |
| Technical Evaluator | The maintainer, architect, or early adopter reading the docs before adoption. | A trustworthy narrative that links high-level guidance to canonical repo contracts. |

## Scope

### In Scope

- [SCOPE-01] A Docusaurus-based public documentation site under this repo with a custom Transit visual identity and rail/transport-oriented narrative.
- [SCOPE-02] Public-facing intro, concept, and first-run documentation for library and server use cases.
- [SCOPE-03] Integration of foundational repo documents into the published docs surface so canonical contracts remain accessible alongside the narrative docs.
- [SCOPE-04] A static deployment path suitable for S3 and CloudFront hosting.

### Out of Scope

- [SCOPE-05] API-complete reference generation from Rust doc comments or protocol schemas.
- [SCOPE-06] Full docs search, analytics, localization, or multi-version documentation.
- [SCOPE-07] Hosted auth, personalized portals, or interactive control-plane features.
- [SCOPE-08] Rewriting the foundational source documents themselves beyond small cross-linking or presentation-oriented edits.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Deliver a Docusaurus site with a public home page and docs information architecture that introduce Transit in user-facing language rather than internal board terminology. | GOAL-01, GOAL-03 | must | The product needs a true public front door. |
| FR-02 | Author concept docs that explain records, streams, branches, manifests, lineage, durability modes, and tiered storage using the Transit product vocabulary and transport metaphor. | GOAL-01 | must | First-time users need a mental model before they can evaluate the system. |
| FR-03 | Author separate first-run guides for embedded/library and networked/server users, each pointing to the current proof path and repo commands that validate the product locally. | GOAL-02 | must | The two adoption paths should be explicit instead of implied. |
| FR-04 | Publish foundational repo contracts through the docs site so readers can move from narrative docs to canonical technical documents without leaving the documentation surface. | GOAL-03 | must | Public docs should not drift away from the real contracts. |
| FR-05 | Add a deploy path that builds the site and syncs the static output to S3 with CloudFront invalidation support. | GOAL-03 | must | The docs need a real delivery path, not just a local demo. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | The public docs must preserve the repo's one-engine, explicit-durability, and immutable-history semantics without introducing simplified but false claims. | GOAL-01, GOAL-02 | must | Docs must improve comprehension without semantic drift. |
| NFR-02 | The docs build must be reproducible from the repo and should not require manual copy/paste of foundational documents before publication. | GOAL-03 | must | The publish path needs to stay maintainable. |
| NFR-03 | The visual design should feel intentional and differentiated, with a clear Transit identity rather than an unstyled default Docusaurus site. | GOAL-01 | should | The first public impression matters for comprehension and credibility. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Public docs scaffold | Static site build + manual review | Story-level verification artifacts |
| First-run guidance | Manual walkthrough against repo proof paths | Story-level verification artifacts |
| Foundational doc publishing + deploy path | Build/deploy workflow verification | Story-level verification artifacts |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| First-time user comprehension is currently limited more by presentation and narrative than by missing core product capability. | The docs launch may undershoot adoption friction. | Re-check after the first public docs slice. |
| The existing foundational Markdown files are good enough to publish with light framing rather than a full rewrite. | The launch may expose rough edges in the canonical docs. | Validate during foundational-doc integration. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| What final public site URL and CloudFront distribution should production deploys target? | Repo owner | Open |
| How much of the foundational corpus should appear as polished docs pages versus linked canonical reference? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] A public docs site explains Transit clearly enough that a first-time reader can distinguish the library and server adoption paths.
- [ ] The site includes a transport-native narrative plus canonical foundational documents.
- [ ] The site builds locally and has a documented deploy path for S3 and CloudFront.
<!-- END SUCCESS_CRITERIA -->
