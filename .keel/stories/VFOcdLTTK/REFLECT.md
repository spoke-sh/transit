# Reflect - Implement Lease Expiration In Consensus

## Acceptance Criteria

- [x] [SRS-01/AC-01] Update `ObjectStoreLeaseHandle` to expose expiration status. <!-- verify: cargo test -p transit-core --lib consensus::tests, SRS-01:start, SRS-01:end -->
- [x] [SRS-01/AC-02] The `ConsensusHandle` can report the current owner even if the lease is expired. <!-- verify: cargo test -p transit-core --lib consensus::tests, SRS-01:continues, SRS-01:end -->
