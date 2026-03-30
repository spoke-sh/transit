# Reflect - Add Quorum Durability Mode To Engine

## Acceptance Criteria

- [x] [SRS-03/AC-01] Add `Quorum` variant to `DurabilityMode` enum. <!-- verify: cargo test -p transit-core engine::tests::quorum_mode_is_defined, SRS-03:start, SRS-03:end -->
- [x] [SRS-03/AC-02] Update `Engine` state to track peer acknowledgement sets for in-flight appends. <!-- verify: cargo test -p transit-core engine::tests::engine_tracks_peer_acks, SRS-03:continues, SRS-03:end -->
- [x] [SRS-NFR-01/AC-01] The implementation remains independent of the underlying network transport. <!-- verify: cargo test -p transit-core engine::tests::engine_tracks_peer_acks, SRS-NFR-01:start, SRS-NFR-01:end -->
