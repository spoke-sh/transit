# Implement Quorum Acknowledgement and Automatic Failover - Product Requirements

> Transit has proven explicit primary handoff and publication-based replication frontiers. This epic moves the system toward a true high-availability cluster by introducing quorum durability and automatic election-based failover.

## Problem Statement

Transit currently requires an operator to explicitly transfer the writable primary role to a caught-up follower. While this is safe, it does not support automatic recovery from node failure. Furthermore, the `replicated` durability mode is currently anchored to publication in object storage rather than acknowledgement from a majority of live peers. To support high-availability workloads, Transit needs to transition from "controlled handoff" to "automatic quorum-based recovery" without losing its commitment to immutable history and explicit lineage.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Implement quorum-based acknowledgements for appends. | A `quorum` durability mode that waits for a majority of nodes. | Implementation verified with automated tests. |
| GOAL-02 | Enable automatic leader election upon primary failure. | A node can be automatically promoted to primary if the previous leader's lease expires. | Verified with chaos-test failure scenarios. |
| GOAL-03 | Define and implement a cluster membership surface. | Nodes can discover each other and maintain a shared view of the quorum. | Implementation verified in the server CLI. |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Operator | Manages high-availability Transit clusters | Automatic recovery and stronger durability guarantees without manual intervention. |
| Application Developer | Builds on top of Transit | Reliable append and read semantics that survive node failures. |

## Scope

### In Scope

- [SCOPE-01] Quorum durability mode (`quorum`) that requires acknowledgement from a majority of configured peers.
- [SCOPE-02] Automatic leader election using the existing `ConsensusHandle` and `ObjectStoreLease` or an expanded provider.
- [SCOPE-03] Cluster membership and node discovery primitives.
- [SCOPE-04] Basic health checks and node status monitoring for failover decisions.

### Out of Scope

- [SCOPE-05] Dynamic cluster re-balancing or automatic data sharding.
- [SCOPE-06] Multi-primary or multi-writer semantics (still one writer per stream head).
- [SCOPE-07] Complex topology optimizations (e.g., rack-aware placement).

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Implement a `quorum` durability mode that blocks acknowledgement until a majority of peers have confirmed receipt of the records. | GOAL-01 | must | Provides the strongest durability guarantee for distributed operation. |
| FR-02 | Implement automatic election logic that triggers when a primary lease is lost or expires. | GOAL-02 | must | Reduces recovery time (RTO) by eliminating the need for manual operator intervention. |
| FR-03 | Expose a cluster membership API that allows nodes to register, heartbeat, and discover their peers. | GOAL-03 | must | Nodes must know the size and membership of the cluster to calculate quorum. |
| FR-04 | Ensure that the former primary is fenced after an automatic election to prevent split-brain. | GOAL-02 | must | Preserves the "one writer per stream head" invariant. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Maintain the one-engine thesis: quorum and failover logic must work in the shared engine. | GOAL-01, GOAL-02 | must | Keeps embedded and server modes semantically aligned. |
| NFR-02 | Minimize the impact of quorum checks on append latency. | GOAL-01 | should | High availability should not come at an unacceptable performance cost. |
| NFR-03 | Failover should be observable and logged for operator audit. | GOAL-02 | must | Operators must be able to understand why and when a failover occurred. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

- **Chaos Testing:** Simulate node failures and verify that a new leader is elected and that no committed data is lost.
- **Quorum Tests:** Verify that appends fail when a majority of nodes are unavailable.
- **Partition Testing:** Use network partitions to verify that only the majority side of the partition can make progress (avoiding split-brain).

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The existing `ConsensusHandle` is robust enough to layer automatic election. | Implementation may require trait changes. | Re-evaluate trait during the first story. |
| Object store latencies are acceptable for discovery heartbeats. | Failure detection may be too slow for some use cases. | Measure and tune lease timeouts. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| How should the initial seed nodes for cluster discovery be configured? | Operator | Open |
| Should we use a separate heartbeat interval from the lease timeout? | Architecture | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] A Transit cluster can survive the loss of a minority of its nodes without data loss or downtime for reads.
- [ ] A new leader is automatically elected and takes over within a configurable lease timeout.
- [ ] The `quorum` durability mode is proven to wait for a majority of nodes before acknowledging.
<!-- END SUCCESS_CRITERIA -->
