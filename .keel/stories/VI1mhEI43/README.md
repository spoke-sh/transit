---
# system-managed
id: VI1mhEI43
status: done
created_at: 2026-04-27T14:07:56
updated_at: 2026-04-27T14:22:39
# authored
title: Add Range Replay And Tail Pagination To Shared Engine
type: feat
operator-signal:
scope: VI1mae3rd/VI1meNvzJ
index: 1
started_at: 2026-04-27T14:16:14
completed_at: 2026-04-27T14:22:39
---

# Add Range Replay And Tail Pagination To Shared Engine

## Summary

Add a bounded replay and tail pagination primitive to the shared engine, then expose it through hosted protocol and Rust client surfaces without changing logical stream order or acknowledgement semantics.

## Acceptance Criteria

- [x] [SRS-01/AC-01] `LocalEngine` exposes a bounded replay or tail API that accepts a stream id, start offset, and max record count, and returns logical stream records plus enough metadata to continue paging. <!-- [SRS-01/AC-01] verify: cargo test -p transit-core replay_page -- --nocapture, SRS-01:start, SRS-01:end, proof: ac-1.log-->
- [x] [SRS-02/AC-01] The hosted protocol and `transit-client` expose the same bounded read behavior while preserving request id, acknowledgement durability, topology, and remote error semantics. <!-- [SRS-02/AC-01] verify: cargo test -p transit-core remote_append_read_and_tail_preserve_positions_and_branch_aware_replay_behavior -- --nocapture && cargo test -p transit-client hosted_authority_exposes_bounded_read_pages -- --nocapture, SRS-02:start, SRS-02:end, proof: ac-2.log-->
- [x] [SRS-NFR-01/AC-01] Tests cover bounded reads over active head, rolled segments, branch-inherited history, and restored history without requiring callers to receive the complete stream. <!-- [SRS-NFR-01/AC-01] verify: cargo test -p transit-core replay_page -- --nocapture && cargo test -p transit-client hosted_authority_exposes_bounded_read_pages -- --nocapture, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log-->
