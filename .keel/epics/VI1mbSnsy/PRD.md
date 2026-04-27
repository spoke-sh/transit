# Typed Workload SDKs For Conversational And Agent Lineage - Product Requirements

## Problem Statement

AI trace and communication contracts are documented, but downstream applications still need to assemble raw labels and payload conventions by hand, which invites semantic drift across agents, conversations, artifacts, and merges.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Publish typed AI trace helper APIs over existing stream, branch, merge, and artifact primitives. | Agent trace examples can create task roots, retry branches, critique branches, tool calls, evaluator decisions, merge artifacts, and completion checkpoints without stringly-typed boilerplate. | Rust API, tests, and docs land together. |
| GOAL-02 | Publish typed communication helper APIs for channel roots, thread branches, backlinks, summaries, classifier evidence, and overrides. | A communication workload example can create and replay a channel/thread topology with typed metadata. | Rust API and replay assertions cover the canonical thread flow. |
| GOAL-03 | Keep typed helpers as workload overlays rather than application policy engines. | Helpers preserve Transit-owned lineage vocabulary while leaving business schemas and authorization outside Transit core. | Public docs state the boundary and tests verify generic payload compatibility. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Agent Runtime Developer | Builds task traces, retries, critiques, and tool/evaluator provenance. | Stable typed builders that map agent events to Transit lineage. |
| Conversational App Developer | Builds channel, thread, summary, and moderation flows. | Typed branch/backlink/summary helpers that replay cleanly. |
| Downstream SDK Maintainer | Wraps Transit for application teams. | A canonical upstream vocabulary to avoid repo-local duplicate clients. |

## Scope

### In Scope

- [SCOPE-01] Typed AI trace event and lineage builders.
- [SCOPE-02] Typed communication event and lineage builders.
- [SCOPE-03] Artifact, summary, backlink, and merge-outcome helper integration.
- [SCOPE-04] Examples and docs for downstream application adoption.

### Out of Scope

- [SCOPE-05] Account, entitlement, moderation, or provider-specific schemas.
- [SCOPE-06] Server-side classifier execution or model hosting.
- [SCOPE-07] UI presentation policy for chat or agent traces.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Add typed builders for AI trace roots, branches, tool events, evaluator decisions, merge artifacts, and completion checkpoints. | GOAL-01 | must | Agent runtimes should not hand-author generic labels for canonical Transit trace concepts. |
| FR-02 | Add typed builders for channel messages, thread branches, replies, backlinks, summaries, classifier evidence, and human overrides. | GOAL-02 | must | Conversational lineage is a reference workload and needs a stable upstream SDK surface. |
| FR-03 | Ensure helper output remains ordinary Transit payload and lineage metadata that works through embedded and hosted APIs. | GOAL-03 | must | Typed helpers must not create a new storage mode. |
| FR-04 | Publish examples and docs that demonstrate replay, branch creation, backlink visibility, and explicit merge/summary boundaries. | GOAL-01, GOAL-02 | should | Downstream teams need copyable patterns that reinforce the architecture vocabulary. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve application schema neutrality; helpers may define Transit lineage vocabulary but not downstream business policy. | GOAL-03 | must | Transit should remain a substrate, not a vertical application backend. |
| NFR-02 | Preserve append-only semantics for every helper-generated event. | GOAL-01, GOAL-02 | must | Workload helpers cannot mutate acknowledged history. |
| NFR-03 | Keep helper naming aligned with `AI_TRACES.md`, `AI_ARTIFACTS.md`, and `COMMUNICATION.md`. | GOAL-01, GOAL-02 | must | Documentation and SDK vocabulary must not drift. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| AI trace helpers | Unit tests and example replay | Story evidence plus docs/example output |
| Communication helpers | Unit tests for channel/thread/backlink/summary replay | Story evidence plus docs/example output |
| Boundary discipline | Review and tests that helpers produce ordinary payloads and `LineageMetadata` | Story evidence and documentation update |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Typed builders can live in an existing crate without forcing a new published package boundary. | A crate split may be needed earlier. | Decide during first story after checking downstream import ergonomics. |
| Current `ArtifactEnvelope` can support summaries, backlinks, and merge outcomes with small additions. | Artifact helper work may need a stronger typed envelope. | Validate during communication builder implementation. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should typed helpers live in `transit-core`, `transit-client`, or a new `transit-workloads` crate? | Epic owner | Open |
| How much JSON payload shape should be stabilized now versus examples-only? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] AI trace helpers cover the canonical entities in `AI_TRACES.md`.
- [ ] Communication helpers cover channel roots, thread branches, backlinks, summaries, and overrides from `COMMUNICATION.md`.
- [ ] Helper-generated events replay through embedded and hosted surfaces without special storage semantics.
- [ ] Public docs show downstream usage without requiring private label conventions.
<!-- END SUCCESS_CRITERIA -->
