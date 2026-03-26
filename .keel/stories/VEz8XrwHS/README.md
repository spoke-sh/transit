---
# system-managed
id: VEz8XrwHS
status: backlog
created_at: 2026-03-26T07:49:16
updated_at: 2026-03-26T08:06:55
# authored
title: Add Tail Session Support To Python Client
type: feat
operator-signal:
scope: VEz2iOasp/VEz3VaL0a
index: 1
---

# Add Tail Session Support To Python Client

## Summary

Extend the Python client at `clients/python/transit_client.py` with tail session support including `tail_open()`, `poll()`, `grant_credit()`, and `cancel()` operations that match the server's credit-based delivery model.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] `TransitClient.tail_open()` opens a tail session with a starting offset and initial credit. <!-- [SRS-01/AC-01] verify: just python-client-proof, SRS-01:start:end -->
- [ ] [SRS-01/AC-02] The tail session supports `poll()` to receive records, `grant_credit()` to extend, and `cancel()` to close. <!-- [SRS-01/AC-02] verify: just python-client-proof, SRS-01:start:end -->
- [ ] [SRS-02/AC-01] Server errors and backpressure details during tail sessions are surfaced to the caller without silent swallowing. <!-- [SRS-02/AC-01] verify: code review, SRS-02:start:end -->
