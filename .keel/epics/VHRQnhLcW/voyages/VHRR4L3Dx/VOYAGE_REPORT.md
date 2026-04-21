# VOYAGE REPORT: Deliver Hosted Batch Append Surface

## Voyage Metadata
- **ID:** VHRR4L3Dx
- **Epic:** VHRQnhLcW
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 3/3 stories complete

## Implementation Narrative
### Add Single-Stream Batch Append To Shared Engine And Hosted Protocol
- **ID:** VHRRILABF
- **Status:** done

#### Summary
Add the shared-engine batch append primitive and hosted protocol wiring for one
stream so a single request can append multiple payloads atomically while
preserving ordinary Transit record ordering, offsets, and replay semantics.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] `LocalEngine` publishes a single-stream batch append path that commits `N` payloads as ordered contiguous records and returns batch acknowledgement metadata. <!-- verify: cargo test -p transit-core append_batch_ -- --nocapture, SRS-01:start:end -->
- [x] [SRS-02/AC-02] The hosted protocol exposes `AppendBatch` / `AppendBatchOk` and returns one acknowledgement for the whole batch. <!-- verify: cargo test -p transit-core remote_batch_append_ -- --nocapture, SRS-02:start:end -->
- [x] [SRS-03/AC-03] Empty batches and batches above the configured count/byte limits fail through the normal hosted invalid-request path. <!-- verify: cargo test -p transit-core remote_batch_append_limits_ -- --nocapture, SRS-03:start:end -->
- [x] [SRS-NFR-01/AC-04] Replay and tail still observe ordinary individual records after a successful batch append. <!-- verify: cargo test -p transit-core append_batch_ -- --nocapture, SRS-NFR-01:start:end -->

### Expose Hosted Batch Append Through Rust Client And CLI
- **ID:** VHRRILIBH
- **Status:** done

#### Summary
Publish the hosted batch append capability through `transit-client` and the CLI
so downstream Rust producers and operator-facing workflows can use the new
protocol path without hand-authoring raw protocol messages.

#### Acceptance Criteria
- [x] [SRS-04/AC-01] `TransitClient` exposes `append_batch(...)` and preserves the normal `RemoteAcknowledged<_>` envelope and hosted error surface. <!-- verify: cargo test -p transit-client batch_append_ -- --nocapture, SRS-04:start:end -->
- [x] [SRS-04/AC-02] The CLI remote append surface accepts multiple payload values for one stream and reports batch acknowledgement metadata in human and JSON output. <!-- verify: cargo test -p transit-cli remote_cli_batch_append_ -- --nocapture, SRS-04:start:end -->
- [x] [SRS-NFR-02/AC-03] The Rust client and CLI remain thin wrappers over the hosted protocol instead of inventing a private batching dialect. <!-- verify: manual, SRS-NFR-02:start:end -->

### Publish Proof And Limit Guidance For Hosted Batch Append
- **ID:** VHRRILqCd
- **Status:** done

#### Summary
Publish the proof and downstream-facing guidance needed to make hosted batch
append a usable contract, including CLI-visible evidence and explicit guidance
for supported limit failures.

#### Acceptance Criteria
- [x] [SRS-05/AC-01] A CLI-facing proof or targeted test flow demonstrates hosted batch append through the published operator surface. <!-- verify: cargo test -p transit-cli remote_cli_batch_append_ -- --nocapture, SRS-05:start:end -->
- [x] [SRS-05/AC-02] The downstream-facing Rust client or CLI docs publish the supported batch limits and failure behavior explicitly. <!-- verify: manual, SRS-05:start:end -->
- [x] [SRS-NFR-03/AC-03] The evidence set covers happy-path batching plus explicit limit failures across the core, protocol, client, and CLI seams touched by the feature. <!-- verify: cargo test -p transit-core append_batch_ -- --nocapture && cargo test -p transit-core remote_batch_append_ -- --nocapture && cargo test -p transit-core remote_batch_append_limits_ -- --nocapture && cargo test -p transit-client batch_append_ -- --nocapture && cargo test -p transit-cli remote_cli_batch_append_ -- --nocapture, SRS-NFR-03:start:end -->


