# Launch Public Docs Platform - SRS

## Summary

Epic: VF7qPMy1g
Goal: Ship the first public Transit docs surface with a strong product narrative, runnable onramp tracks for library and server users, foundational contract publishing, and a static S3/CloudFront deploy path.

## Scope

### In Scope

- [SCOPE-01] A Docusaurus site scaffold in this repo with custom Transit branding, navigation, homepage, and docs information architecture.
- [SCOPE-02] Public-facing MDX docs that explain Transit concepts plus separate first-run tracks for library and server users.
- [SCOPE-03] A publish step that brings foundational repo Markdown documents into the documentation site as canonical reference material.
- [SCOPE-04] A CI/deploy path that builds the docs site and publishes static output for S3 and CloudFront hosting.

### Out of Scope

- [SCOPE-05] Generated API reference from Rust doc comments, protobufs, or protocol schemas.
- [SCOPE-06] Search, analytics, localization, or multi-version docs.
- [SCOPE-07] Production DNS, AWS account provisioning, or one-off bucket/distribution setup done outside the repo.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Create a Docusaurus workspace under `website/` with Transit-specific configuration, a public home page, custom styling, and a docs sidebar that can support both narrative guides and published foundational references. | SCOPE-01 | FR-01 | build + manual |
| SRS-02 | Author concept docs that explain Transit’s core model, the transport/rail metaphor, durability modes, and the relationship between embedded and server modes without depending on internal planning jargon. | SCOPE-02 | FR-02 | manual |
| SRS-03 | Author separate first-run docs for library and server users that point to the repo’s existing proof and command paths. | SCOPE-02 | FR-03 | manual |
| SRS-04 | Add a repeatable sync step that publishes selected foundational Markdown files from the repo root into the website docs tree during build preparation. | SCOPE-03 | FR-04 | build + manual |
| SRS-05 | Add a deployment workflow that builds the site and supports syncing static output to S3 plus CloudFront invalidation using repository-provided configuration. | SCOPE-04 | FR-05 | workflow review + manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The public docs must preserve Transit’s one-engine, immutable-history, lineage, and explicit-durability semantics without introducing simplified but false claims. | SCOPE-02, SCOPE-03 | NFR-01 | manual |
| SRS-NFR-02 | The docs site must build from a clean repo checkout without requiring manual copying of foundational documents into the website tree. | SCOPE-01, SCOPE-03, SCOPE-04 | NFR-02 | build |
| SRS-NFR-03 | The visual presentation must establish a distinct Transit identity with a transport-native design language instead of an unstyled default Docusaurus look. | SCOPE-01, SCOPE-02 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
