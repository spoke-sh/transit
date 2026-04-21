# Deliver Hosted Batch Append Surface - SRS

## Summary

Epic: VHRQnhLcW
Goal: Add single-stream batch append across the hosted protocol, server, Rust client, and CLI so downstream producers can amortize remote append overhead while preserving ordinary Transit record semantics.

## Scope

### In Scope

- [SCOPE-01] A single-stream batch append path in the shared engine and hosted server protocol, including batch acknowledgement metadata.
- [SCOPE-02] Explicit record-count and byte-limit enforcement for hosted batch append requests.
- [SCOPE-03] `transit-client` and CLI surfaces that expose hosted batch append without raw protocol access.
- [SCOPE-04] Targeted automated coverage and CLI-facing proof/test coverage for successful batching and limit failures.

### Out of Scope

- [SCOPE-05] Multi-stream transactions or cross-stream atomicity.
- [SCOPE-06] A streaming producer protocol or long-lived producer transport session.
- [SCOPE-07] Any change to replay, tail, checkpoint, or materialization semantics away from individual Transit records.
- [SCOPE-08] Consumer-specific batching envelopes above the Transit record boundary.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Implement a shared-engine batch append primitive for one stream that persists `N` payloads atomically as ordinary records, preserving exact submission order and contiguous offsets. | SCOPE-01 | FR-02 | story: VHRRILABF |
| SRS-02 | Extend the hosted protocol with a batch append request/response that returns first position, last position, record count, manifest generation, and rolled segment metadata for one batch. | SCOPE-01 | FR-01 | story: VHRRILABF |
| SRS-03 | Enforce explicit hosted batch limits for record count and total bytes, and surface limit failures through the normal hosted error envelope. | SCOPE-02 | FR-04 | story: VHRRILABF |
| SRS-04 | Publish batch append through `TransitClient` and the CLI so downstream Rust producers and operator-facing workflows can append multiple payloads to one stream without raw protocol access. | SCOPE-03 | FR-03 | story: VHRRILIBH |
| SRS-05 | Publish CLI-visible proof/test coverage and downstream-facing guidance for successful hosted batch append and supported limit failures. | SCOPE-04 | FR-04 | story: VHRRILqCd |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Hosted batching must preserve ordinary Transit semantics: read, tail, checkpoints, and downstream materialization continue to observe individual records rather than opaque batch envelopes. | SCOPE-01 | NFR-01 | story: VHRRILABF |
| SRS-NFR-02 | The implementation must remain shared-engine-first and avoid creating a client-only or server-only semantic path for batching. | SCOPE-01 | NFR-02 | story: VHRRILIBH |
| SRS-NFR-03 | The feature must ship with targeted coverage for happy-path batching plus explicit limit/failure behavior, and with CLI-visible evidence for the supported operator surface. | SCOPE-04 | NFR-03 | story: VHRRILqCd |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
