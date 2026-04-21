---
# system-managed
id: VHRRILIBH
status: backlog
created_at: 2026-04-21T08:57:07
updated_at: 2026-04-21T08:57:52
# authored
title: Expose Hosted Batch Append Through Rust Client And CLI
type: feat
operator-signal:
scope: VHRQnhLcW/VHRR4L3Dx
index: 2
---

# Expose Hosted Batch Append Through Rust Client And CLI

## Summary

Publish the hosted batch append capability through `transit-client` and the CLI
so downstream Rust producers and operator-facing workflows can use the new
protocol path without hand-authoring raw protocol messages.

## Acceptance Criteria

- [ ] [SRS-04/AC-01] `TransitClient` exposes `append_batch(...)` and preserves the normal `RemoteAcknowledged<_>` envelope and hosted error surface. <!-- verify: cargo test -p transit-client batch_append_ -- --nocapture, SRS-04:start:end -->
- [ ] [SRS-04/AC-02] The CLI remote append surface accepts multiple payload values for one stream and reports batch acknowledgement metadata in human and JSON output. <!-- verify: cargo test -p transit-cli remote_cli_batch_append_ -- --nocapture, SRS-04:start:end -->
- [ ] [SRS-NFR-02/AC-03] The Rust client and CLI remain thin wrappers over the hosted protocol instead of inventing a private batching dialect. <!-- verify: manual, SRS-NFR-02:start:end -->
