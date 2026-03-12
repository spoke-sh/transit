# Cold History Publication And Restore - SRS

## Summary

Epic: VDeYUdLSW
Goal: Extend the local engine with object-store publication, cold-history restore, and shared-engine proof boundaries so tiered storage stays part of the executable design.

## Scope

### In Scope

- [SCOPE-01] Object-store publication of rolled immutable segments and the manifest state that references them.
- [SCOPE-02] Cold restore of local engine state from remote manifests and remote segment objects.
- [SCOPE-03] Human-facing verification of tiered durability and shared-engine boundaries.

### Out of Scope

- [SCOPE-04] Multi-node replication, quorum durability, or consensus.
- [SCOPE-05] Server-mode networking as a prerequisite for publication or restore.
- [SCOPE-06] Signed checkpoints, attestations, or broader trust infrastructure beyond the current integrity contract.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Implement object-store publication for rolled immutable segments plus the manifest updates needed to reference those objects. | SCOPE-01 | FR-04 | manual |
| SRS-02 | Implement cold restore that rebuilds local engine state from remote manifests and remote segment objects. | SCOPE-02 | FR-04 | manual |
| SRS-03 | Upgrade CLI and `just mission` proof surfaces so humans can verify tiered durability behavior and shared-engine boundaries end to end. | SCOPE-03 | FR-05 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Publication and restore behavior must keep using the shared engine semantics rather than introducing server-only or storage-format-specific behavior. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-04 | manual |
| SRS-NFR-02 | Durability, publication, and restore guarantees must remain explicit in tests, docs, and proof paths. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-03 | manual |
| SRS-NFR-03 | The voyage must remain single-node and local-first even while using object storage for cold history. | SCOPE-01, SCOPE-02 | NFR-01 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
