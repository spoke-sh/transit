---
id: VDst5yAoK
title: Define Consensus And Provider Traits
type: feat
status: done
created_at: 2026-03-14T15:41:23
updated_at: 2026-03-14T15:42:38
operator-signal: 
scope: VDssrPWoX/VDsswMQlJ
index: 1
started_at: 2026-03-14T15:41:57
completed_at: 2026-03-14T15:42:38
---

# Define Consensus And Provider Traits

## Summary

Define the core `ConsensusHandle` and `ConsensusProvider` traits to allow for pluggable leader election.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Define `ConsensusHandle` trait for checking leadership status. <!-- [SRS-01/AC-01] verify: cargo check -p transit-core, SRS-01:start, SRS-01:end -->
- [x] [SRS-01/AC-02] Define `ConsensusProvider` trait for acquiring leases. <!-- [SRS-01/AC-02] verify: cargo check -p transit-core, SRS-01:continues, SRS-01:end -->
