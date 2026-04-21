---
# system-managed
id: VHRRILqCd
status: done
created_at: 2026-04-21T08:57:07
updated_at: 2026-04-21T09:16:26
# authored
title: Publish Proof And Limit Guidance For Hosted Batch Append
type: feat
operator-signal:
scope: VHRQnhLcW/VHRR4L3Dx
index: 3
started_at: 2026-04-21T09:15:20
submitted_at: 2026-04-21T09:16:20
completed_at: 2026-04-21T09:16:26
---

# Publish Proof And Limit Guidance For Hosted Batch Append

## Summary

Publish the proof and downstream-facing guidance needed to make hosted batch
append a usable contract, including CLI-visible evidence and explicit guidance
for supported limit failures.

## Acceptance Criteria

- [x] [SRS-05/AC-01] A CLI-facing proof or targeted test flow demonstrates hosted batch append through the published operator surface. <!-- verify: cargo test -p transit-cli remote_cli_batch_append_ -- --nocapture, SRS-05:start:end -->
- [x] [SRS-05/AC-02] The downstream-facing Rust client or CLI docs publish the supported batch limits and failure behavior explicitly. <!-- verify: manual, SRS-05:start:end -->
- [x] [SRS-NFR-03/AC-03] The evidence set covers happy-path batching plus explicit limit failures across the core, protocol, client, and CLI seams touched by the feature. <!-- verify: cargo test -p transit-core append_batch_ -- --nocapture && cargo test -p transit-core remote_batch_append_ -- --nocapture && cargo test -p transit-core remote_batch_append_limits_ -- --nocapture && cargo test -p transit-client batch_append_ -- --nocapture && cargo test -p transit-cli remote_cli_batch_append_ -- --nocapture, SRS-NFR-03:start:end -->
