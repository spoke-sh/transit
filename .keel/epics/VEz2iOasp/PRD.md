# Client Libraries For External Server Access - Product Requirements

## Problem Statement

Transit has a working networked server but no client libraries for external consumers. Without at least a Python client, external users cannot exercise append, branch, tail, and lineage operations programmatically against a running transit server.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Deliver a Python client library that wraps the transit server protocol for append, read, tail, branch, merge, and lineage inspection. | Python client exercises all core operations against a running server | Python client voyage completed |
| GOAL-02 | Prove the client library works end-to-end through a dedicated proof path. | Client proof script exercises the full operation set and produces pass/fail evidence | Client proof story accepted |
| GOAL-03 | Keep the client as a thin protocol wrapper without introducing a second storage or lineage model. | Client delegates all semantics to the server; no local engine logic | Thin-wrapper constraint verified |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Application Builder | The engineer integrating transit into Python-based agent runtimes, model harnesses, or communication systems. | A usable client that maps transit operations to familiar Python idioms. |
| Core Transit Maintainer | The engineer proving that the server protocol is externally consumable. | A client that validates the wire contract from the consumer side. |
| Operator | The human proving external access through a proof script. | A runnable proof that the server is usable beyond the Rust CLI. |

## Scope

### In Scope

- [SCOPE-01] A Python client library covering append, read, tail, branch, merge, and lineage inspection operations against a running transit server.
- [SCOPE-02] A proof script that exercises the client end-to-end against a local server instance.
- [SCOPE-03] Client error handling that surfaces server acknowledgement, error, and backpressure semantics.

### Out of Scope

- [SCOPE-04] Client libraries for languages beyond Python in this epic.
- [SCOPE-05] Client-side storage, caching, or local engine embedding.
- [SCOPE-06] Authentication, authorization, or multi-tenant client configuration.
- [SCOPE-07] Publishing the client to PyPI or any package registry.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Implement a Python client that can create streams, append records, and read back acknowledged records from a running transit server. | GOAL-01 | must | Append and read are the foundational operations for any client. |
| FR-02 | Implement tail session support in the Python client with explicit lifecycle and backpressure handling. | GOAL-01 | must | Tail is a core transit operation and must be available to external consumers. |
| FR-03 | Implement branch creation, merge, and lineage inspection in the Python client. | GOAL-01 | must | Branch and lineage operations are product primitives that define transit's value. |
| FR-04 | Deliver a proof script that exercises all client operations against a locally started server and produces pass/fail output. | GOAL-02 | must | The proof script is the verification surface for client correctness. |
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
| Core operations | Proof script exercising append, read, tail, branch, merge, lineage | Story-level verification artifacts |
| Error handling | Proof script exercising error and backpressure scenarios | Accepted story evidence |
| Thin wrapper | Code review confirming no local engine logic in client | Accepted story evidence |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The transit server wire protocol is stable enough for a client library without frequent breaking changes. | Client may need rework as the protocol evolves. | Re-check during voyage planning. |
| Python is the highest-value first client language given the AI and agent workload focus. | A different language may be needed first. | Validate with user during planning. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should the Python client use async IO or synchronous sockets for the first version? | Epic owner | Open |
| How should the client handle tail session reconnection for the first version? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] A Python client library covers append, read, tail, branch, merge, and lineage inspection.
- [ ] A proof script exercises the client end-to-end against a local transit server.
- [ ] The client is a thin protocol wrapper with no local engine logic.
<!-- END SUCCESS_CRITERIA -->
