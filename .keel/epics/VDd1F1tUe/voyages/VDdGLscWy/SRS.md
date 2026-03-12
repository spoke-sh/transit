# Verifiable Lineage Contract - SRS

## Summary

Epic: VDd1F1tUe
Goal: Define the minimum integrity contract for segments, manifests, and verification checkpoints without slowing the hot append path.

## Scope

### In Scope

- [SCOPE-01] Integrity artifacts for immutable segments, manifests, and lineage checkpoints.
- [SCOPE-02] Verification boundaries for append, segment roll, object-store publication, restore, and lineage inspection.
- [SCOPE-03] Cross-document alignment for architecture, evaluation, configuration, and release guidance.

### Out of Scope

- [SCOPE-04] Key management, external attestation, or per-record signatures.
- [SCOPE-05] Implementing cryptographic verification in code during this voyage.
- [SCOPE-06] Distributed replication proofs or multi-node trust semantics.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Define the minimum immutable integrity artifacts for `transit`: fast segment checksum, cryptographic segment digest, and manifest root. | SCOPE-01 | FR-01 | manual |
| SRS-02 | Define the lineage checkpoint contract and the minimum proof surface required for remote restore and lineage inspection. | SCOPE-01 | FR-01 | manual |
| SRS-03 | Define the verification lifecycle for append, segment roll, object-store publication, restore, and lineage inspection, including which work is deferred off the hot path. | SCOPE-02 | FR-02 | manual |
| SRS-04 | Align the repository documentation so the architecture, evaluation, configuration, and release surfaces reference the same staged integrity model. | SCOPE-03 | FR-03 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The integrity contract must preserve the hot append path by keeping heavyweight proofs and signing out of the default acknowledgement path. | SCOPE-01, SCOPE-02 | NFR-01 | manual |
| SRS-NFR-02 | The contract must remain provider-neutral and implementation-ready for both embedded and server packaging. | SCOPE-01, SCOPE-03 | NFR-02 | manual |
| SRS-NFR-03 | The integrity surfaces must be auditable and benchmarkable so restore and release claims can be verified later. | SCOPE-02, SCOPE-03 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
