# Rust Client For External Server Access - Product Requirements

## Problem Statement

Transit has a working networked server but no Rust client crate for external consumers. Without a native Rust client, external users cannot exercise append, branch, tail, and lineage operations programmatically against a running transit server without dropping to the CLI.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Deliver a Rust client crate that wraps the transit server protocol for append, read, tail, branch, merge, and lineage inspection. | Rust client exercises all core operations against a running server | Rust client voyage completed |
| GOAL-02 | Prove the client library works end-to-end through a dedicated proof path. | Client proof script exercises the full operation set and produces pass/fail evidence | Client proof story accepted |
| GOAL-03 | Keep the client as a thin protocol wrapper without introducing a second storage or lineage model. | Client delegates all semantics to the server; no local engine logic | Thin-wrapper constraint verified |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Application Builder | The engineer integrating transit into Rust services, embedded tooling, or agent runtimes. | A usable client that maps transit operations to idiomatic Rust APIs. |
| Core Transit Maintainer | The engineer proving that the server protocol is externally consumable. | A client that validates the wire contract from the consumer side. |
| Operator | The human proving external access through a proof example or binary. | A runnable proof that the server is usable beyond the Rust CLI. |

## Scope

### In Scope

- [SCOPE-01] A Rust client crate covering append, read, tail, branch, merge, and lineage inspection operations against a running transit server.
- [SCOPE-02] A proof example or binary that exercises the client end-to-end against a local server instance.
- [SCOPE-03] Client error handling that surfaces server acknowledgement, error, and backpressure semantics.

### Out of Scope

- [SCOPE-04] Client libraries for languages beyond Rust in this epic.
- [SCOPE-05] Client-side storage, caching, or local engine embedding.
- [SCOPE-06] Authentication, authorization, or multi-tenant client configuration.
- [SCOPE-07] Publishing the client to crates.io or any package registry.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Implement a Rust client that can create streams, append records, and read back acknowledged records from a running transit server. | GOAL-01 | must | Append and read are the foundational operations for any client. |
| FR-02 | Implement tail session support in the Rust client with explicit lifecycle and backpressure handling. | GOAL-01 | must | Tail is a core transit operation and must be available to external consumers. |
| FR-03 | Implement branch creation, merge, and lineage inspection in the Rust client. | GOAL-01 | must | Branch and lineage operations are product primitives that define transit's value. |
| FR-04 | Deliver a proof example or binary that exercises all client operations against a locally started server and produces pass/fail output. | GOAL-02 | must | The proof path is the verification surface for client correctness. |
| FR-05 | Keep the client as a thin protocol wrapper that delegates all storage and lineage semantics to the server. | GOAL-03 | must | The client must not reimplement engine behavior. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | The client must surface server acknowledgement and error envelopes without hiding or reinterpreting them. | GOAL-01, GOAL-03 | must | Operators need to see what the server actually committed. |
| NFR-02 | The client proof must be runnable from the repo without external service dependencies. | GOAL-02 | must | Proof reproducibility is a project constraint. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Core operations | Proof example exercising append, read, tail, branch, merge, lineage | Story-level verification artifacts |
| Error handling | Proof example exercising error and backpressure scenarios | Accepted story evidence |
| Thin wrapper | Code review confirming no local engine logic in client | Accepted story evidence |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The transit server wire protocol is stable enough for a client library without frequent breaking changes. | Client may need rework as the protocol evolves. | Re-check during voyage planning. |
| Rust is the highest-value first client language while the product is still converging on shared-engine and wire-contract semantics. | A different language may be needed first. | Validate with user during planning. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should the Rust client expose a blocking API first, an async API first, or both from the start? | Epic owner | Open |
| How should the client handle tail session reconnection for the first version? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] A Rust client crate covers append, read, tail, branch, merge, and lineage inspection.
- [ ] A proof example exercises the client end-to-end against a local transit server.
- [ ] The client is a thin protocol wrapper with no local engine logic.
<!-- END SUCCESS_CRITERIA -->
