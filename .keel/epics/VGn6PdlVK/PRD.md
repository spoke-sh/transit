# Hosted Tiered Server Runtime - Product Requirements

## Problem Statement

Transit already publishes a hosted consumer contract and tiered/object-store
architecture, but the shipped server bootstrap still exits on non-local
durability and does not resolve real object-store providers from config.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Hosted Transit can resolve authored object-store providers and boot in a tiered runtime shape. | `transit server run` accepts tiered/object-store config and starts without falling back to a local-only claim. | Voyage `VGn6xmmDh` completed |
| GOAL-02 | Hosted acknowledgements, storage probe output, and recovery proofs stay honest about the guarantees the runtime actually satisfies. | Server and proof surfaces expose explicit durability and non-claim boundaries that match the real runtime path. | Voyage `VGn6z2GXx` completed |
| GOAL-03 | Downstream repos have one upstream runtime and client surface they can adopt for a clean cutover. | The canonical runtime, endpoint grammar, and client guidance live upstream and remove the need for downstream private hosted adapters. | Voyage `VGn6zxceG` completed |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Transit operator | Engineer running hosted Transit for downstream workloads. | Authored object-store config that boots predictably and exposes honest runtime guarantees. |
| Downstream integrator | Engineer cutting a consumer repo over to hosted Transit. | One canonical upstream runtime and client surface instead of a private duplicate protocol. |
| Platform maintainer | Engineer proving durability and recovery claims across environments. | Clear evidence that tiered/object-store claims match actual runtime behavior. |

## Scope

### In Scope

- [SCOPE-01] Runtime object-store provider resolution from authored config for
  hosted server bootstrap.
- [SCOPE-02] Hosted server behavior and proof surfaces for tiered durability,
  recovery, and explicit non-claims.
- [SCOPE-03] Upstream documentation and client/runtime guidance needed for
  downstream direct cutover.

### Out of Scope

- [SCOPE-04] Consumer-owned schema, identity, or business-policy semantics.
- [SCOPE-05] Infra rollout plumbing owned outside the Transit reactor.
- [SCOPE-06] Preserving or extending downstream private hosted protocols as a
  long-term compatibility lane.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Transit must resolve the configured storage provider into a real object-store client that hosted runtime surfaces can use. | GOAL-01 | must | Authored object-store config is meaningless unless the runtime can instantiate it. |
| FR-02 | `transit server run` must support hosted tiered runtime bootstrap instead of exiting on non-local durability from config. | GOAL-01 | must | Downstream repos cannot cut over to the upstream server until the runtime path exists. |
| FR-03 | Transit must publish honest storage-probe, acknowledgement, and recovery semantics for hosted object-store-backed operation. | GOAL-02 | must | Operators and downstream consumers need contract data they can trust. |
| FR-04 | Transit must preserve one canonical downstream adoption path through the upstream client and runtime surface. | GOAL-03 | must | A clean cutover fails if downstream repos still need private adapter knowledge. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Hosted runtime claims must remain explicit and honest; the runtime must not report stronger durability or auth guarantees than the implemented path proves. | GOAL-01, GOAL-02 | must | Overclaimed substrate guarantees create unsafe downstream assumptions. |
| NFR-02 | Object-store-backed runtime support must preserve warm-cache replaceability and authoritative remote recovery. | GOAL-01, GOAL-02 | must | Tiered architecture breaks if local cache silently becomes the durable source of truth. |
| NFR-03 | Published cutover guidance must remain generic and reusable for any downstream consumer. | GOAL-03 | must | Transit owns substrate semantics, not a single consumer's migration lore. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Object-store runtime bootstrap | Runtime tests and CLI verification of authored config resolution | Voyage `VGn6xmmDh` artifacts |
| Tiered guarantee honesty | Storage probe checks plus warm-cache recovery proofs | Voyage `VGn6z2GXx` artifacts |
| Downstream cutover surface | Contract review and cutover-facing docs/tests | Voyage `VGn6zxceG` artifacts |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The shared engine and hosted protocol already contain enough substrate primitives to support a true hosted tiered runtime without defining a second server contract. | The mission could devolve into another interface rewrite instead of a runtime completion slice. | Validate against the current `transit-core`, `transit-cli`, and `transit-client` seams before implementation. |
| Downstream repos are prepared to delete private hosted adapters once this runtime and contract work lands upstream. | Transit could ship a better surface while duplicate downstream protocol ownership persists. | Keep the direct-cutover requirement explicit throughout the mission. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Provider builders for `s3`, `gcs`, and `azure` may require feature or credential-shape work beyond the current filesystem proofs. | Epic owner | Open |
| Hosted tiered append semantics may need runtime plumbing beyond bootstrap alone so `ack.durability = tiered` remains truthful. | Epic owner | Open |
| Downstream consumers may still carry HTTP-shaped validation or test harness assumptions that no longer match the upstream socket endpoint contract. | Mission stack | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] `transit server run` boots with authored object-store-backed tiered config instead of rejecting it.
- [ ] Hosted proofs and probes make authoritative remote recovery and runtime non-claims explicit.
- [ ] Downstream repos have one upstream runtime and client surface they can consume for a direct cutover.
<!-- END SUCCESS_CRITERIA -->
