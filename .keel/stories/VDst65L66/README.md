---
id: VDst65L66
title: Enforce Consensus Leadership In Local Engine
type: feat
status: backlog
created_at: 2026-03-14T15:41:23
updated_at: 2026-03-14T15:41:52
operator-signal: 
scope: VDssrPWoX/VDsswMQlJ
index: 3
---

# Enforce Consensus Leadership In Local Engine

## Summary

Integrate consensus checking into `LocalEngine` to ensure only the current leader can append or update history.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] Enforce leadership check in `LocalEngine::append`. <!-- [SRS-03/AC-01] verify: cargo test -p transit-core, SRS-03:start, SRS-03:end -->
- [ ] [SRS-NFR-01/AC-01] Ensure cached leadership status avoids remote checks on every record. <!-- [SRS-NFR-01/AC-01] verify: cargo test -p transit-core, SRS-NFR-01:start, SRS-NFR-01:end -->
