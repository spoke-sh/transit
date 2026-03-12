# Communication Contract And Auto-Threading Model - SRS

## Summary

Epic: VDd1F0OXH
Goal: Define the first auto-threaded communication contract on top of native branches

## Scope

### In Scope

- [SCOPE-01] The canonical communication event model for channels, threads, messages, summaries, and backlinks.
- [SCOPE-02] Classifier evidence, human override, and reconciliation semantics for auto-threading.
- [SCOPE-03] Cross-document alignment for repository architecture, guide, and evaluation surfaces.

### Out of Scope

- [SCOPE-04] Full chat UI, moderation product policy, or notification design.
- [SCOPE-05] Teaching the storage engine presentation or moderation details.
- [SCOPE-06] Replacing native branches with opaque threading tables.
- [SCOPE-07] Server-mode implementation work.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Define the canonical communication contract for `transit`, including channels as root streams, threads as child branches, canonical message events, and optional summary or backlink artifacts. | SCOPE-01 | FR-01 | manual |
| SRS-02 | Define the metadata required for classifier-created thread splits and human overrides without mutating existing message history. | SCOPE-02 | FR-02 | manual |
| SRS-03 | Define the thread lifecycle and reconciliation model, including when summaries, backlinks, and explicit merge artifacts should be used. | SCOPE-02 | FR-02 | manual |
| SRS-04 | Align repository documentation so the architecture, guide, and evaluation surfaces reference the same communication contract and workload boundaries. | SCOPE-03 | FR-03 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The contract must preserve native stream and branch semantics across embedded and server packaging rather than inventing a communication-specific storage mode. | SCOPE-01, SCOPE-03 | NFR-01 | manual |
| SRS-NFR-02 | Classifier evidence, overrides, and reconciliation artifacts must remain explicit but should not bloat the default append path for ordinary messages. | SCOPE-02 | NFR-02 | manual |
| SRS-NFR-03 | The workload must remain auditable and benchmarkable so classifier-to-branch latency, threaded replay correctness, and override traceability can be verified. | SCOPE-02, SCOPE-03 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
