# Implement Verifiable Lineage Primitives - SRS

## Summary

Epic: VDoZVggut
Goal: Deliver the core integrity primitives and verification tools for transit.

## Scope

### In Scope

- [SCOPE-01] SHA-256 digests for segments and manifest roots.
- [SCOPE-02] `LineageCheckpoint` implementation and verification.
- [SCOPE-03] Visual integrity verification in `transit-cli`.

### Out of Scope

- [SCOPE-04] Per-record signatures.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Implement SHA-256 digests for segments and manifest roots in the storage kernel. | SCOPE-01 | FR-01 | automated |
| SRS-02 | Enforce digest verification during tiered restore and publication. | SCOPE-01 | FR-02 | automated |
| SRS-03 | Implement LineageCheckpoint creation and verification. | SCOPE-02 | FR-03 | automated |
| SRS-04 | Add visual trust-chain and verification-map surfaces to the CLI. | SCOPE-03 | FR-04 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Preserve append-path latency by deferring digest computation to segment-roll and publication. | SCOPE-01 | NFR-01 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
