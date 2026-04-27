# Publish Typed AI And Communication Event Builders - SRS

## Summary

Epic: VI1mbSnsy
Goal: Provide typed Rust helper APIs and examples for task traces, conversational threads, backlinks, summaries, artifacts, and merge metadata over shared lineage primitives.

## Scope

### In Scope

- [SCOPE-01] AI trace builders for the canonical trace entities.
- [SCOPE-02] Communication builders for channel, thread, backlink, summary, classifier, and override entities.
- [SCOPE-03] Artifact and merge helper integration.
- [SCOPE-04] Examples and docs for downstream adoption.

### Out of Scope

- [SCOPE-05] Application authorization, account, session, or moderation policy.
- [SCOPE-06] Model execution or classifier hosting.
- [SCOPE-07] UI rendering behavior for conversations or agent traces.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | The SDK shall provide typed AI trace builders for task roots, retry branches, critique branches, tool-call events, evaluator decisions, merge artifacts, and completion checkpoints. | SCOPE-01 | FR-01 | automated |
| SRS-02 | The SDK shall provide typed communication builders for channel messages, thread branches, thread replies, backlinks, summaries, classifier evidence, and human override artifacts. | SCOPE-02 | FR-02 | automated |
| SRS-03 | Helper output shall be ordinary Transit payload bytes plus `LineageMetadata`, `ArtifactEnvelope`, `StreamPosition`, or `MergeSpec` values that work through embedded and hosted APIs. | SCOPE-03 | FR-03 | automated |
| SRS-04 | Documentation and examples shall demonstrate at least one AI trace and one channel/thread workload end to end. | SCOPE-04 | FR-04 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Helper APIs shall not encode downstream business policy, identity policy, or provider-specific validation. | SCOPE-01, SCOPE-02 | NFR-01 | manual |
| SRS-NFR-02 | Helper-generated events shall preserve append-only history and explicit lineage semantics. | SCOPE-01, SCOPE-02 | NFR-02 | automated |
| SRS-NFR-03 | Public helper names and docs shall match the canonical vocabulary in root workload contracts. | SCOPE-04 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
