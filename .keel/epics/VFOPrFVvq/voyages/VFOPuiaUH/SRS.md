# Implement Quorum Durability and Membership - Software Requirements

> Define the cluster membership model and implement the quorum durability mode for appends. This voyage provides the foundations for automatic failover.

## Goal

Define exactly how a Transit cluster knows its own membership and implement a `quorum` durability mode that waits for a majority of nodes.

## Scope

### In Scope

- [SCOPE-01] Cluster membership surface: nodes can register their identity and address.
- [SCOPE-02] `quorum` durability mode implementation in `transit-core`.
- [SCOPE-03] Shared-engine acknowledgement logic that can wait for peer confirmation.

### Out of Scope

- [SCOPE-04] Automatic leader election (next voyage).
- [SCOPE-05] Advanced failure detectors.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Parent | Priority |
|----|-------------|-------|--------|--------|----------|
| SRS-01 | Define a `ClusterMembership` trait that allows nodes to query the set of active peers. | SCOPE-01 | FR-03 | FR-03 | must |
| SRS-02 | Implement an initial `ObjectStoreMembership` provider that uses a discovery file or directory in object storage. | SCOPE-01 | FR-03 | FR-03 | must |
| SRS-03 | Add a `quorum` variant to `DurabilityMode` and implement the wait-for-majority logic in the engine. | SCOPE-02 | FR-01 | FR-01 | must |
| SRS-04 | Ensure that the engine can handle partial acknowledgements and timeouts when waiting for quorum. | SCOPE-03 | FR-01 | FR-01 | must |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Parent | Priority |
|----|-------------|-------|--------|--------|----------|
| SRS-NFR-01 | The quorum logic must remain pluggable and independent of the network transport. | SCOPE-03 | NFR-01 | NFR-01 | must |
| SRS-NFR-02 | Membership lookup should be efficient enough for use in every quorum append. | SCOPE-01 | NFR-02 | NFR-02 | should |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

- **Quorum Success:** A 3-node cluster can acknowledge appends with `DurabilityMode::Quorum` if 2 nodes are healthy.
- **Quorum Failure:** A 3-node cluster cannot acknowledge appends if 2 nodes are down.
- **Membership Discovery:** A new node added to the discovery directory is automatically seen as part of the quorum.
