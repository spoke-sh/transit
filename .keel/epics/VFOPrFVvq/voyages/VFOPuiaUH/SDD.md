# Implement Quorum Durability and Membership - System Design Document

> Architectural approach for cluster membership and quorum durability.

## Architectural Goal

The core engine needs to support a `DurabilityMode::Quorum` that waits for a majority of nodes to acknowledge an append. To calculate a majority, the engine must have a reliable way to discover the current cluster membership.

## Design Center

1.  **Pluggable Membership:** Introduce a `ClusterMembership` trait in `transit-core` that can query the set of active nodes.
2.  **Object-Store Discovery:** Implement an initial `ObjectStoreMembership` provider. This leverages the existing `ObjectStore` abstraction to maintain a list of active nodes without needing a separate discovery service.
3.  **Quorum Durability:** Extend `DurabilityMode` with a `Quorum` variant. When the engine appends a record with this mode, it will wait for an internal "ack set" to reach a majority.
4.  **Replication Transport Integration:** The existing server protocol must be extended to allow followers to report their receipt of records to the primary.

## Components

### `ClusterMembership` Trait
- `nodes() -> Vec<NodeIdentity>`: Returns the set of nodes currently in the cluster.
- `quorum_size() -> usize`: Returns `(nodes().len() / 2) + 1`.

### `DurabilityMode::Quorum`
- The engine will track "acknowledged offsets" from each peer.
- For a given append, the ack is complete when `n >= quorum_size()` nodes (including the primary) have acknowledged the offset.

### `ObjectStoreMembership` Implementation
- Nodes heartbeats their presence by writing or updating a file in `objects/cluster/membership/<node_id>.json`.
- The primary reads this directory to determine the current quorum.

## Data Flow

1.  **Append:** Client appends a record with `DurabilityMode::Quorum`.
2.  **Local Append:** Primary appends the record locally and acknowledges it.
3.  **Replication:** Primary replicates the record to followers.
4.  **Peer Ack:** Followers confirm receipt of the record to the primary.
5.  **Quorum Check:** Primary tracks peer acks. Once a majority is reached, it confirms the append to the client.

## Tradeoffs and Constraints

- **Discovery Latency:** `ObjectStoreMembership` might have higher latency for new node joins compared to a dedicated gossip or discovery service. This is acceptable for the initial slice.
- **Clock Drift:** Heartbeats in the object store should use a robust "last updated" mechanism that does not depend on strict clock synchronization.

## Failures and Recovery

- **Partial Quorum:** If a majority cannot be reached within a timeout, the append should return a `QuorumTimeout` error.
- **Node Join/Leave:** The system must handle nodes joining or leaving the cluster while appends are in flight.
