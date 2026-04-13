# Make Transit Server The Hosted Authority For External Workloads And Derived State - Product Requirements

## Problem Statement

Spoke Hub and similar consumers still open local Transit storage for domain-owned control-plane records such as auth/account/session events, while transit-server still treats filesystem state as the primary persistence surface. We need hosted Transit to own authoritative append, replay, and generic materialization mechanics for external control planes without absorbing consumer schemas or introducing a second storage or lineage model.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Move external workload producers and readers onto hosted Transit as the authoritative append and replay surface. | Proofs show representative consumer-owned records can be written and replayed through a running transit server without local embedded authority | Voyage `VGh5B5qMT` completed |
| GOAL-02 | Make tiered server durability real by treating object storage as the long-term authority and warm filesystem state as cache and working set. | Proofs show restart or cache loss can recover authoritative history from the remote tier while keeping durability labels explicit | Voyage `VGh5BgrVO` completed |
| GOAL-03 | Materialize replayable reference views from authoritative Transit streams using shared checkpoints and lineage. | Proofs rebuild equivalent reference projections from stream history and checkpoint resume without hidden mutable truth | Voyage `VGh5CIxcc` completed |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Control-Plane Integrator | The engineer wiring Spoke Hub or a similar service onto hosted Transit for domain-owned stateful workloads. | Hosted append/replay/materialization surfaces that eliminate local embedded authority while leaving schema ownership in the consumer. |
| Transit Operator | The engineer running transit-server as a shared authority service. | Explicit durability rules, object-store-backed recovery, and proofs that match real server behavior. |
| Projection Builder | The engineer deriving consumer-owned read models, such as Spoke auth/account/session state, from authoritative history. | Checkpointed materialization surfaces that reuse Transit lineage rather than inventing a second state system. |

## Scope

### In Scope

- [SCOPE-01] Hosted authority contracts and proof paths for external workload producers and readers.
- [SCOPE-02] Server durability and startup rules that make object storage authoritative and warm filesystem state recoverable.
- [SCOPE-03] Reference materialization contracts and proofs for consumer-owned projections derived from authoritative streams.

### Out of Scope

- [SCOPE-04] Hub UI, browser routing, or consumer-facing product experience work.
- [SCOPE-05] Consumer-specific domain policy, entitlement rules, or business logic.
- [SCOPE-06] Generalized identity, account, or product surfaces implemented inside Transit.
- [SCOPE-07] Replication, quorum, or failover changes beyond what is required to keep durability labels honest for the hosted authority path.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Provide a hosted authority contract so external consumers can publish and replay consumer-owned records through transit-server instead of opening local embedded Transit storage. | GOAL-01 | must | Hosted Transit must become the authoritative message surface before Hub can stop losing domain-owned state on redeploy. |
| FR-02 | Make object storage the long-term authoritative tier for hosted server durability and treat filesystem state as warm cache or working set rather than the only persistence path. | GOAL-02 | must | The current filesystem-first server path contradicts the product thesis and the desired production posture. |
| FR-03 | Provide checkpointed materialization surfaces so authoritative streams can derive replayable reference views from shared lineage and manifests. | GOAL-03 | must | Consumers need replaceable read models, not hidden mutable server state. |
| FR-04 | Prove the hosted authority path end to end through repo-native proof surfaces. | GOAL-01, GOAL-02, GOAL-03 | must | The operator needs evidence that the authority model works in practice, not just in documentation. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve the shared-engine thesis: server authority, tiering, and projections must reuse the same manifests, checkpoints, and lineage model as embedded mode. | GOAL-01, GOAL-02, GOAL-03 | must | Transit cannot solve hosted authority by creating a second semantic world. |
| NFR-02 | Keep durability labels explicit at acknowledgement, proof, and operator surfaces. | GOAL-01, GOAL-02 | must | Hosted authority work must not blur `local` and `tiered` guarantees. |
| NFR-03 | Keep consumer-specific domain policy outside Transit core even when reference projection fixtures are added. | GOAL-01, GOAL-03 | must | Transit should host authoritative history and derivation patterns, not absorb consumer business rules. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Hosted authority wiring | Tests plus remote client or server proofs showing append/replay without local embedded authority | Accepted story evidence in voyage `VGh5B5qMT` |
| Tiered durability | Server restart, hydrate, and cache-loss proofs with explicit `local`/`tiered` outputs | Accepted story evidence in voyage `VGh5BgrVO` |
| Materialized projections | Checkpoint/resume proofs rebuilding reference views from authoritative history | Accepted story evidence in voyage `VGh5CIxcc` |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Spoke Hub auth/account/session is the first high-value external consumer, but the hosted authority and projection surfaces should remain reusable for other control planes. | The epic could become too Spoke-specific or too abstract. | Re-check during voyage implementation and review shared boundaries in design. |
| The existing client, tiered storage, and materialization primitives are sufficient foundations for this hosted authority slice without reopening consensus scope. | The epic may sprawl into replication or multi-node redesign. | Validate during voyage planning and keep replication work out of scope unless a hard blocker appears. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should the hosted authority proof live only in Transit or also expose reusable fixtures for downstream repos such as Spoke? | Epic owner | Open |
| How much reference projection vocabulary belongs in Transit before downstream repos such as Spoke should own the rest of the schema? | Epic owner | Open |
| What acknowledgement boundary should gate `tiered` claims when object-store publication lags hot appends? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] External workload consumers can use hosted Transit as the authoritative append and replay surface without local embedded authority.
- [ ] transit-server proves object-store-backed authority with warm-cache restart or recovery behavior.
- [ ] Reference projections rebuild from authoritative history and checkpoint resume without hidden mutable truth.
<!-- END SUCCESS_CRITERIA -->
