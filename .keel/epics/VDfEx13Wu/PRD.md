# Shared-Engine Server Mode And Remote API - Product Requirements

## Problem Statement

Transit has a durable local engine, but it still lacks a networked server mode that exposes the same append, read, tail, branch, merge, and lineage semantics over a real client/server boundary without introducing replication or a second storage engine.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Deliver the first shared-engine server daemon for single-node `transit`. | Remote daemon workflow planned and implemented without a second engine | First server voyage completed |
| GOAL-02 | Define and implement the first server wire contract with explicit framing, acknowledgements, error semantics, and streaming tail lifecycle. | Wire contract and tail session model are planned, implemented, and verified | Protocol voyage completed |
| GOAL-03 | Preserve transport abstraction so deployment underlays such as WireGuard remain optional and do not replace the application protocol. | Transport boundary is explicit in docs, code shape, and mission proof | Transport boundary accepted |
| GOAL-04 | Keep the human-facing proof path meaningful as server mode becomes real. | `just mission` and CLI proof exercise the networked single-node server end to end | Mission verification upgraded |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Core Transit Maintainer | The engineer extending the verified local engine into the first server surface. | A traceable delivery plan for daemon lifecycle, remote semantics, and protocol boundaries. |
| Application Or Agent Runtime Builder | The engineer who wants to use `transit` across processes or hosts without embedding the engine directly everywhere. | A usable server mode that preserves append, branch, merge, and replay semantics over the network. |
| Operator | The human proving progress through CLI and `just mission`. | One trustworthy proof path for the first server deployment without hidden replication assumptions. |

## Scope

### In Scope

- [SCOPE-01] A single-node daemon that wraps the shared engine and exposes remote append, read, tail, branch, merge, and lineage inspection behavior.
- [SCOPE-02] The first request/response protocol surface with explicit framing, correlation, acknowledgements, errors, and streaming tail lifecycle.
- [SCOPE-03] CLI or client ergonomics sufficient to exercise the server remotely during mission proof.
- [SCOPE-04] Transport-boundary guidance that keeps WireGuard or other secure underlays optional rather than collapsing them into the application protocol.
- [SCOPE-05] A human-facing mission proof path that exercises the first networked server end to end.

### Out of Scope

- [SCOPE-06] Multi-node replication, consensus, leader election, or any distributed ownership protocol.
- [SCOPE-07] Public browser ingress, WebSocket surfaces, or end-user collaboration UX.
- [SCOPE-08] A second storage engine or server-only lineage semantics.
- [SCOPE-09] Full authentication, authorization, or multi-tenant policy design beyond what is minimally needed to run local or trusted-node proof flows.
- [SCOPE-10] Using WireGuard itself as the `transit` application protocol.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Implement a single-node server daemon that exposes remote append, read, tail, branch, merge, and lineage inspection operations on top of the shared engine. | GOAL-01 | must | The product needs a real networked server surface before replication work begins. |
| FR-02 | Implement the first server protocol contract with explicit request framing, correlation, acknowledgement, error, and streaming-tail session semantics. | GOAL-02 | must | Remote correctness depends on a clear application protocol, not implied socket behavior. |
| FR-03 | Implement CLI or client flows and mission proof coverage that exercise the server remotely. | GOAL-01, GOAL-04 | must | Human verification is a product constraint, not incidental tooling. |
| FR-04 | Keep transport underlay concerns explicit so deployment over WireGuard or other secure meshes does not replace `transit`'s own protocol semantics. | GOAL-02, GOAL-03 | should | The transport boundary needs to stay clear before server work ossifies. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve the one-engine thesis by keeping the server as a wrapper around the existing engine and storage semantics. | GOAL-01, GOAL-02 | must | Server mode cannot become a second database. |
| NFR-02 | Keep scope explicitly single-node and non-replicated for this epic. | GOAL-01, GOAL-03 | must | Replication must remain downstream of a proven server contract. |
| NFR-03 | Keep remote acknowledgement, durability, and error boundaries explicit in docs, code, and proof surfaces. | GOAL-02, GOAL-04 | must | Operators need to know what the server has actually committed. |
| NFR-04 | Keep the protocol transport-agnostic enough to run over generic transports while treating WireGuard as an optional secure underlay. | GOAL-02, GOAL-03 | must | The application protocol should not collapse into one deployment primitive. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Shared-engine daemon behavior | Targeted tests plus remote CLI proof flows | Story-level verification artifacts linked during execution |
| Remote lineage semantics | Focused correctness tests for append/read/tail, branch/merge, and lineage inspection | Accepted story evidence for core RPC slices |
| Protocol and session lifecycle | Protocol-level tests and proof notes for framing, acknowledgement, backpressure, and cancellation | Accepted story evidence for wire-contract slices |
| Operator proof path | `just mission`, CLI client flows, and board health | Accepted story evidence plus `keel doctor` |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The verified durable local engine is stable enough to serve as the foundation for the first networked server mode. | Server work may need foundational engine refactoring before meaningful progress. | Re-check during the first voyage. |
| The first useful server transport can remain single-node and trusted-network oriented without deciding full public ingress or replication strategy. | The mission may overreach into later protocol and operator concerns. | Validate during protocol-voyage planning. |
| A transport-agnostic protocol boundary can be defined before choosing long-term deployment defaults such as TCP, QUIC, or WireGuard underlay patterns. | The implementation could prematurely ossify around one transport. | Re-check during protocol and mission-proof stories. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Which transport should back the first server proof while keeping the protocol transport-agnostic? | Epic owner | Open |
| How much auth or operator policy needs to exist before the first server proof is responsible enough to run? | Epic owner | Open |
| What tail-session reconnect and resume semantics are necessary in the first remote streaming surface? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] The repo contains a planned and executable first server epic that wraps the shared engine instead of inventing server-only storage behavior.
- [ ] Remote append/read/tail, branch/merge, and lineage inspection are all represented as scoped voyage work rather than deferred slogans.
- [ ] The wire protocol boundary, CLI proof flow, and optional-underlay guidance remain part of the first networked server story.
<!-- END SUCCESS_CRITERIA -->

## Research Analysis

*From bearing assessments:*

### Findings

- Server mode should be the next step on top of the shared engine, while replication stays explicitly downstream of a proven single-node server contract.
- WireGuard is useful framing for deployment strategy, but it belongs as an optional secure underlay rather than the `transit` application protocol itself.

### Opportunity Cost

If server mode is delayed until replication design is settled, the project stays stuck proving only embedded usage and risks designing distributed semantics without a stable remote contract.

### Dependencies

- The durable local engine, manifest behavior, and explicit durability modes are prerequisites for credible server packaging.
- The remaining research mission continues to inform later replication and transport work, but it should not block this single-node server epic.

### Alternatives Considered

- Jump directly to replication, but that would dilute the now-proven local engine and blur the one-engine thesis.
- Treat WireGuard as the primary transport, but that would confuse secure underlay choices with application protocol semantics.
