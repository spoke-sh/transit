# Build and Verify SQL Materialization Flow - SRS

## Summary

Epic: VICkg6QuJ
Goal: Integrate SQL materialization with Transit streams and verify branch-local reuse.

## Scope

### In Scope

- [SCOPE-01] Implementation of `SqlReducer` as a `transit_materialize::Reducer`.
- [SCOPE-02] Stream-to-SQL integration.
- [SCOPE-03] Branch-local reuse demonstration.

### Out of Scope

- [SCOPE-04] Cross-stream SQL joins or complex materialized views.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Implement `SqlReducer` that executes SQL DML on Prolly storage. | SCOPE-01 | FR-01 | automated |
| SRS-02 | Verify SQL view state across stream branches. | SCOPE-03 | FR-01 | automated |
| SRS-03 | Implement `transit sql` CLI surface for interactive query execution. | SCOPE-02 | FR-01 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Materialization must preserve structural sharing via Prolly Trees. | SCOPE-03 | NFR-01 | automated |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
