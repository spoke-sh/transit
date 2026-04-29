# Prolly Tree Storage Backend for Apache DataFusion - Product Requirements

## Problem Statement

Apache DataFusion needs a custom storage backend that leverages Transit's Prolly Trees for structural sharing and O(1) branching.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Implement DataFusion storage traits on Prolly Trees. | Passing test suite for DDL and DML. | 100% trait coverage |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Developer | Integrating SQL materialization into Transit. | A reliable SQL interface for Prolly Trees. |

## Scope

### In Scope

- [SCOPE-01] DataFusion `TableProvider` implementation.
- [SCOPE-02] DataFusion `CatalogProvider` implementation.
- [SCOPE-03] Integration with Transit Prolly Tree structures.
- [SCOPE-04] Arrow RecordBatch mapping for Prolly Tree nodes.

### Out of Scope

- [SCOPE-05] SQL transactions (DataFusion is typically analytical/stateless).
- [SCOPE-06] Complex multi-table indexes beyond Prolly Tree primary keys.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Implement DataFusion storage interface (`TableProvider`). | GOAL-01 | must | Core functionality. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Maintain Prolly Tree invariants. | GOAL-01 | must | Ensuring data integrity. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Storage Trait | Automated unit tests for TableProvider methods | Test logs showing successful table scanning and record retrieval |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| DataFusion's Arrow-native model aligns with Prolly Tree serialization. | Performance overhead in conversion. | Benchmarks. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Handling writes (INSERT/UPDATE/DELETE) in DataFusion. | Architecture | Investigate `insert_into` or custom materializer logic. |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Passing test suite demonstrating `CREATE EXTERNAL TABLE` (or equivalent) and `SELECT`.
- [ ] Zero Prolly Tree invariant violations during SQL operations.
<!-- END SUCCESS_CRITERIA -->
