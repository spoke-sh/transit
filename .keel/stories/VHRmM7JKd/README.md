---
# system-managed
id: VHRmM7JKd
status: in-progress
created_at: 2026-04-21T10:20:47
updated_at: 2026-04-21T10:25:39
# authored
title: Add Configurable Hosted I/O Timeouts To Server And Client Surfaces
type: feat
operator-signal:
scope: VHRmIhDsm/VHRmIjGvL
index: 1
started_at: 2026-04-21T10:25:39
---

# Add Configurable Hosted I/O Timeouts To Server And Client Surfaces

## Summary

Add explicit timeout configuration hooks to the hosted server and Rust client
surfaces so downstream callers can raise connection I/O timeouts above the
current 1s default without changing request/response semantics.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] `ServerConfig` exposes a configurable per-connection I/O timeout while preserving the current explicit 1000ms default when callers do not override it. <!-- verify: cargo test -p transit-core hosted_timeout_config_server_ -- --nocapture, SRS-01:start:end -->
- [ ] [SRS-02/AC-02] `RemoteClient` and `TransitClient` expose configurable client-side I/O timeout while preserving the hosted acknowledgement and error envelopes literally. <!-- verify: cargo test -p transit-client hosted_timeout_config_client_ -- --nocapture, SRS-02:start:end -->
- [ ] [SRS-NFR-01/AC-03] The new timeout knobs remain transport/runtime configuration only and do not alter append, read, or tail semantics. <!-- verify: manual, SRS-NFR-01:start:end -->
