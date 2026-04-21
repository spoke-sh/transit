# Single-Stream Batch Append For Hosted Protocol - Product Requirements

## Problem Statement

Transit's hosted append surface is still record-at-a-time, which forces one RPC, acknowledgement, and JSON cycle per logical record for high-cardinality producers. Downstream Rust clients need a first-class single-stream batch append path that preserves per-record offsets, ordering, replay/tail semantics, and explicit batch limits without inventing application-level envelope batching above Transit.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Let downstream Rust producers append multiple payloads to one hosted Transit stream in one request while preserving ordinary per-record semantics. | Targeted protocol, client, and CLI coverage shows one batch request returns batch acknowledgement metadata and read/tail surfaces still observe individual records with deterministic contiguous offsets. | Voyage `VHRR4L3Dx` planned |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Downstream Rust Producer | Engineer running a separate `transit-server` process and writing many small records through `transit-client`. | A first-class upstream batch append path that reduces per-record transport overhead without packing multiple logical records into one payload. |
| Transit Maintainer | Engineer evolving the hosted protocol and CLI proof surface. | A batching feature that fits the shared engine, keeps semantics explicit, and remains testable through the existing hosted boundaries. |

## Scope

### In Scope

- [SCOPE-01] A hosted `AppendBatch` request/response path for a single stream, including batch acknowledgement metadata.
- [SCOPE-02] Server-side batch append semantics that preserve exact submission order, contiguous offsets, and all-or-nothing success for one stream.
- [SCOPE-03] `transit-client` and `transit` CLI support for batch append so downstream Rust users and proof flows do not need raw protocol access.
- [SCOPE-04] Explicit client/server record-count and byte limits plus documented failure behavior.
- [SCOPE-05] Targeted tests and CLI-proof coverage for successful batching and limit enforcement.

### Out of Scope

- [SCOPE-06] Multi-stream transactions or cross-stream atomicity.
- [SCOPE-07] A streaming producer protocol, long-lived producer session, or transport redesign beyond request/response batching.
- [SCOPE-08] Changing read, tail, checkpoint, or materialization semantics away from individual Transit records.
- [SCOPE-09] Consumer-specific envelope schemas above the Transit record boundary.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Add a hosted single-stream batch append request/response so one client request can carry `N` payloads and receive one batch acknowledgement with first position, last position, record count, manifest generation, and rolled segment metadata. | GOAL-01 | must | Downstream Rust producers need a first-class upstream batching contract instead of inventing opaque envelope batching. |
| FR-02 | The server must append batch payloads as `N` distinct records for one stream, preserving exact submission order, contiguous offsets, and atomic success/failure at the batch boundary. | GOAL-01 | must | Transit must retain per-record semantics and deterministic history even when transport overhead is amortized. |
| FR-03 | Publish the batch append capability through `transit-client` and the CLI so downstream Rust consumers and proof flows can use it without driving raw protocol messages. | GOAL-01 | must | The upstream client and CLI are the canonical hosted surfaces for downstream use and proofing. |
| FR-04 | Document and enforce explicit batch limits and failure behavior for record count and/or batch bytes across the hosted surface. | GOAL-01 | must | Operators and downstream clients need predictable limits instead of transport instability or implicit caps. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve ordinary Transit record semantics: replay, tail, checkpoints, and downstream materialization must continue to operate on individual records after a batch append. | GOAL-01 | must | Hosted batching must not create a second semantic world that hides logical records inside an opaque payload. |
| NFR-02 | Preserve the shared-engine and hosted-boundary model: batching must extend existing engine/protocol/client seams rather than introducing a private client-side batching dialect or server-only semantics. | GOAL-01 | must | Transit’s embedded and hosted modes must continue to share one storage and lineage model. |
| NFR-03 | The feature must ship with targeted automated coverage and a CLI-facing proof/test path for both success and limit failures. | GOAL-01 | must | This is a transport-sensitive change; the acceptance bar must stay evidence-backed and operator-visible. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Shared engine and hosted protocol semantics | Targeted tests for ordering, contiguous offsets, atomicity, and limit enforcement | Story-level evidence under the planned voyage |
| Rust client and CLI surface | Targeted tests plus CLI proof/test coverage for the batch path | Story-level evidence under the planned voyage |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The existing shared engine can support a batch append path without weakening per-record replay/tail semantics. | The epic could force a second semantic path or overscope into a protocol redesign. | Validate during voyage design and targeted implementation tests. |
| Explicit count/byte limits are sufficient for the first downstream producer workload without introducing a streaming producer protocol. | The epic could under-solve the remote instability problem or drift into a larger transport redesign. | Validate limits and failure behavior through targeted coverage and proof output. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| What default count and byte limits are safe for the current JSON-over-TCP request path while still materially reducing per-record overhead? | Epic owner | Open |
| Should the CLI expose batching through repeated `--payload-text` usage on the existing append command or a distinct batch-oriented command surface? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Downstream Rust clients can append multiple records to a single stream in one hosted request through an upstream-supported batch surface.
- [ ] Hosted read and tail flows still observe individual Transit records with deterministic ordering and contiguous positions after batch append.
- [ ] Batch count/byte limits and failure behavior are explicit, tested, and available through the CLI proof/test surface.
<!-- END SUCCESS_CRITERIA -->
