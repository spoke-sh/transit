---
# system-managed
id: VFOQ1pmtQ
status: backlog
created_at: 2026-03-30T15:35:31
updated_at: 2026-03-30T15:37:10
# authored
title: Add Quorum Durability Mode To Engine
type: feat
operator-signal:
scope: VFOPrFVvq/VFOPuiaUH
index: 3
---

# Add Quorum Durability Mode To Engine

## Summary

Add the `Quorum` variant to `DurabilityMode` and integrate it into the engine's append path.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] Add `Quorum` variant to `DurabilityMode` enum. <!-- verify: automated, SRS-03:start, SRS-03:end -->
- [ ] [SRS-03/AC-02] Update `Engine` state to track peer acknowledgement sets for in-flight appends. <!-- verify: automated, SRS-03:continues, SRS-03:end -->
- [ ] [SRS-NFR-01/AC-01] The implementation remains independent of the underlying network transport. <!-- verify: manual, SRS-NFR-01:start, SRS-NFR-01:end -->
