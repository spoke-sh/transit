# Materialized Reference Projection Surface - SRS

## Summary

Epic: VGh59soBt
Goal: Define how authoritative Transit streams materialize into replayable reference views so external consumers can rebuild or query derived state without hidden local persistence.

## Scope

### In Scope

- [SCOPE-01] Reference reducer and checkpoint contracts for consumer-owned stream families.
- [SCOPE-02] Materialization proofs that derive reference views from replay and resume from checkpoints.
- [SCOPE-03] Projection outputs and inspection surfaces that remain replaceable read models instead of hidden mutable truth.

### Out of Scope

- [SCOPE-04] Hub-specific auth UX, provider policy, or entitlement logic.
- [SCOPE-05] Shipping canonical consumer auth/account/session schemas inside Transit core.
- [SCOPE-06] Distributed materialization coordination outside the current hosted authority slice.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Define the reference reducer contracts and inputs needed to derive consumer-owned views from authoritative stream history. | SCOPE-01 | FR-03 | docs + code review |
| SRS-02 | Implement or prove checkpointed materialization that can derive reference views from authoritative replay and resume without reprocessing settled history. | SCOPE-02 | FR-03 | test + proof |
| SRS-03 | Ensure reference projections remain replayable, replaceable read models whose checkpoints anchor to the same lineage and manifests as the core engine. | SCOPE-03 | FR-03 | test + proof |
| SRS-04 | Provide an inspection or proof surface that demonstrates an external consumer can rebuild equivalent reference state from authoritative history and checkpoints. | SCOPE-02, SCOPE-03 | FR-04 | proof |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Reference reducers must remain projection plumbing layered on Transit history rather than new mutable server-owned truth tables. | SCOPE-01 | NFR-01 | code review |
| SRS-NFR-02 | Projection checkpoints must anchor to shared manifests and lineage checkpoints, not a projection-only authority model. | SCOPE-02 | NFR-01 | test |
| SRS-NFR-03 | Reference projection vocabulary must stop short of consumer-specific auth policy, schemas, or provider rules. | SCOPE-03 | NFR-03 | code review |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
