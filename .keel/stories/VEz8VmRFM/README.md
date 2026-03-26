---
# system-managed
id: VEz8VmRFM
status: backlog
created_at: 2026-03-26T07:49:08
updated_at: 2026-03-26T08:05:36
# authored
title: Add Prolly Tree Snapshot Production To Materialization Proof
type: feat
operator-signal:
scope: VEz2huKbt/VEz3VMCrg
index: 2
---

# Add Prolly Tree Snapshot Production To Materialization Proof

## Summary

Extend the `materialization-proof` command to build a Prolly Tree snapshot from the materializer's derived state using `ProllyTreeBuilder` and `ObjectStoreProllyStore`, and produce a `SnapshotManifest` binding the root digest to the source checkpoint.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] The proof builds a Prolly Tree from derived state entries and stores nodes via `ObjectStoreProllyStore`. <!-- [SRS-03/AC-01] verify: cargo test + just screen, SRS-03:start:end -->
- [ ] [SRS-03/AC-02] The proof produces a `SnapshotManifest` with a root digest bound to the source `LineageCheckpoint`. <!-- [SRS-03/AC-02] verify: cargo test + just screen, SRS-03:start:end -->
