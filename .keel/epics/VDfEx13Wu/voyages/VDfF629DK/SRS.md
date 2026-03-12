# Server Daemon And Core Lineage RPCs - SRS

## Summary

Epic: VDfEx13Wu
Goal: Deliver the first single-node transit daemon on the shared engine with remote append, read, tail, branch, merge, and lineage inspection semantics.

## Scope

### In Scope

- [SCOPE-01] Server daemon bootstrap, lifecycle, and configuration on top of the shared engine.
- [SCOPE-02] Remote append, read, and tail operations that preserve current engine semantics.
- [SCOPE-03] Remote branch, merge, and lineage inspection operations on the same server surface.

### Out of Scope

- [SCOPE-04] Replication, multi-node ownership, or consensus behavior.
- [SCOPE-05] Browser/public ingress, authentication policy, or multi-tenant controls beyond trusted proof-path assumptions.
- [SCOPE-06] Replacing the shared engine with server-specific storage logic.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Implement shared-engine server bootstrap so a single-node daemon can open the existing engine, bind a listener, and manage deterministic startup/shutdown behavior. | SCOPE-01 | FR-01 | manual |
| SRS-02 | Implement remote append, read, and tail operations that preserve stream positions, branch-aware replay semantics, and explicit durability results over the server boundary. | SCOPE-02 | FR-01 | manual |
| SRS-03 | Implement remote branch creation, merge recording, and lineage inspection operations on the same server surface. | SCOPE-03 | FR-01 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The daemon must remain a wrapper around the shared engine and storage layout rather than inventing a server-only semantic path. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-01 | manual |
| SRS-NFR-02 | The voyage must remain explicitly single-node and non-replicated even when operations are remote. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-02 | manual |
| SRS-NFR-03 | Remote durability, lifecycle, and error boundaries must remain explicit in the daemon and proof surfaces. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
