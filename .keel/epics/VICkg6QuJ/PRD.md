# SQL Materializer and Branch Integration - Product Requirements

## Problem Statement

Need a concrete SqlMaterializer that integrates Apache DataFusion with Transit streams and demonstrates branch-local SQL reuse.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Create a branch-aware SQL materializer. | Successful materialization of forked streams. | 0 data duplication |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Operator | Managing derived SQL views. | Branch-aware SQL state. |

## Scope

### In Scope

- [SCOPE-01] `SqlReducer` implementation.
- [SCOPE-02] Stream-to-SQL integration.
- [SCOPE-03] Branch-local reuse demonstration.

### Out of Scope

- [SCOPE-04] Cross-stream JOIN materialization.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Materialize stream records via SQL. | GOAL-01 | must | Core materialization logic. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Leverage Prolly structural sharing. | GOAL-01 | must | Minimize storage overhead for branches. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| End-to-End | Proof path with forked streams | CLI logs showing SQL results and Prolly node reuse |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Stream payloads can be easily mapped to SQL DML commands. | Need complex payload mapping logic. | Materialization flow tests. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Handling SQL schema evolution across branches. | Product | Out of scope for now. |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] SQL view correctly reflects stream history.
- [ ] Child branches reuse Prolly nodes from parent branches.
<!-- END SUCCESS_CRITERIA -->
