# Research Verifiable Lineage And Cryptographic Integrity - Product Requirements

> Define the first integrity contract for `transit` so segments, manifests, and checkpoints can become verifiable without forcing heavyweight cryptography into every append acknowledgement.

## Problem Statement

`transit` already claims immutable segments, explicit lineage, and object-store-backed recovery, but the repo does not yet define what counts as verified history. Without a concrete integrity contract, future storage, restore, and checkpoint work will drift between cheap checksums, heavyweight signing, and vague audit claims. The product needs one staged model that tells engineers and operators where checksums end, where cryptographic digests begin, and which proofs are required for remote restore or lineage inspection.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Publish the minimum integrity model for immutable segments and manifests. | Integrity artifacts documented | Contract authored |
| GOAL-02 | Define the verification lifecycle and checkpoint boundary for append, roll, publish, restore, and lineage inspection. | Verification stages documented | Lifecycle authored |
| GOAL-03 | Align architecture, evaluation, release, and configuration guidance around staged integrity hardening. | Cross-doc guidance updated | Alignment complete |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Core Engineer | Builds storage, recovery, and lineage surfaces | One integrity contract that fits the append-only engine |
| Operator | Runs nodes and restores history from object storage | Clear proof boundaries for restore, audit, and release decisions |
| Benchmark Author | Measures cost and correctness of durability features | Explicit integrity modes for benchmark and regression coverage |

## Scope

### In Scope

- [SCOPE-01] Integrity artifacts for immutable segments, manifests, and lineage checkpoints.
- [SCOPE-02] Verification boundaries for append, segment roll, object-store publication, restore, and lineage inspection.
- [SCOPE-03] Cross-document alignment so architecture, evaluation, configuration, and release guidance all describe the same staged hardening model.

### Out of Scope

- [SCOPE-04] Key management, per-record signatures, or external attestation systems.
- [SCOPE-05] Full cryptographic implementation in code during this epic.
- [SCOPE-06] Distributed replication proofs or multi-node trust models.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Define the minimum integrity artifacts for `transit`, including fast segment checksums, cryptographic segment digests, manifest roots, and lineage checkpoints. | GOAL-01 | must | The engine and docs need one shared proof model. |
| FR-02 | Define the verification lifecycle for append, segment roll, object-store publication, restore, and lineage inspection, including which work is deferred off the hot path. | GOAL-02 | must | Integrity work must be staged without distorting append latency claims. |
| FR-03 | Map the integrity contract onto architecture, evaluation, configuration, and release guidance. | GOAL-03 | must | Future implementation and benchmarking work should cite one contract instead of inventing new proof semantics. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve the current append-path latency thesis by keeping heavyweight proof generation and signing out of the default acknowledgement path. | GOAL-01, GOAL-02 | must | Integrity work should reinforce, not sabotage, the performance model. |
| NFR-02 | Keep the contract provider-neutral and compatible with both embedded and server packaging. | GOAL-01, GOAL-03 | must | Integrity semantics belong to the engine, not one deployment wrapper. |
| NFR-03 | Keep the integrity surfaces auditable and benchmarkable so restore and release claims can be verified later. | GOAL-02, GOAL-03 | must | Proof claims are only useful if they can be tested and published. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

- Prove the integrity contract through voyage SRS coverage and story-level authored artifacts.
- Verify cross-document alignment by updating the architecture, evaluation, configuration, and release docs to cite the same staged hardening model.
- Re-run `keel doctor` and `keel flow` after planning and execution so the research mission stays coherent.

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The current single-node kernel is mature enough to define stable immutable boundaries for segments and manifests | The contract may need rework if storage shape changes drastically | Validate against the current `transit-core` storage scaffold |
| Fast checksums and cryptographic proofs should remain separate concerns | Configuration and implementation may need simplification later | Re-check once storage benchmarks exist |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should the first cryptographic digest recommendation be `BLAKE3`, `SHA-256`, or algorithm-neutral? | Architecture | Open |
| How much checkpoint structure belongs in `transit-core` versus later materialization or client layers? | Architecture | Open |
| Could premature integrity hardening distort the throughput story of the hot path? | Architecture | Mitigated by staging work at segment roll, publish, and restore boundaries |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] The repo contains a verifiable-lineage contract that explains segment checksums, segment digests, manifest roots, and lineage checkpoints in `transit` terms.
- [ ] The verification lifecycle explicitly separates append-path work from segment-roll, publication, restore, and audit-time verification.
- [ ] Architecture, evaluation, configuration, and release guidance all point at the same staged integrity model.
<!-- END SUCCESS_CRITERIA -->

## Research Analysis

*From bearing assessment:*

### Findings

- Integrity work is structurally aligned with `transit` because the engine already centers immutable segments, manifests, and explicit lineage rather than mutable records or hidden rewrites [SRC-01] [SRC-02] [SRC-03].
- The best path is staged hardening: start with content integrity for segments and manifests, then decide later whether signed checkpoints or attestations belong in the product surface [SRC-02] [SRC-03].

### Opportunity Cost

Hardening verification too early would compete with delivery of the kernel itself, and integrity layers are only as good as the manifest and segment model they sit on top of [SRC-02].

### Dependencies

- Stable segment layout, manifest structure, and object-store publication flow are prerequisites for meaningful cryptographic hardening [SRC-02].

### Alternatives Considered

- Rely only on storage-provider checksums and local filesystem integrity, but that would leave lineage proofs and remote restore trust implicit rather than explicit [SRC-01] [SRC-03].

---

*This PRD was seeded from bearing `VDd1F1tUe`. See `bearings/VDd1F1tUe/` for original research.*
