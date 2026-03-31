---
# system-managed
id: VFOcdMHUG
status: done
created_at: 2026-03-30T15:43:41
updated_at: 2026-03-30T16:39:35
# authored
title: Implement Election Loop For Followers
type: feat
operator-signal:
scope: VFOPrFVvq/VFOPyDxnf
index: 2
started_at: 2026-03-30T15:44:12
completed_at: 2026-03-30T16:39:35
---

# Implement Election Loop For Followers

## Summary

Implement a background loop that monitors the primary lease and triggers an election when it expires.

## Acceptance Criteria

- [x] [SRS-01/AC-03] Implement an `ElectionMonitor` that periodically checks lease health. <!-- verify: cargo test -p transit-core --lib consensus::tests, SRS-01:continues, SRS-01:end, proof: ac-1.log -->
- [x] [SRS-NFR-01/AC-01] The election timeout is configurable via `LocalEngineConfig`. <!-- verify: cargo test -p transit-core engine::tests, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-2.log -->
