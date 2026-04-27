# Harden Hosted Protocol Auth And Lease Fencing - SRS

## Summary

Epic: VI1mcFKum
Goal: Make hosted acknowledgement, auth, stream ownership, and proof APIs explicit enough for downstream systems that need finality, reorg handling, or auditability.

## Scope

### In Scope

- [SCOPE-01] Hosted token auth enforcement in the framed protocol.
- [SCOPE-02] Remote error semantics for auth failures.
- [SCOPE-03] Conditional object-store lease fencing.
- [SCOPE-04] Blockchain-style finality and fork proof contract.
- [SCOPE-04] Tests and docs for hardened guarantees.

### Out of Scope

- [SCOPE-06] Multi-primary writes, sharding, or application consensus.
- [SCOPE-07] Full mTLS implementation and certificate lifecycle.
- [SCOPE-08] External signing, key management, or attestation service integration.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | The server shall reject unauthenticated framed requests when configured with token auth, while preserving explicit `none` mode for local development. | SCOPE-01 | FR-01 | automated |
| SRS-02 | Auth failures shall return remote error envelopes with request id, topology, stable error code, and message. | SCOPE-02 | FR-02 | automated |
| SRS-03 | Object-store consensus shall use conditional writes or equivalent generation checks for acquire, heartbeat, and handoff so stale owners cannot overwrite newer leases. | SCOPE-03 | FR-03 | automated |
| SRS-04 | Manifest publication shall fail closed when the current lease proof cannot be verified against the remote authority. | SCOPE-03 | FR-03 | automated |
| SRS-05 | Transit shall document and expose a finality/fork proof contract that maps records to blocks, branches to forks, checkpoints to finality markers, and explicit merge or selection artifacts to reorg handling. | SCOPE-04 | FR-04 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Auth and fencing shall not create server-only storage semantics or bypass shared-engine lineage. | SCOPE-01, SCOPE-03 | NFR-01 | manual |
| SRS-NFR-02 | Ownership uncertainty shall reject writes or publication instead of returning an overstated acknowledgement. | SCOPE-03 | NFR-02 | automated |
| SRS-NFR-03 | Blockchain-style documentation shall state that Transit supplies lineage/finality primitives, not a complete blockchain consensus runtime. | SCOPE-04 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
