# Build and Verify SQL Materialization Flow - SDD

## Summary

This voyage integrates Apache DataFusion storage with Transit's materialization engine.

## Architecture

The `SqlMaterializer` acts as a `Reducer` that translates Transit records into SQL commands (or direct storage updates) executed against a DataFusion-backed Prolly Tree.

### Components

- `SqlMaterializer`: The bridge between Transit streams and SQL execution.
- `Apache DataFusion`: The execution engine for SQL commands.
- `ProllyTable`: The storage adapter implemented in `VICkpNoeV`.

### Flow

1. `SqlMaterializer` receives a batch of records from a Transit stream.
2. For each record, it determines the target table and operation.
3. It executes the operation against the DataFusion context (or directly via `ProllyTreeBuilder` if optimizing).
4. Periodic checkpoints are taken to commit the Prolly Tree root and save the materialization cursor.
