# VOYAGE REPORT: Kernel Types And Storage Skeleton

## Voyage Metadata
- **ID:** VDcx4sb6D
- **Epic:** VDcx2lQGz
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 3/3 stories complete

## Implementation Narrative
### Define Stream And Lineage Kernel Types
- **ID:** VDcx7jKhg
- **Status:** done

#### Summary
Define the first typed kernel for streams, branches, merges, and lineage metadata in `transit-core`
so later storage and server work can build on a stable model instead of inventing semantics piecemeal.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] `transit-core` defines typed identifiers and lineage entities for streams, branch points, merge specs, and merge-policy metadata. <!-- [SRS-01/AC-01] verify: cargo test --workspace, SRS-01:start, proof: ac-1.log-->
- [x] [SRS-01/AC-02] The kernel model preserves multi-parent merge lineage explicitly instead of reducing merge to an opaque application-level event. <!-- [SRS-01/AC-02] verify: cargo test --workspace, SRS-01:continues, SRS-01:end, proof: ac-2.log-->
- [x] [SRS-NFR-02/AC-01] Branch and merge types preserve append-only semantics and avoid hidden reconciliation behavior. <!-- [SRS-NFR-02/AC-01] verify: cargo test --workspace, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log-->

### Implement Local Segment And Manifest Scaffolding
- **ID:** VDcx7jQiT
- **Status:** done

#### Summary
Add the first local segment and manifest scaffold in `transit-core` so the repo has a real storage
kernel slice that still preserves the object-store-native architecture.

#### Acceptance Criteria
- [x] [SRS-02/AC-01] `transit-core` defines immutable segment and manifest scaffold types shared by embedded and server-facing code. <!-- [SRS-02/AC-01] verify: cargo test --workspace, SRS-02:start, proof: ac-1.log-->
- [x] [SRS-02/AC-02] The scaffold keeps object-store-facing persistence boundaries explicit instead of collapsing into a purely local-only design. <!-- [SRS-02/AC-02] verify: cargo test --workspace; cargo run -p transit-cli --bin transit -- object-store probe --root target/transit-mission/object-store, SRS-02:continues, SRS-02:end, proof: ac-2.log-->
- [x] [SRS-03/AC-01] The segment and manifest scaffold leaves a clear checkpoint and snapshot boundary for a future materialization layer. <!-- [SRS-03/AC-01] verify: cargo test --workspace, SRS-03:start, SRS-03:end, proof: ac-3.log-->

### Upgrade Just Mission To Exercise The Storage Kernel
- **ID:** VDcx7jWDN
- **Status:** done

#### Summary
Upgrade the human-facing proof path so `just mission` validates the storage-kernel slice rather than
only bootstrap health, and keeps the CLI proof surface aligned with the mission.

#### Acceptance Criteria
- [x] [SRS-04/AC-01] `just mission` exercises the current storage-kernel slice through tests and CLI proofs. <!-- [SRS-04/AC-01] verify: nix develop path:/home/alex/workspace/spoke-sh/transit --command just mission, SRS-04:start, proof: ac-1.log-->
- [x] [SRS-04/AC-02] CLI mission status output surfaces kernel-oriented progress in human-readable form. <!-- [SRS-04/AC-02] verify: cargo run -p transit-cli --bin transit -- mission status --repo-root ., SRS-04:continues, SRS-04:end, proof: ac-2.log-->
- [x] [SRS-NFR-03/AC-01] The proof path remains one obvious operator entrypoint instead of spreading across ad hoc commands. <!-- [SRS-NFR-03/AC-01] verify: just mission, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log-->


