# Incremental Prolly Tree Updates - Product Requirements

## Problem Statement

ProllyTreeBuilder currently only supports batch builds; logarithmic point updates (insert/delete) are required for efficient SQL materialization.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Add point update support to Prolly Trees. | O(log N) insert/delete performance. | < 10ms for 1M keys |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Developer | Building efficient materializers. | Fast incremental state updates. |

## Scope

### In Scope

- [SCOPE-01] Recursive `insert` implementation.
- [SCOPE-02] Recursive `delete` implementation.
- [SCOPE-03] Prolly node re-chunking logic.

### Out of Scope

- [SCOPE-04] Range deletes.
- [SCOPE-05] Bulk load optimizations beyond current batch builder.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Support logarithmic point mutations. | GOAL-01 | must | Required for incremental SQL. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Mutation must be O(log N). | GOAL-01 | must | Avoid performance regressions. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Performance | Benchmarks against trees with 1M+ entries | Performance logs showing O(log N) scaling |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Current chunking logic can be adapted for point mutations. | Need a new chunking algorithm. | Recursive update tests. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Pathological cases where many nodes need re-chunking. | Engineering | To be analyzed. |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] `insert` and `delete` correctly maintain tree order and invariants.
- [ ] Mutation time scales logarithmically with tree size.
<!-- END SUCCESS_CRITERIA -->
