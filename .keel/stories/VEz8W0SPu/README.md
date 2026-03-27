---
# system-managed
id: VEz8W0SPu
status: done
created_at: 2026-03-26T07:49:08
updated_at: 2026-03-26T23:46:45
# authored
title: Add Branch Aware Materialization Scenario To Proof
type: feat
operator-signal:
scope: VEz2huKbt/VEz3VMCrg
index: 3
started_at: 2026-03-26T23:41:26
completed_at: 2026-03-26T23:46:45
---

# Add Branch Aware Materialization Scenario To Proof

## Summary

Extend the `materialization-proof` command with a branch-aware scenario: create a branch, append branch-specific records, materialize the branch independently, and produce a branch-local snapshot with a distinct root digest from the root stream snapshot.

## Acceptance Criteria

- [x] [SRS-04/AC-01] The proof creates a branch, appends branch-specific records, and materializes the branch independently. <!-- [SRS-04/AC-01] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof-branch, SRS-04:start:end, proof: ac-1.log -->
- [x] [SRS-04/AC-02] The branch snapshot has a distinct root digest from the root stream snapshot. <!-- [SRS-04/AC-02] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof-branch-json --json, SRS-04:start:end, proof: ac-2.log -->
- [x] [SRS-05/AC-01] Materialization checkpoints and snapshots reference the same manifests and lineage model as the core engine. <!-- [SRS-05/AC-01] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture, SRS-05:start:end, proof: ac-3.log -->
