---
id: VDcx7jKhg
title: Define Stream And Lineage Kernel Types
type: feat
status: in-progress
created_at: 2026-03-11T22:17:01
updated_at: 2026-03-11T22:21:54
operator-signal: 
scope: VDcx2lQGz/VDcx4sb6D
index: 1
started_at: 2026-03-11T22:21:54
---

# Define Stream And Lineage Kernel Types

## Summary

Define the first typed kernel for streams, branches, merges, and lineage metadata in `transit-core`
so later storage and server work can build on a stable model instead of inventing semantics piecemeal.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] `transit-core` defines typed identifiers and lineage entities for streams, branch points, merge specs, and merge-policy metadata. <!-- [SRS-01/AC-01] verify: cargo test --workspace, SRS-01:start, proof: ac-1.log-->
- [ ] [SRS-01/AC-02] The kernel model preserves multi-parent merge lineage explicitly instead of reducing merge to an opaque application-level event. <!-- [SRS-01/AC-02] verify: cargo test --workspace, SRS-01:continues, proof: ac-2.log-->
- [ ] [SRS-NFR-02/AC-01] Branch and merge types preserve append-only semantics and avoid hidden reconciliation behavior. <!-- [SRS-NFR-02/AC-01] verify: cargo test --workspace, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log-->
