# Implement Core Prolly Storage Traits for DataFusion - SDD

## Summary

This voyage implements the bridge between Apache DataFusion and Transit's Prolly Trees.

## Architecture

DataFusion interacts with storage through the `TableProvider` and `CatalogProvider` traits. We provide a `ProllyTable` implementation that translates these calls into Prolly Tree scans and lookups.

### Components

- `ProllyTable`: Implements `TableProvider`. Handles schema mapping and produces `ExecutionPlan`s for scanning.
- `ProllyCatalog`: Implements `CatalogProvider`. Discovers available Prolly Trees and registers them as tables.
- `RowEncoding`: Mapping between Prolly Tree `LeafEntry` and Arrow `RecordBatch`.

### Flow

1. DataFusion receives a query referencing a Prolly-backed table.
2. `ProllyCatalog` provides the `ProllyTable` instance.
3. `ProllyTable` creates a `ProllyScan` (custom `ExecutionPlan`).
4. `ProllyScan` iterates over the Prolly Tree, decodes entries into Arrow columns, and returns `RecordBatch`es.
