---
# system-managed
id: VEz8Y3TQE
status: backlog
created_at: 2026-03-26T07:49:16
updated_at: 2026-03-26T08:06:55
# authored
title: Add Lineage Inspection To Rust Client
type: feat
operator-signal:
scope: VEz2iOasp/VEz3VaL0a
index: 2
---

# Add Lineage Inspection To Rust Client

## Summary

Extend the Rust client with `lineage()` method for inspecting stream lineage (branch/merge DAG). The existing `create_merge()` method is already implemented in `crates/transit-client`; this story adds the inspection side.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] `TransitClient::lineage()` returns the lineage DAG for a stream including branch and merge relationships. <!-- [SRS-03/AC-01] verify: cargo test -p transit-client lineage_, SRS-03:start:end -->
- [ ] [SRS-04/AC-01] The client surfaces server acknowledgement and error envelopes for lineage operations without reinterpreting them. <!-- [SRS-04/AC-01] verify: code review + cargo test -p transit-client lineage_, SRS-04:start:end -->
