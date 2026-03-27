---
# system-managed
id: VEz8XrwHS
status: done
created_at: 2026-03-26T07:49:16
updated_at: 2026-03-26T23:53:27
# authored
title: Add Tail Session Support To Rust Client
type: feat
operator-signal:
scope: VEz2iOasp/VEz3VaL0a
index: 1
started_at: 2026-03-26T23:51:25
completed_at: 2026-03-26T23:53:27
---

# Add Tail Session Support To Rust Client

## Summary

Extend the Rust client at `crates/transit-client/src/client.rs` with tail session support including `tail_open()`, `poll()`, `grant_credit()`, and `cancel()` operations that match the server's credit-based delivery model.

## Acceptance Criteria

- [x] [SRS-01/AC-01] `TransitClient::tail_open()` opens a tail session with a starting offset and initial credit. <!-- [SRS-01/AC-01] verify: cargo test -p transit-client tail_ -- --nocapture, SRS-01:start:end, proof: ac-1.log -->
- [x] [SRS-01/AC-02] The tail session supports `poll()` to receive records, `grant_credit()` to extend, and `cancel()` to close. <!-- [SRS-01/AC-02] verify: cargo test -p transit-client tail_ -- --nocapture, SRS-01:start:end, proof: ac-2.log -->
- [x] [SRS-02/AC-01] Server errors and backpressure details during tail sessions are surfaced to the caller without silent swallowing. <!-- [SRS-02/AC-01] verify: cargo test -p transit-client tail_ -- --nocapture, SRS-02:start:end, proof: ac-3.log -->
