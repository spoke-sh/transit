# Deliver Hosted Transport Robustness Improvements - SRS

## Summary

Epic: VHRmIhDsm
Goal: Add configurable hosted I/O timeouts and concurrent connection handling so sustained producer/consumer workloads stop routinely failing with 1s transport timeouts.

## Scope

### In Scope

- [SCOPE-01] Configurable server-side connection I/O timeout for hosted runtime callers.
- [SCOPE-02] Configurable client-side I/O timeout for `RemoteClient` and `TransitClient`.
- [SCOPE-03] Concurrent serving of accepted hosted connections to remove strict listener-loop serialization.
- [SCOPE-04] CLI/server proof coverage and operator guidance for raised timeout configuration under mixed producer/consumer load.

### Out of Scope

- [SCOPE-05] Connection pooling or reuse beyond the existing request/response connection model.
- [SCOPE-06] Any change to append, read, tail, lineage, checkpoint, or materialization semantics.
- [SCOPE-07] Protocol redesign beyond runtime configuration and concurrent connection serving.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Expose configurable server-side connection I/O timeout on `ServerConfig`, preserving the current explicit 1s default when callers do not override it. | SCOPE-01 | FR-01 | story: VHRmM7JKd |
| SRS-02 | Expose configurable client-side I/O timeout on `RemoteClient` and `TransitClient`, preserving the current explicit 1s default when callers do not override it. | SCOPE-02 | FR-02 | story: VHRmM7JKd |
| SRS-03 | Publish an operator-facing timeout configuration path that CLI/server proof coverage can exercise explicitly. | SCOPE-04 | FR-04 | story: VHRmM9dNP |
| SRS-04 | Serve accepted hosted connections concurrently instead of handling them strictly inline in the listener loop. | SCOPE-03 | FR-03 | story: VHRmM8aLE |
| SRS-05 | Provide proof/test coverage that demonstrates a mixed producer/consumer hosted workload with raised timeouts and unchanged protocol semantics. | SCOPE-04 | FR-04 | story: VHRmM8aLE |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Timeout and concurrency changes must preserve the existing hosted request/response, append, and tail semantics exactly. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-01 | story: VHRmM7JKd |
| SRS-NFR-02 | The hosted runtime should no longer hit routine 1s transport timeouts under moderate sustained producer/consumer load once the new timeout knobs are raised above the work duration. | SCOPE-03, SCOPE-04 | NFR-02 | story: VHRmM8aLE |
| SRS-NFR-03 | The implementation and operator surface must stay bounded to transport/runtime robustness and avoid expanding into connection pooling or a private hosted dialect. | SCOPE-04 | NFR-03 | story: VHRmM9dNP |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
