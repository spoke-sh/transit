# Research Auto-Threaded Communication And Collaboration - Product Requirements

> Define the first communication contract for `transit` so channel roots, native thread branches, classifier evidence, and explicit thread reconciliation become a first-party workload model.

## Problem Statement

`transit` already claims that channels should map to root streams and threads should map to native branches, with classifier-driven auto-threading as a signature use case. What it still lacks is a canonical communication contract. Without that contract, future product work will drift between flat message streams with side tables, storage-coupled UI policy, and vague references to "auto-threading" that do not define what is actually appended, branched, or merged. The product needs one explicit model that says what belongs in `transit` lineage primitives, what belongs in application conventions above them, and how classifier evidence, manual overrides, summaries, backlinks, and reconciliation should behave.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Define the minimum communication contract for channels, threads, messages, summaries, and backlinks on top of native streams and branches. | Contract authored | Canonical contract published |
| GOAL-02 | Define classifier evidence, human override, and thread reconciliation semantics without bloating the hot message path. | Lifecycle and reconciliation model documented | Design center published |
| GOAL-03 | Align repository architecture, guide, and evaluation guidance around the same communication workload model. | Cross-doc guidance updated | Alignment complete |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Application Engineer | Builds channel and thread experiences on top of `transit` | A clear event and metadata model for communication workloads |
| Model / Classifier Engineer | Produces thread-boundary decisions and override workflows | Explicit audit surfaces for classifier evidence and human correction |
| Operator / Benchmark Author | Verifies replay, latency, and correctness under communication load | A benchmarkable and inspectable workload contract |

## Scope

### In Scope

- [SCOPE-01] Define the canonical communication event model for channels, threads, messages, summaries, and backlinks.
- [SCOPE-02] Define classifier evidence, human override, and reconciliation semantics for auto-threading.
- [SCOPE-03] Align repository docs and evaluation guidance around that contract.

### Out of Scope

- [SCOPE-04] Designing a full chat UI, moderation policy engine, or notification system.
- [SCOPE-05] Teaching the storage engine presentation or moderation policy details.
- [SCOPE-06] Replacing native branches with opaque application-level thread tables.
- [SCOPE-07] Implementing server-mode collaboration features in this epic.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Define the minimum communication contract for `transit`, including channels as root streams, threads as child branches, canonical message events, and optional summary or backlink artifacts. | GOAL-01 | must | The communication story needs one stable workload contract. |
| FR-02 | Define the metadata and lifecycle model for classifier-created thread splits, human overrides, and reconciliation artifacts. | GOAL-02 | must | Auto-threading needs explicit audit and override semantics. |
| FR-03 | Align architecture, guide, and evaluation surfaces around the communication contract and the auto-threading workload model. | GOAL-03 | must | Future implementation and benchmarks should cite one contract. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve the one-engine thesis by keeping channels and threads mapped to shared stream and branch semantics across embedded and server packaging. | GOAL-01, GOAL-03 | must | Communication must remain a workload on the engine, not a separate storage mode. |
| NFR-02 | Keep classifier evidence, override metadata, and reconciliation artifacts explicit but off the default append path for ordinary messages. | GOAL-02 | must | Auto-threading should remain inspectable without bloating every message append. |
| NFR-03 | Keep the workload auditable and benchmarkable so classifier-to-branch latency, threaded replay correctness, and override behavior can be verified later. | GOAL-02, GOAL-03 | must | Product claims should stay measurable. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

- Prove the communication contract through voyage SRS coverage and authored repository artifacts.
- Verify the design boundary by updating repo docs to preserve native branch semantics and explicit classifier evidence.
- Re-run `keel doctor` and `keel flow` after planning and execution so the research mission stays coherent.

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The durable local engine and current lineage model are stable enough to define a communication workload contract | The contract may need rework if branch or merge semantics change materially | Validate against the current engine and docs |
| Auto-threading remains the clearest product-facing demonstration of `transit`'s lineage model | The workload may be overemphasized relative to other use cases | Re-check once additional reference workloads mature |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Which reconciliation flows should ever use explicit merges instead of summaries or backlinks? | Architecture | Open |
| How much override and moderation behavior should remain application-level rather than repository-wide contract? | Architecture | Open |
| Could product behavior leak into core storage semantics prematurely? | Architecture | Mitigated by scope and NFR-01 |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] The repo contains a canonical communication contract for channels, threads, message events, and optional summary/backlink artifacts.
- [ ] The repo contains an explicit model for classifier evidence, human overrides, and thread reconciliation that does not bloat ordinary message appends.
- [ ] Architecture, guide, and evaluation guidance all describe the same auto-threading workload model.
<!-- END SUCCESS_CRITERIA -->

## Research Analysis

*From bearing assessment:*

### Findings

- The communication thesis is already structurally supported: root streams, thread branches, classifier evidence, and replay correctness are all first-class concepts in the current docs [SRC-01] [SRC-02] [SRC-03] [SRC-04].
- The key research challenge is scope discipline. `transit` should own branch and merge lineage, while thread summaries, backlinks, moderation, and UI policy should stay mostly above the storage substrate [SRC-02] [SRC-03].

### Opportunity Cost

This work competes with deeper storage engineering, but without a concrete communication workload the product risks underspecifying the signature branch-as-thread story that differentiates it [SRC-01] [SRC-04].

### Dependencies

- Reliable branch creation, lineage metadata, merge artifacts, and evaluation harnesses are prerequisites for validating this workload beyond documents [SRC-02] [SRC-04].

### Alternatives Considered

- Treat communication as just another flat append stream with application-level threading tables, but that throws away the explicit lineage model `transit` is built to provide [SRC-01] [SRC-02].

---

*This PRD was seeded from bearing `VDd1F0OXH`. See `bearings/VDd1F0OXH/` for original research.*
