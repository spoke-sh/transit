# Deliver Embedded Replay And Artifact Helper APIs - Product Requirements

## Problem Statement

Transit already has lineage-aware branches, replay, materialization checkpoints, and explicit artifact contracts, but embedded callers still lack stable helper surfaces for branch metadata, root-plus-branch inspection, artifact envelopes, and checkpoint-driven replay workflows. That makes higher-level conversation layers harder to build without leaking app policy into Transit core.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Expose stable branch metadata helpers that embedded callers can use without hand-rolling lineage label conventions. | Branch metadata setup becomes a supported helper path instead of ad hoc map assembly. | One stable metadata helper surface is delivered. |
| GOAL-02 | Make root-plus-branch replay and materialization inspection easier for embedded applications. | An embedded caller can inspect divergent branch state without custom replay stitching. | One bounded root-plus-branch inspection path is delivered. |
| GOAL-03 | Provide artifact-envelope and checkpoint/replay helpers that keep Transit generic while reducing app-layer glue code. | Artifact and checkpoint flows become easier to use without introducing paddles-specific semantics into core APIs. | Helper APIs and proof flows cover artifact and checkpoint ergonomics. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Embedded Transit Integrator | The engineer building a branch-heavy application layer on top of Transit as a library. | Stable helper surfaces for metadata, replay inspection, artifact envelopes, and checkpoint resume without inventing hidden storage rules. |
| Transit Maintainer | The engineer evolving Transit without collapsing it into an application framework. | A helper layer that improves usability while preserving the engine's general lineage substrate. |

## Scope

### In Scope

- [SCOPE-01] Stable helper APIs for branch metadata and lineage labels that can carry app-owned thread or branch context without hardcoding app policy.
- [SCOPE-02] Embedded replay or materialization views that make root-plus-branch inspection straightforward and ancestry-aware.
- [SCOPE-03] Artifact-envelope helper APIs for summaries, backlinks, merge outcomes, and adjacent explicit artifacts.
- [SCOPE-04] Checkpoint and replay ergonomics that reduce glue code for apps building conversation or agent layers on top of Transit.
- [SCOPE-05] Proofs, docs, or examples that demonstrate the helper layer as an embedded substrate rather than a product-specific framework.

### Out of Scope

- [SCOPE-06] Paddles-specific conversation policy, classifier heuristics, moderation behavior, or auto-threading defaults.
- [SCOPE-07] Server-only query surfaces or UI workflows that bypass the shared engine model.
- [SCOPE-08] A universal schema for every communication artifact body or application domain built on Transit.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Deliver stable branch metadata helpers built on existing lineage primitives so embedded callers can construct and inspect branch context safely. | GOAL-01 | must | Branch metadata is the foundation for thread, branch, and replay semantics above the core engine. |
| FR-02 | Deliver embedded replay or materialization views that expose root-plus-branch state without forcing callers to flatten divergence manually. | GOAL-02 | must | Branch-heavy applications need first-class inspection of ancestor and child history. |
| FR-03 | Deliver artifact-envelope helper APIs for summaries, backlinks, merge outcomes, and related explicit artifacts using Transit’s existing envelope model. | GOAL-03 | must | Artifact helpers reduce repeated app-layer boilerplate while keeping audit semantics explicit. |
| FR-04 | Deliver checkpoint and replay helper ergonomics that let embedded applications resume branch-aware state cleanly. | GOAL-03 | must | Checkpoint usability is the other half of making replay-driven apps practical on top of Transit. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve Transit as a general lineage substrate and avoid hardcoding paddles-specific conversation policy into the helper APIs. | GOAL-01, GOAL-03 | must | This mission is about substrate ergonomics, not collapsing Transit into an app framework. |
| NFR-02 | Preserve shared-engine semantics across embedded and server modes, including lineage, replay, checkpoint, and storage behavior. | GOAL-01, GOAL-02, GOAL-03 | must | Helper APIs cannot create a second semantic world for one deployment mode. |
| NFR-03 | Keep summaries, backlinks, merge outcomes, and checkpoint state explicit, replayable, and artifact-oriented rather than hidden mutable side data. | GOAL-02, GOAL-03 | must | Replay and audit are central product invariants. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Problem outcome | Tests, CLI proofs, or manual review chosen during planning | Story-level verification artifacts linked during execution |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Existing lineage metadata, replay, checkpoint, and artifact contracts are strong enough to support a helper-focused mission without a separate foundational research slice. | The epic may discover missing substrate primitives mid-flight. | Validate helper design directly against `LineageMetadata`, replay, materialization, and artifact-envelope contracts during execution. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Which helpers belong in `transit-core` versus an adjacent first-party crate if the surface grows beyond minimal ergonomics? | Epic owner | Open |
| How much schema convenience can Transit provide before it starts encoding conversation-product behavior? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Embedded callers can construct stable branch metadata without ad hoc label assembly.
- [ ] Root-plus-branch replay or materialization inspection is available through a supported helper path.
- [ ] Artifact envelopes for summaries, backlinks, and merge outcomes are easier to author while staying explicit and replayable.
- [ ] Checkpoint and replay helpers reduce app-layer glue code without introducing paddles-specific policy into Transit core.
<!-- END SUCCESS_CRITERIA -->
