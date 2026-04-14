# Publish Hosted Consumer Interface For Spoke Cutover - Product Requirements

## Problem Statement

Spoke still carries a duplicate transit-server runtime and a private hosted Transit client contract. The authoritative hosted consumer interface should live in Transit so downstream repos can consume one canonical endpoint/auth/acknowledgement surface and cut directly off duplicate local ownership.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Transit owns the canonical hosted consumer endpoint contract for downstream adopters such as Spoke. | Endpoint, auth, acknowledgement, and error semantics are authored upstream instead of drifting into repo-local protocol surfaces. | Voyage `VGj3HXPMa` completed |
| GOAL-02 | Transit publishes the reusable client and direct-cutover proof surface that lets Spoke replace its duplicate runtime and private hosted client semantics without transitionary debt. | Spoke has an explicit upstream contract to consume and a documented direct-cutover path for deleting duplicate local ownership. | Voyage `VGj3HWSL4` completed |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Downstream integrator | Engineer maintaining Spoke or another consumer that currently carries local hosted Transit glue. | One canonical upstream contract to consume instead of defining a second client/server surface locally. |
| Transit maintainer | Engineer evolving hosted Transit semantics. | A clear place to author endpoint, auth, acknowledgement, and client behavior without relying on downstream forks. |

## Scope

### In Scope

- [SCOPE-01] Author the hosted consumer endpoint, auth, acknowledgement, and
  error contract in the Transit reactor.
- [SCOPE-02] Define the reusable upstream client surface that downstream repos
  should consume for hosted append, replay, branch, and related operations.
- [SCOPE-03] Publish the direct-cutover proof path for replacing Spoke's
  duplicate local runtime/client surface with the upstream contract.

### Out of Scope

- [SCOPE-04] Spoke-side implementation work that actually swaps its callsites
  onto the new upstream surface.
- [SCOPE-05] Consumer-owned schema, policy, or business semantics above the
  hosted Transit substrate.
- [SCOPE-06] Infra rollout plumbing beyond the interface and proof contract
  needed by downstream consumers.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Transit must define the canonical hosted consumer endpoint contract, including endpoint shape, auth posture, acknowledgement semantics, and error surfaces. | GOAL-01 | must | Downstream repos cannot cut over cleanly if the authoritative contract is still implicit. |
| FR-02 | Transit must define the reusable upstream client surface that downstream repos such as Spoke should consume for hosted operations. | GOAL-02 | must | A downstream cutover needs an importable client boundary, not just prose. |
| FR-03 | Transit must define the direct cutover proof path for downstream duplicate runtimes or local hosted clients. | GOAL-02 | should | Downstream repos need an inspectable path to remove duplicate local ownership without carrying transitional interface debt forward. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | The hosted consumer interface must stay generic and reusable; it must not absorb Spoke-specific schema or business policy. | GOAL-01, GOAL-02 | must | Transit owns substrate semantics, not consumer meaning. |
| NFR-02 | Contract evolution and replacement posture must be explicit so downstream repos do not fork endpoint or client semantics again. | GOAL-01, GOAL-02 | must | Hidden transition rules recreate the duplicate-runtime problem. |
| NFR-03 | The upstream cutover path must remain inspectable through docs, tests, or proof artifacts that downstream repos can cite during direct replacement. | GOAL-02 | must | Cross-repo migrations fail when the proof surface lives only in chat. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Hosted consumer endpoint contract | Planning review plus contract and proof authoring | Voyage `VGj3HXPMa` artifacts |
| Upstream client and direct cutover path | Planning review plus cutover-proof authoring | Voyage `VGj3HWSL4` artifacts |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Spoke's local `crates/transit-server` and `spoke-core::messaging::TransitClient` are duplicate ownership to replace rather than an intentional long-term fork. | The epic could optimize away a path the platform still intends to keep. | Validate against the current Spoke mission artifacts and architecture docs. |
| The existing Transit hosted-authority work provides enough substrate vocabulary to define the upstream consumer contract without reopening the generic authority mission. | This follow-on could duplicate or contradict already-finished mission work. | Re-check against mission `VGh598Oz0` artifacts before implementation. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should the hosted consumer interface extend the current `transit-client` surface directly or live in a more explicit hosted-consumer layer above it? | Epic owner | Open |
| Which single canonical hosted consumer posture should the direct cutover target first? | Epic owner | Open |
| How much auth configuration belongs in the client crate versus a server/runtime contract consumed by downstream repos and Infra? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Transit owns the hosted consumer endpoint contract instead of leaving it in downstream repos.
- [ ] Transit publishes a reusable client boundary for downstream hosted consumers.
- [ ] Spoke has an explicit upstream direct-cutover path for deleting its duplicate local runtime and hosted client semantics.
<!-- END SUCCESS_CRITERIA -->
