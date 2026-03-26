# Rust Client Library And Proof - SRS

## Summary

Epic: VEz2iOasp
Goal: Deliver a Rust client crate covering append, read, tail, branch, merge, and lineage inspection with an end-to-end proof example against a local server.

## Scope

### In Scope

- [SCOPE-01] A Rust client crate covering append, read, tail, branch, merge, and lineage inspection operations against a running transit server.
- [SCOPE-02] A proof example or binary that exercises the client end-to-end against a local server instance.
- [SCOPE-03] Client error handling that surfaces server acknowledgement, error, and backpressure semantics.

### Out of Scope

- [SCOPE-04] Client libraries for languages beyond Rust.
- [SCOPE-05] Client-side storage, caching, or local engine embedding.
- [SCOPE-06] Authentication, authorization, or multi-tenant configuration.
- [SCOPE-07] Publishing the client to crates.io or any package registry.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Implement `TransitClient::tail_open()` plus `poll()`, `grant_credit()`, and `cancel()` so the Rust client supports explicit tail lifecycle with credit-based delivery. | SCOPE-01 | FR-02 | test + proof |
| SRS-02 | Ensure tail session operations surface server acknowledgement, error, and backpressure envelopes without hiding or reinterpreting them. | SCOPE-03 | FR-05 | test + proof |
| SRS-03 | Implement `TransitClient::lineage()` so the Rust client can inspect the branch and merge DAG exposed by the server. | SCOPE-01 | FR-03 | test + proof |
| SRS-04 | Ensure lineage inspection surfaces server acknowledgement and error envelopes without hiding or reinterpreting them. | SCOPE-03 | FR-05 | test + proof |
| SRS-05 | Validate the existing `create_root()`, `append()`, `read()`, `create_branch()`, and `create_merge()` methods in `crates/transit-client` through an end-to-end proof against a local server. | SCOPE-01 | FR-01 | proof |
| SRS-06 | Deliver a proof example at `crates/transit-client/examples/proof.rs` that exercises tail and lineage in addition to the existing core operations, reports pass/fail per operation, and exits non-zero on failure. | SCOPE-02 | FR-04 | proof |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The client must be a thin protocol wrapper with no local engine logic. | SCOPE-01 | FR-05 | code review |
| SRS-NFR-02 | The proof example must be runnable from the repo without external service dependencies beyond a locally started transit server. | SCOPE-02 | NFR-02 | proof |
| SRS-NFR-03 | The client must not silently swallow server errors; acknowledgement status and error details must be accessible to the caller. | SCOPE-03 | NFR-01 | test |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
