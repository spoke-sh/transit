# Implement Apache DataFusion Materialization on Prolly Trees - Charter

Archetype: Technical

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Implement DataFusion `TableProvider` and `CatalogProvider` on top of Transit's Prolly Trees. | board: VICkg4FuI |
| MG-02 | Create a `SqlMaterializer` that leverages DataFusion to consume Transit streams and apply updates to a Prolly Tree-backed state. | board: VICkg6QuJ |
| MG-03 | Demonstrate branch-local SQL reuse by creating a branch of a materialized SQL view and divergent updates. | board: VICkg6QuJ |
| MG-04 | Implement efficient logarithmic point updates (insert/delete) in `ProllyTreeBuilder`. | board: VICkg5IvO |

## Constraints

- Use Apache DataFusion as the SQL engine (Arrow-native, extensible query engine).
- State must be stored in Prolly Trees to preserve Transit's structural sharing and O(1) branching.
- Must support incremental updates (INSERT/UPDATE/DELETE) in Prolly Trees via custom `ExecutionPlan` or `TableProvider` extensions.
- SQL schema should be derived from or explicitly defined for the materialization.

## Halting Rules

- HALT if Prolly Tree updates become O(N) where N is the total state size (must stay logarithmic).
- HALT if the implementation requires changing Transit's core append-only invariants.
- HALT when basic DDL/DML and branch-aware materialization are verified.
