---
# system-managed
id: VFOQ1pmtQ
status: done
created_at: 2026-03-30T15:35:31
updated_at: 2026-03-30T15:46:31
# authored
title: Add Quorum Durability Mode To Engine
type: feat
operator-signal:
scope: VFOPrFVvq/VFOPuiaUH
index: 3
started_at: 2026-03-30T15:37:12
completed_at: 2026-03-30T15:46:31
---

# Add Quorum Durability Mode To Engine

## Summary

Add the `Quorum` variant to `DurabilityMode` and integrate it into the engine's append path.

## Acceptance Criteria

- [x] [SRS-03/AC-01] Add `Quorum` variant to `DurabilityMode` enum. <!-- verify: cargo test -p transit-core engine::tests::quorum_mode_is_defined, SRS-03:start, SRS-03:end, proof: ac-1.log -->
- [x] [SRS-03/AC-02] Update `Engine` state to track peer acknowledgement sets for in-flight appends. <!-- verify: cargo test -p transit-core engine::tests::engine_tracks_peer_acks, SRS-03:continues, SRS-03:end, proof: ac-2.log -->
- [x] [SRS-NFR-01/AC-01] The implementation remains independent of the underlying network transport. <!-- verify: cargo test -p transit-core engine::tests::engine_tracks_peer_acks, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log -->
