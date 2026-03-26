---
# system-managed
id: VEz8W0SPu
status: backlog
created_at: 2026-03-26T07:49:08
updated_at: 2026-03-26T08:05:36
# authored
title: Add Branch Aware Materialization Scenario To Proof
type: feat
operator-signal:
scope: VEz2huKbt/VEz3VMCrg
index: 3
---

# Add Branch Aware Materialization Scenario To Proof

## Summary

Extend the `materialization-proof` command with a branch-aware scenario: create a branch, append branch-specific records, materialize the branch independently, and produce a branch-local snapshot with a distinct root digest from the root stream snapshot.

## Acceptance Criteria

- [ ] [SRS-04/AC-01] The proof creates a branch, appends branch-specific records, and materializes the branch independently. <!-- [SRS-04/AC-01] verify: cargo test + just screen, SRS-04:start:end -->
- [ ] [SRS-04/AC-02] The branch snapshot has a distinct root digest from the root stream snapshot. <!-- [SRS-04/AC-02] verify: cargo test + just screen, SRS-04:start:end -->
- [ ] [SRS-05/AC-01] Materialization checkpoints and snapshots reference the same manifests and lineage model as the core engine. <!-- [SRS-05/AC-01] verify: code review + cargo test, SRS-05:start:end -->
