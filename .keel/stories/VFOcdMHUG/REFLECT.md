# Reflect - Implement Election Loop For Followers

## Acceptance Criteria

- [x] [SRS-01/AC-03] Implement an `ElectionMonitor` that periodically checks lease health. <!-- verify: cargo test -p transit-core --lib consensus::tests, SRS-01:continues, SRS-01:end -->
- [x] [SRS-NFR-01/AC-01] The election timeout is configurable via `LocalEngineConfig`. <!-- verify: cargo test -p transit-core engine::tests, SRS-NFR-01:start, SRS-NFR-01:end -->
