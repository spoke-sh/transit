# Implement Verifiable Lineage And Cryptographic Integrity - Product Requirements

> Implementation of SHA-256 digests, manifest roots, and lineage checkpoints for verifiable history.

## Problem Statement

`transit` has an authored integrity contract, but the repo needs to implement the core cryptographic primitives for segments, manifests, and checkpoints so history can be verified during publication, restore, and audit.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Implement SHA-256 content digests for immutable segments and manifest roots for stable history verification. | Segments and manifests have verifiable digests | Implementation verified |
| GOAL-02 | Implement lineage checkpoints for verifiable stream heads. | Checkpoints bind to manifest roots | Implementation verified |
| GOAL-03 | Expose visual integrity verification in the CLI. | CLI surfaces trust chain and verification map | Implementation verified |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Core Engineer | Builds storage and recovery surfaces | Stable integrity primitives in the engine |
| Operator | Runs nodes and audits history | Clear verification tools and proof artifacts |

## Scope

### In Scope

- [SCOPE-01] SHA-256 digests for segments and manifest roots in `transit-core`.
- [SCOPE-02] `LineageCheckpoint` implementation and verification.
- [SCOPE-03] Visual integrity verification in `transit-cli`.

### Out of Scope

- [SCOPE-04] Per-record signatures or external attestation.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Implement segment content digests and manifest roots in the storage kernel. | GOAL-01 | must | Core primitives for verifiable history. |
| FR-02 | Enforce digest verification during tiered restore and publication. | GOAL-01 | must | Prevents restore or publication of tampered segments. |
| FR-03 | Implement LineageCheckpoint creation and verification. | GOAL-02 | must | Binds stream heads to verified history. |
| FR-04 | Add visual trust-chain and verification-map surfaces to the CLI. | GOAL-03 | must | Makes integrity status human-inspectable. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve append-path latency by deferring digest computation to segment-roll and publication. | GOAL-01 | must | Maintains performance while adding verification. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

- Automated unit tests for tampering detection.
- CLI proofs for trust-chain and verification-map rendering.
- `just screen` end-to-end verification.

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| SHA-256 provides sufficient integrity for the first implementation slice. | Need to migration digests later. | Verified by implementation experience. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| How will we handle digest rotation in the future? | Architecture | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [x] Segments and manifests have SHA-256 digests.
- [x] Lineage checkpoints are verifiable.
- [x] CLI shows a visual trust chain.
<!-- END SUCCESS_CRITERIA -->
