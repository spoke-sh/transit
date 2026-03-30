---
# system-managed
id: VFOcdNxWm
status: backlog
created_at: 2026-03-30T15:43:41
updated_at: 2026-03-30T16:26:48
# authored
title: Verify Automatic Failover With Chaos Test
type: feat
operator-signal:
scope: VFOPrFVvq/VFOPyDxnf
index: 4
---

# Verify Automatic Failover With Chaos Test

## Summary

Verify the end-to-end automatic failover behavior by simulating primary failure in a multi-node cluster.

## Acceptance Criteria

- [ ] [SRS-04/AC-01] Failover events are logged and observable through the server API. <!-- verify: manual, SRS-04:start, SRS-04:end -->
- [ ] [SRS-NFR-02/AC-01] Handoff is achieved within the configured lease timeout plus propagation delay. <!-- verify: manual, SRS-NFR-02:start, SRS-NFR-02:end -->
- [ ] [SRS-05/AC-01] A follower becomes writable automatically after primary failure is detected. <!-- verify: automated, SRS-05:start, SRS-05:end -->
