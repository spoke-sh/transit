---
# system-managed
id: VHRRILABF
status: in-progress
created_at: 2026-04-21T08:57:07
updated_at: 2026-04-21T08:58:11
# authored
title: Add Single-Stream Batch Append To Shared Engine And Hosted Protocol
type: feat
operator-signal:
scope: VHRQnhLcW/VHRR4L3Dx
index: 1
started_at: 2026-04-21T08:58:11
---

# Add Single-Stream Batch Append To Shared Engine And Hosted Protocol

## Summary

Add the shared-engine batch append primitive and hosted protocol wiring for one
stream so a single request can append multiple payloads atomically while
preserving ordinary Transit record ordering, offsets, and replay semantics.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] `LocalEngine` publishes a single-stream batch append path that commits `N` payloads as ordered contiguous records and returns batch acknowledgement metadata. <!-- verify: cargo test -p transit-core append_batch_ -- --nocapture, SRS-01:start:end -->
- [ ] [SRS-02/AC-02] The hosted protocol exposes `AppendBatch` / `AppendBatchOk` and returns one acknowledgement for the whole batch. <!-- verify: cargo test -p transit-core remote_batch_append_ -- --nocapture, SRS-02:start:end -->
- [ ] [SRS-03/AC-03] Empty batches and batches above the configured count/byte limits fail through the normal hosted invalid-request path. <!-- verify: cargo test -p transit-core remote_batch_append_limits_ -- --nocapture, SRS-03:start:end -->
- [ ] [SRS-NFR-01/AC-04] Replay and tail still observe ordinary individual records after a successful batch append. <!-- verify: cargo test -p transit-core append_batch_ -- --nocapture, SRS-NFR-01:start:end -->
