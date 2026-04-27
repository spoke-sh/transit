# Hosted Authority Hardening For Durable External Systems - Product Requirements

## Problem Statement

Hosted Transit has useful lineage and durability semantics, but transport auth, stream ownership fencing, and finality proof surfaces are not yet hard enough for production external authority or blockchain-style fork and finality workflows.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Enforce declared hosted auth posture at the protocol boundary. | Server tests prove unauthenticated requests fail when auth is configured and local `none` mode remains explicit. | Token auth lands first; mTLS remains documented unless implemented. |
| GOAL-02 | Replace plain object-store lease writes with conditional fencing semantics where supported. | Competing acquisition and heartbeat tests prove stale owners cannot overwrite newer leases. | Provider-backed CAS or a documented fallback contract lands. |
| GOAL-03 | Define a blockchain-style finality and fork proof contract on top of Transit lineage. | Docs and proof types explain blocks as records, forks as branches, finality as checkpoints, and reorgs as explicit lineage events. | Contract doc plus tests for proof envelope construction. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Hosted Transit Operator | Runs Transit as the authoritative server for downstream clients. | Enforced auth, explicit acknowledgements, and durable fencing. |
| External System Integrator | Evaluates Transit for systems with finality or audit requirements. | Concrete proof and fork semantics instead of informal replay claims. |
| Blockchain-Style Application Developer | Models block streams, forks, finality, or reorg workflows. | A lineage-native mapping that preserves immutable history. |

## Scope

### In Scope

- [SCOPE-01] Hosted token auth enforcement and remote error semantics.
- [SCOPE-02] Conditional lease acquisition, heartbeat, and handoff fencing where the object-store backend supports it.
- [SCOPE-03] Finality/fork proof envelope design and documentation.
- [SCOPE-04] Tests and proof updates for auth, fencing, and proof construction.

### Out of Scope

- [SCOPE-05] Multi-primary writes or dynamic sharding.
- [SCOPE-06] Full mTLS certificate lifecycle unless explicitly pulled into a later voyage.
- [SCOPE-07] A cryptocurrency runtime, consensus protocol, or VM.
- [SCOPE-08] Signed attestations or external key management.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Enforce hosted `token` auth posture in the framed protocol and preserve explicit non-claims for modes not implemented. | GOAL-01 | must | Hosted consumers need declared auth to become real runtime behavior. |
| FR-02 | Add protocol-level auth failure errors without discarding request correlation or topology metadata. | GOAL-01 | must | Clients need actionable remote errors. |
| FR-03 | Implement conditional object-store lease writes for acquire, heartbeat, and handoff, or publish a strict fallback contract when CAS is unavailable. | GOAL-02 | must | Plain overwrites are too weak for production stream ownership. |
| FR-04 | Define finality and fork proof envelopes that bind stream id, head offset, manifest root, parent heads, checkpoint kind, and optional application block metadata. | GOAL-03 | should | Blockchain-style consumers need a precise mapping to Transit lineage. |
| FR-05 | Document the block/fork/finality mapping and update proof guidance without claiming a full blockchain runtime. | GOAL-03 | should | The use case should be credible but scoped. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Hosted hardening shall preserve shared-engine storage and lineage semantics. | GOAL-01, GOAL-02 | must | Auth and ownership must not create server-only history behavior. |
| NFR-02 | Fencing behavior shall fail closed when ownership cannot be proven. | GOAL-02 | must | Overclaiming leadership is worse than rejecting writes. |
| NFR-03 | Blockchain-style docs shall distinguish Transit lineage/finality primitives from application consensus. | GOAL-03 | must | Transit should not overclaim a complete chain system. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Token auth | Server and client tests over allowed and rejected requests | Remote error and acknowledgement proof logs |
| Lease fencing | Object-store-backed tests for acquire, heartbeat, handoff, and stale-owner publish attempts | Consensus and engine test evidence |
| Finality/fork contract | Doc review plus proof-envelope unit tests | Contract docs and story proof logs |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| `object_store` exposes enough conditional write metadata for at least the primary filesystem/S3-compatible path. | Fencing may require provider-specific adapters. | Validate in the lease-fencing story before changing public guarantees. |
| Token auth is the right first enforced posture. | mTLS may be needed earlier for hosted users. | Keep mTLS as declared posture until implementation is explicitly scoped. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| What exact credential placement belongs in the framed protocol without implying HTTP semantics? | Epic owner | Open |
| Which object-store providers can support equivalent conditional lease updates? | Epic owner | Open |
| Should finality proof envelopes live in `storage`, `integrity`, or a new proof module? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Hosted token auth is enforced and visible through remote error envelopes.
- [ ] Lease acquire, heartbeat, handoff, and manifest publication cannot silently overwrite newer ownership.
- [ ] A documented finality/fork proof contract maps blockchain-style workflows onto Transit lineage without claiming full application consensus.
- [ ] Proof guidance and tests match the hardened guarantees.
<!-- END SUCCESS_CRITERIA -->
