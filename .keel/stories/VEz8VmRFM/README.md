---
# system-managed
id: VEz8VmRFM
status: done
created_at: 2026-03-26T07:49:08
updated_at: 2026-03-26T23:40:33
# authored
title: Add Prolly Tree Snapshot Production To Materialization Proof
type: feat
operator-signal:
scope: VEz2huKbt/VEz3VMCrg
index: 2
started_at: 2026-03-26T23:35:34
completed_at: 2026-03-26T23:40:33
---

# Add Prolly Tree Snapshot Production To Materialization Proof

## Summary

Extend the `materialization-proof` command to build a Prolly Tree snapshot from the materializer's derived state using `ProllyTreeBuilder` and `ObjectStoreProllyStore`, and produce a `SnapshotManifest` binding the root digest to the source checkpoint.

## Acceptance Criteria

- [x] [SRS-03/AC-01] The proof builds a Prolly Tree from derived state entries and stores nodes via `ObjectStoreProllyStore`. <!-- [SRS-03/AC-01] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof-snapshot, SRS-03:start:end, proof: ac-1.log -->
- [x] [SRS-03/AC-02] The proof produces a `SnapshotManifest` with a root digest bound to the source `LineageCheckpoint`. <!-- [SRS-03/AC-02] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof-snapshot-json --json, SRS-03:start:end, proof: ac-2.log -->
