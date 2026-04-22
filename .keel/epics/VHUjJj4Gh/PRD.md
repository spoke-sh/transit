# Object-Store-Native Published Manifests And Frontier Discovery - Product Requirements

## Problem Statement

Transit currently models published state differently on local disk and remote object storage, with filesystem-first manifest handling instead of one object-store-native authority model. We need immutable manifest snapshots plus a small mutable frontier pointer so published segments, manifests, and latest-state discovery use the same semantics through the object_store crate while leaving the hot active head local and append-oriented.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Give Transit one published-storage authority model for local filesystem and remote object storage. | Published segments, manifests, and latest discovery use one object-store-native contract across both backends. | No backend-specific published-state semantic split remains in design or implementation. |
| GOAL-02 | Preserve the append-oriented working plane while moving published state onto the object-store model. | Active-head append and local working-state flows remain outside the published object-store path. | No hot-path append regression or semantic rewrite is introduced. |
| GOAL-03 | Make latest published-state discovery explicit and reliable. | Operators and recovery code resolve the latest immutable manifest through a small frontier object rather than append semantics or backend-specific listing assumptions. | The latest published frontier can be discovered and verified from an explicit pointer object. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Transit Operator | Runs Transit in local or tiered deployments and needs predictable published-state recovery. | One clear authority model for sealed published history and latest discovery. |
| Downstream Integrator | Embeds Transit or talks to a server process and expects storage semantics to stay coherent across deployment shapes. | Shared published-state behavior independent of backend choice. |

## Scope

### In Scope

- [SCOPE-01] Define a two-plane storage contract: local mutable working state and object-store-native published authority.
- [SCOPE-02] Model immutable manifest snapshots and a small mutable published frontier pointer for latest discovery.
- [SCOPE-03] Align local filesystem published artifacts with the same object-store concepts used for remote publication.
- [SCOPE-04] Proof coverage and operator guidance for the new authority model.

### Out of Scope

- [SCOPE-05] Replacing the active head with an object-store append model.
- [SCOPE-06] Manifest delta logs, paged manifest trees, or other second-step scaling designs.
- [SCOPE-07] Global stream indexes or cross-stream discovery layers beyond per-stream frontier discovery.
- [SCOPE-08] Garbage collection policy for historical manifest snapshots beyond what current retention already governs.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Transit MUST define one published-storage authority model for filesystem and remote object-store backends based on immutable published artifacts. | GOAL-01 | must | Prevents local and remote deployments from drifting into separate semantic worlds. |
| FR-02 | Transit MUST distinguish the mutable working plane from the published authority plane and keep the hot append path local and append-oriented. | GOAL-02 | must | Preserves current write semantics while moving sealed history onto the object-store model. |
| FR-03 | Transit MUST represent latest published discovery through a small frontier object that points at the latest immutable manifest snapshot. | GOAL-03 | must | Gives recovery and operators one explicit latest-state discovery mechanism. |
| FR-04 | Transit MUST define publication ordering so immutable segments and immutable manifest snapshots become visible before the frontier pointer advances. | GOAL-01, GOAL-03 | must | Keeps published-state visibility crash-safe and backend-agnostic. |
| FR-05 | Transit MUST expose proof and operator documentation for the object-store-native authority model. | GOAL-01, GOAL-03 | should | The model needs a public proof path and operator explanation to be usable. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve append, replay, lineage, durability, and retention semantics across the new authority model. | GOAL-01, GOAL-02 | must | Storage authority changes must not silently rewrite Transit semantics. |
| NFR-02 | Keep immutable published artifacts overwrite-free except for the small frontier pointer object. | GOAL-01, GOAL-03 | must | Matches object-store strengths and avoids pretending append-to-object is available. |
| NFR-03 | Keep the authority boundary observable in proofs and public documentation. | GOAL-01, GOAL-03 | should | Operators need to understand what is mutable, what is immutable, and how latest discovery works. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Authority contract | Story-level authored planning review and implementation tests | Story contracts, SRS/SDD links, targeted implementation tests |
| Latest discovery | CLI proofs and recovery tests | Proof logs plus published frontier evidence |
| Operator guidance | Public docs review and proof output | Updated docs and proof commands linked in story evidence |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Local filesystem should model published authority the same way remote object storage does. | The design could preserve an unnecessary semantic split. | Validate through implementation and proof coverage that filesystem publication uses the same object-store concepts. |
| The active head should remain a local working-plane concern. | Forcing the hot append path through object-store abstractions could introduce the wrong write model. | Keep it explicit in requirements, design, and story boundaries. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Whether local replay should eventually consume committed history only through the published object namespace or continue to use local paths with equivalent descriptors. | Epic owner | Open |
| How aggressively old immutable manifest snapshots should be garbage-collected after frontier advancement or retention trimming. | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Published authority is defined as immutable segments plus immutable manifest snapshots plus a mutable published frontier pointer across filesystem and remote backends.
- [ ] The working plane remains explicitly local and append-oriented.
- [ ] The board lands proof and documentation that explain latest discovery and immutable-versus-mutable boundaries.
<!-- END SUCCESS_CRITERIA -->
