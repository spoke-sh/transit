# Implement Core Prolly Storage Traits for DataFusion - SRS

## Summary

Epic: VICkg4FuI
Goal: Implement and verify the DataFusion storage traits on top of Prolly Trees.

## Scope

### In Scope

- [SCOPE-01] Implementation of DataFusion `TableProvider` trait for read operations.
- [SCOPE-02] Implementation of DataFusion `CatalogProvider` trait for table discovery.
- [SCOPE-03] Integration with Prolly Tree `LeafEntry` encoding.

### Out of Scope

- [SCOPE-04] Full support for all DataFusion `TableProvider` optional methods (e.g., `insert_into` might be handled by materializer).
- [SCOPE-05] High-performance analytical optimizations.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Map Prolly Tree entries to Arrow RecordBatches. | SCOPE-03 | FR-01 | automated |
| SRS-02 | Implement `ProllyTable` as a `TableProvider` for scanning Prolly Trees. | SCOPE-01 | FR-01 | automated |
| SRS-03 | Implement `ProllyCatalog` as a `CatalogProvider` to manage multiple Prolly-backed tables. | SCOPE-02 | FR-01 | automated |
| SRS-04 | Verify storage implementation with integration tests. | SCOPE-01 | FR-01 | automated |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Ensure storage operations maintain Prolly Tree invariants. | SCOPE-03 | NFR-01 | automated |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
