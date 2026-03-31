# Ship Quorum Acknowledgement and Automatic Failover - Decision Log

<!-- Append entries below. Each entry is an H2 with ISO timestamp. -->
<!-- Use `keel mission digest` to compress older entries when this file grows large. -->

## 2026-03-30T17:14:00Z — Ship story VFOcdN9W6

Completed **Implement Automatic Lease Acquisition** (VFOcdN9W6) in voyage VFOPyDxnf.

**Delivered:**
- `ElectionMonitor` that polls `current_lease()` and fires `ElectionTrigger` on expiration or absence.
- `ElectionTrigger` impl on `LocalEngine` that attempts `provider.acquire()` and binds the handle.
- `is_expired()` on `ConsensusHandle`, `current_lease()` on `ConsensusProvider`.
- `NodeId` now required on `LocalEngineConfig::new` — every engine instance has explicit identity.
- `with_provider()` and `with_election_timeout()` config builders for wiring election into the engine.

**Evidence:** All 3 ACs verified via targeted test runs (election monitor trigger, exclusive lease optimistic locking, append fencing).
