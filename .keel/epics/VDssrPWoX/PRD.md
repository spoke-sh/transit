# Implement Multi-Node Consensus And Leader Election - Product Requirements

> Transit needs a way to coordinate stream head ownership across multiple nodes to prevent manifest corruption and enable distributed append.

## Problem Statement

`transit` currently assumes a single logical writer per stream head. In a multi-node environment, we must ensure that only one node can act as the leader for a given `stream_id` to maintain the append-only discipline and prevent manifest generation collisions. Without a consensus mechanism, multiple nodes could attempt to roll segments or update manifests simultaneously, leading to data loss or corruption in the object storage source of truth.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Implement a distributed leader election mechanism for stream ownership. | Only one node can append to a stream at a time | Implementation verified |
| GOAL-02 | Ensure linearizable manifest updates across multiple nodes. | No manifest generation collisions in object storage | Implementation verified |
| GOAL-03 | Preserve the "one engine" thesis by keeping consensus lightweight and integrated. | No mandatory heavy external dependencies (like a full ZK/etcd cluster) | Implementation verified |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Core Engineer | Builds the distributed engine | A reliable way to coordinate writes without sacrifice performance |
| Operator | Deploys multi-node Transit | High availability and conflict-free scaling |

## Scope

### In Scope

- [SCOPE-01] Stream ownership leases (only one node owns the head of a `stream_id`).
- [SCOPE-02] Consensus-backed manifest updates.
- [SCOPE-03] Integration with `LocalEngine` to enforce ownership.

### Out of Scope

- [SCOPE-04] Full multi-master write reconciliation (multi-writer per stream is not the goal; one-leader-per-stream is).
- [SCOPE-05] Cross-region geographic replication.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Implement a `ConsensusHandle` trait for leader election and lease management. | GOAL-01 | must | Pluggable consensus backend. |
| FR-02 | Implement an `ObjectStoreLease` provider for consensus without external clusters. | GOAL-01, GOAL-03 | must | Aligns with object-storage-native thesis. |
| FR-03 | Update `LocalEngine` to acquire a lease before allowing appends or manifest updates. | GOAL-01, GOAL-02 | must | Enforces ownership in the engine. |
| FR-04 | Support lease fencing (STONITH) to prevent "zombie" leaders from writing. | GOAL-02 | must | Prevents corruption during network partitions. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Minimize consensus latency for the hot append path. | GOAL-01 | must | Ownership should be cached or heartbeated, not checked on every single record. |
| NFR-02 | Ensure the system remains available if a minority of nodes fail. | GOAL-01 | must | High availability. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

- Chaos tests: killing leaders and verifying that new leaders take over without corruption.
- Multi-node integration tests simulating concurrent write attempts.
- Jepsen-style linearizability checks for manifest generations.

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Object storage providers offer enough conditional-write primitives for a reliable lease. | May need an external coordinator (etcd/Consul) for some backends. | Test across S3, Azure, and GCS. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should we use a lightweight internal Raft (e.g. `raft-rs` or `openraft`) instead of pure object-store leases? | Architecture | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Only one node can act as leader for a stream head.
- [ ] Concurrent appends from different nodes are correctly fenced.
- [ ] Manifest updates are linearizable.
<!-- END SUCCESS_CRITERIA -->
