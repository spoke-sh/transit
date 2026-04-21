---
# system-managed
id: VHRmM8aLE
status: backlog
created_at: 2026-04-21T10:20:47
updated_at: 2026-04-21T10:25:32
# authored
title: Serve Hosted Connections Concurrently Under Producer Consumer Load
type: feat
operator-signal:
scope: VHRmIhDsm/VHRmIjGvL
index: 2
---

# Serve Hosted Connections Concurrently Under Producer Consumer Load

## Summary

Remove strict listener-loop serialization by serving accepted hosted
connections concurrently and prove the hosted runtime behaves robustly under
mixed producer/consumer traffic.

## Acceptance Criteria

- [ ] [SRS-04/AC-01] Accepted hosted connections are no longer served strictly inline in the listener loop; producer and consumer requests can make progress concurrently. <!-- verify: cargo test -p transit-core hosted_concurrent_connection_ -- --nocapture, SRS-04:start:end -->
- [ ] [SRS-05/AC-02] A targeted mixed producer/consumer workload with raised timeouts completes on the existing hosted protocol surface without routine transport timeout failure. <!-- verify: cargo test -p transit-core hosted_producer_consumer_timeout_ -- --nocapture, SRS-05:start:end -->
- [ ] [SRS-NFR-02/AC-03] The robustness proof remains about runtime behavior only and preserves the existing append and tail semantics while producer and consumer traffic overlap. <!-- verify: cargo test -p transit-core hosted_producer_consumer_timeout_ -- --nocapture, SRS-NFR-02:start:end -->
