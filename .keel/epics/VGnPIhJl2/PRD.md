# Projection Consumer Reads For Hosted Transit Client - Product Requirements

## Problem Statement

Transit publishes hosted append, replay, and lineage surfaces, but downstream consumers still lack a canonical upstream projection-read client API. Without one, hosted cutover paths either bail on projection reads or keep private wrappers outside `transit-client`.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Let downstream Rust consumers derive current projection views through `transit-client` from a hosted Transit server without reopening local embedded authority. | Tests or proof flows show a consumer reducer can build the expected view from authoritative hosted replay through `transit-client` | Voyage `VGnPLHvGm` completed |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Downstream Rust Integrator | The engineer cutting a Rust service over to hosted Transit. | A canonical upstream client API for projection reads so replay-driven materialization does not require a repo-local wrapper. |
| Projection Builder | The engineer deriving consumer-owned read models from hosted Transit. | Generic projection-consumer mechanics that preserve replay and reducer ownership boundaries. |

## Scope

### In Scope

- [SCOPE-01] A generic `transit-client` API for replay-driven projection reads over the hosted Transit boundary.
- [SCOPE-02] Proof or test coverage showing downstream-style reference projections can be reduced through the upstream client surface.
- [SCOPE-03] Documentation updates that publish the new projection-consumer surface as part of the canonical hosted Rust client boundary.

### Out of Scope

- [SCOPE-04] Shipping consumer-specific auth, account, session, or entitlement schemas inside Transit.
- [SCOPE-05] Introducing a projection-only server-owned truth table or mutable hosted read store.
- [SCOPE-06] Downstream repo implementation changes beyond what is necessary to prove the upstream API shape.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Publish a generic `transit-client` projection-consumer API that reduces authoritative hosted replay into a consumer-owned current view. | GOAL-01 | must | Downstream Rust repos need an upstream projection-read path that does not depend on private wrappers. |
| FR-02 | Prove the projection-consumer API against a hosted Transit server using a representative reference projection workload. | GOAL-01 | must | The projection path must be inspectable and evidence-backed before downstream cutover can rely on it. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve generic Transit semantics: reducer logic and consumer schema ownership stay outside Transit even when the client publishes projection-consumer helpers. | GOAL-01 | must | Transit should own reusable mechanics, not consumer policy. |
| NFR-02 | Keep projection reads replay-anchored and rebuildable from authoritative history rather than inventing a projection-only server truth path. | GOAL-01 | must | The hosted client surface must not create a second semantic world for derived state. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Hosted projection consumer path | Targeted `transit-client` tests and proof/example output against a running `transit-server` | Accepted story evidence in voyage `VGnPLHvGm` |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Downstream consumers can express their projection semantics as reducer logic over authoritative replay without Transit owning their schema. | The epic could accidentally force consumer-specific behavior into Transit or require a server-side truth table. | Validate during voyage implementation and keep the published API generic. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| How much checkpoint or revision vocabulary belongs in the upstream helper before it starts leaking consumer-specific projection policy? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Downstream Rust repos can derive projection views from hosted Transit through `transit-client` without a repo-local projection-read wrapper.
- [ ] The published API keeps projection reads replay-driven and leaves consumer schema ownership outside Transit.
<!-- END SUCCESS_CRITERIA -->
