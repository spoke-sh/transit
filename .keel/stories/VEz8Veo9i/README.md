---
# system-managed
id: VEz8Veo9i
status: done
created_at: 2026-03-26T07:49:07
updated_at: 2026-03-26T23:34:53
# authored
title: Implement Materialization Proof CLI Command With Checkpoint And Resume
type: feat
operator-signal:
scope: VEz2huKbt/VEz3VMCrg
index: 1
started_at: 2026-03-26T23:24:20
completed_at: 2026-03-26T23:34:53
---

# Implement Materialization Proof CLI Command With Checkpoint And Resume

## Summary

Add a `materialization-proof` CLI mission subcommand to `transit-cli` that appends records, runs `LocalMaterializationEngine` with a simple counting reducer, produces a `MaterializationCheckpoint`, then resumes from that checkpoint and verifies only new records are processed.

## Acceptance Criteria

- [x] [SRS-01/AC-01] `transit mission materialization-proof --root <path>` appends records, runs a materializer, and reports the materialized count matching the appended count. <!-- [SRS-01/AC-01] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof, SRS-01:start:end, proof: ac-1.log -->
- [x] [SRS-02/AC-01] The proof checkpoints, appends more records, resumes from the checkpoint, and verifies only the new records were processed. <!-- [SRS-02/AC-01] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof-json --json, SRS-02:start:end, proof: ac-2.log -->
- [x] [SRS-NFR-01/AC-01] The materialization checkpoint contains a `LineageCheckpoint` anchor from the core engine, not a parallel model. <!-- [SRS-NFR-01/AC-01] verify: cargo test -p transit-materialize materializer_can_resume_from_checkpoint_without_reprocessing_old_records -- --nocapture, SRS-NFR-01:start:end, proof: ac-3.log -->
