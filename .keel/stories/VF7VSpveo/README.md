---
# system-managed
id: VF7VSpveo
status: done
created_at: 2026-03-27T18:10:28
updated_at: 2026-03-27T18:27:49
# authored
title: Bootstrap Read-Only Follower Catch-Up
type: feat
operator-signal:
scope: VDd1J2IDM/VF7VP3H4s
index: 1
started_at: 2026-03-27T18:23:55
submitted_at: 2026-03-27T18:27:39
completed_at: 2026-03-27T18:27:49
---

# Bootstrap Read-Only Follower Catch-Up

## Summary

Bootstrap the first follower path by restoring and advancing from published remote-tier history while keeping followers explicitly read-only and aligned with the shared engine.

## Acceptance Criteria

- [x] [SRS-02/AC-01] Allow a follower to bootstrap from published remote-tier history using the shared restore path while remaining read-only. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-1.log -->
- [x] [SRS-02/AC-02] Define follower catch-up in terms of published frontier advancement rather than direct record fan-out or follower-local writes. <!-- [SRS-02/AC-02] verify: manual, SRS-02:continues, SRS-02:end, proof: ac-2.log -->
- [x] [SRS-NFR-02/AC-01] Keep follower behavior below consensus, failover, and ownership-transfer semantics. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log -->
