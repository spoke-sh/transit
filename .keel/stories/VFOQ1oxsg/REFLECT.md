# Reflect - Implement ObjectStoreMembership Provider

## Acceptance Criteria

- [x] [SRS-02/AC-01] Implement `ObjectStoreMembership` using the existing `ObjectStore` trait. <!-- verify: cargo test -p transit-core --lib membership::tests, SRS-02:start, SRS-02:end -->
- [x] [SRS-02/AC-02] Nodes can register and heartbeat their presence via files in a discovery directory. <!-- verify: cargo test -p transit-core --lib membership::tests, SRS-02:continues, SRS-02:end -->
- [x] [SRS-02/AC-03] Membership provider can list all active nodes based on valid heartbeats. <!-- verify: cargo test -p transit-core --lib membership::tests, SRS-02:continues, SRS-02:end -->
