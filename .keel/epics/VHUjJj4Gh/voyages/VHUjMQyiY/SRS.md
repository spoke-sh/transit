# Deliver Immutable Manifest Snapshots With Frontier Pointer - SRS

## Summary

Epic: VHUjJj4Gh
Goal: Make published Transit authority object-store-native for filesystem and remote backends by keeping sealed segments and manifest snapshots immutable, discovering the latest published state through a small mutable frontier pointer, and preserving local working-state append semantics.

## Scope

### In Scope

- [SCOPE-01] Define the authority split between the local working plane and the published object-store-native plane.
- [SCOPE-02] Define the immutable manifest snapshot and mutable frontier-pointer model.
- [SCOPE-03] Align filesystem-backed published artifacts with the same object-store namespace concepts used for remote publication.
- [SCOPE-04] Cover proof and documentation updates needed to explain and exercise the model.

### Out of Scope

- [SCOPE-05] Replacing the active head with an object-store-backed append surface.
- [SCOPE-06] Designing manifest deltas, paged manifest trees, or snapshot garbage collection beyond first-order requirements.
- [SCOPE-07] Adding cross-stream indexing beyond per-stream frontier discovery.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Transit MUST define a two-plane storage contract: a local mutable working plane for `active.segment` and `state.json`, and a published authority plane composed of immutable object-store-native artifacts. | SCOPE-01 | FR-02 | manual |
| SRS-02 | Transit MUST define one published namespace model for sealed segments, manifest snapshots, and frontier discovery that applies to both filesystem and remote object-store backends. | SCOPE-02, SCOPE-03 | FR-01 | manual |
| SRS-03 | Transit MUST define the published frontier object schema to include the stream identity and the latest immutable manifest discovery fields required for recovery and operator inspection. | SCOPE-02 | FR-03 | manual |
| SRS-04 | Transit MUST define publication ordering such that segments are durable before manifests and manifests are durable before the frontier pointer advances. | SCOPE-02, SCOPE-03 | FR-04 | manual |
| SRS-05 | Transit MUST define recovery and latest-discovery behavior against the frontier object and immutable manifest snapshots rather than append-to-object or backend-specific listing assumptions. | SCOPE-02, SCOPE-03 | FR-03 | manual |
| SRS-06 | Transit MUST provide proof and operator-facing guidance that demonstrates the object-store-native authority model and explains the mutable frontier boundary. | SCOPE-04 | FR-05 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The new authority model MUST preserve append, replay, lineage, durability, and retention semantics. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-01 | manual |
| SRS-NFR-02 | Immutable published artifacts MUST remain overwrite-free; only the small frontier pointer may be updated in place. | SCOPE-02, SCOPE-03 | NFR-02 | manual |
| SRS-NFR-03 | The hot append path MUST remain outside the published object-store path. | SCOPE-01 | NFR-01 | manual |
| SRS-NFR-04 | Proofs and public documentation MUST make the authority boundary and latest-discovery model explicit to operators. | SCOPE-04 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
