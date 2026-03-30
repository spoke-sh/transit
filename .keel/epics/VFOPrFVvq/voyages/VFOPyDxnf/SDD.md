# Enable Automatic Leader Election and Failover - System Design Document

> Architectural approach for automatic election and failover.

## Architectural Goal

Implement automatic failover by allowing followers to monitor the primary lease and attempt to acquire it once it expires or is explicitly released.

## Design Center

1.  **Election Loop:** Each follower runs a background election loop that periodically checks the health and lease status of the current primary.
2.  **Lease Expiration:** The `ConsensusHandle` and `ObjectStoreLease` must support expiration times. If the primary does not renew its heartbeat, the lease eventually expires.
3.  **Automatic Acquisition:** Once a lease is expired, any eligible follower can attempt to acquire it. The `ObjectStoreLease` uses optimistic locking to ensure that only one node succeeds.
4.  **Promotion Path:** A node that acquires the lease follows the existing "promotion readiness" logic (e.g., checking it has the latest published frontier) before becoming writable.

## Components

### Election Monitor
- Periodically queries `ConsensusHandle::current_primary()`.
- If the primary node is inactive or the lease is expired, triggers a `LeaseAcquisitionAttempt`.

### Lease Heartbeat
- The active primary must periodically renew its lease (e.g., every 10 seconds).
- The lease timeout should be larger than the heartbeat interval (e.g., 30 seconds).

### Failover Fencing
- The engine must check `ConsensusHandle::is_primary(stream_id)` before every append or manifest update.
- If the check fails (e.g., because another node took the lease), the engine must immediately stop accepting writes and transition to a read-only or error state.

## Data Flow

1.  **Primary Failure:** Primary node crashes or loses network connectivity.
2.  **Heartbeat Timeout:** The primary lease in the object store expires because it was not renewed.
3.  **Election Trigger:** Follower's election loop detects the expired lease.
4.  **Acquisition:** Follower attempts to acquire the lease. If it succeeds, it proceeds to promotion.
5.  **Promotion:** Follower verifies its data is caught up and transitions to the writable primary role.
6.  **Fencing:** If the old primary recovers, its next write attempt will fail the lease check, and it will fence itself.

## Tradeoffs and Constraints

- **Failover Latency:** Automatic failover is limited by the lease timeout. Shorter timeouts provide faster recovery but increase the risk of "false positive" failover due to network blips.
- **Clock Dependency:** Lease expiration depends on timestamps in the object store. Using a relative TTL or a shared monotonic time source (if available) is preferred over absolute system clocks.

## Failures and Recovery

- **Split Brain:** Prevented by the atomicity of the `ObjectStoreLease` acquisition. Only one node can own the lease at a time.
- **Acquisition Contention:** If multiple followers attempt to acquire the lease simultaneously, the object store's optimistic locking will ensure only one wins; others will retry or fall back to following the new leader.
