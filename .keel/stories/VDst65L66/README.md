---
id: VDst65L66
title: Enforce Consensus Leadership In Local Engine
type: feat
status: done
created_at: 2026-03-14T15:41:23
updated_at: 2026-03-14T15:48:18
operator-signal: 
scope: VDssrPWoX/VDsswMQlJ
index: 3
started_at: 2026-03-14T15:44:55
completed_at: 2026-03-14T15:48:18
---

# Enforce Consensus Leadership In Local Engine

## Summary

Integrate consensus checking into `LocalEngine` to ensure only the current leader can append or update history.

## Acceptance Criteria

- [x] [SRS-03/AC-01] Enforce leadership check in `LocalEngine::append`. <!-- [SRS-03/AC-01] verify: cargo test -p transit-core engine::tests::engine_enforces_leadership_for_appends, SRS-03:start, SRS-03:end -->
- [x] [SRS-NFR-01/AC-01] Ensure cached leadership status avoids remote checks on every record. <!-- [SRS-NFR-01/AC-01] verify: cargo test -p transit-core engine::tests::engine_enforces_leadership_for_appends, SRS-NFR-01:start, SRS-NFR-01:end -->
