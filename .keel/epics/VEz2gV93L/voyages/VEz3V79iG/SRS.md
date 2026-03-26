# Integrity End-To-End Proof - SRS

## Summary

Epic: VEz2gV93L
Goal: Exercise segment checksums, manifest roots, lineage checkpoints, and tamper detection end-to-end through `just screen` in both embedded and server modes.

## Scope

### In Scope

- [SCOPE-01] End-to-end integrity verification in the `just screen` proof path covering segment checksums, manifest roots, and lineage checkpoints.
- [SCOPE-02] At least one tamper-detection scenario that corrupts a segment or manifest and confirms the engine detects and reports the corruption.
- [SCOPE-03] Proof that integrity verification works through both the local engine and the networked server path.

### Out of Scope

- [SCOPE-04] Cryptographic signature infrastructure, key management, or external PKI.
- [SCOPE-05] Stage 2/3 hardening (Merkle Mountain Ranges, incremental witness proofs).
- [SCOPE-06] Performance optimization or benchmarking of integrity verification.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Implement an `integrity-proof` CLI mission command that appends records, rolls segments, verifies segment checksums (fnv1a64) and content digests (sha256), and reports pass/fail per segment. | SCOPE-01 | FR-01 | test + screen |
| SRS-02 | Extend the integrity proof to publish segments to object storage, restore from the remote manifest, and verify that manifest roots match before and after restore. | SCOPE-01 | FR-02 | test + screen |
| SRS-03 | Extend the integrity proof to create branches and merges, produce lineage checkpoints via `engine.checkpoint()`, and verify them via `engine.verify_checkpoint()`. | SCOPE-01 | FR-03 | test + screen |
| SRS-04 | Implement a tamper-detection scenario that corrupts a sealed segment file on disk and confirms that `verify_local_lineage()` detects and reports the corruption. | SCOPE-02 | FR-04 | test + screen |
| SRS-05 | Exercise integrity verification through the networked server path to confirm shared-engine parity. | SCOPE-03 | FR-05 | test + screen |
| SRS-06 | Add the integrity proof as a step in the `just screen` recipe so it runs alongside the existing local, tiered, and networked proofs. | SCOPE-01 | FR-01 | screen |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Integrity verification must not gate normal append acknowledgements; verification attaches to sealed segments, manifests, and checkpoints. | SCOPE-01, SCOPE-03 | NFR-01 | test |
| SRS-NFR-02 | All proof output must be human-reviewable terminal text with clear pass/fail indicators. | SCOPE-01, SCOPE-02 | NFR-02 | screen |
| SRS-NFR-03 | The proof must produce structured JSON output via `--json` for machine consumption. | SCOPE-01 | NFR-02 | test |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
