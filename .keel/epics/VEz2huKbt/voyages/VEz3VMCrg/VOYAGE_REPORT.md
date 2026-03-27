# VOYAGE REPORT: Materialization End-To-End Proof

## Voyage Metadata
- **ID:** VEz3VMCrg
- **Epic:** VEz2huKbt
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 4/4 stories complete

## Implementation Narrative
### Implement Materialization Proof CLI Command With Checkpoint And Resume
- **ID:** VEz8Veo9i
- **Status:** done

#### Summary
Add a `materialization-proof` CLI mission subcommand to `transit-cli` that appends records, runs `LocalMaterializationEngine` with a simple counting reducer, produces a `MaterializationCheckpoint`, then resumes from that checkpoint and verifies only new records are processed.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] `transit mission materialization-proof --root <path>` appends records, runs a materializer, and reports the materialized count matching the appended count. <!-- [SRS-01/AC-01] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof, SRS-01:start:end, proof: ac-1.log -->
- [x] [SRS-02/AC-01] The proof checkpoints, appends more records, resumes from the checkpoint, and verifies only the new records were processed. <!-- [SRS-02/AC-01] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof-json --json, SRS-02:start:end, proof: ac-2.log -->
- [x] [SRS-NFR-01/AC-01] The materialization checkpoint contains a `LineageCheckpoint` anchor from the core engine, not a parallel model. <!-- [SRS-NFR-01/AC-01] verify: cargo test -p transit-materialize materializer_can_resume_from_checkpoint_without_reprocessing_old_records -- --nocapture, SRS-NFR-01:start:end, proof: ac-3.log -->

#### Implementation Insights
- **VIM1kQn2R: Materialization Proofs Need Public Resume Hooks**
  - Insight: Proof surfaces cannot validate checkpoint and resume behavior if `catch_up()`, `checkpoint()`, and checkpoint-based construction remain internal-only APIs.
  - Suggested Action: Keep checkpoint creation and checkpoint resume public on proof-facing engines so mission commands can verify lifecycle behavior directly.
  - Applies To: `crates/transit-materialize/src/engine.rs`, mission proof commands
  - Category: architecture


### Add Prolly Tree Snapshot Production To Materialization Proof
- **ID:** VEz8VmRFM
- **Status:** done

#### Summary
Extend the `materialization-proof` command to build a Prolly Tree snapshot from the materializer's derived state using `ProllyTreeBuilder` and `ObjectStoreProllyStore`, and produce a `SnapshotManifest` binding the root digest to the source checkpoint.

#### Acceptance Criteria
- [x] [SRS-03/AC-01] The proof builds a Prolly Tree from derived state entries and stores nodes via `ObjectStoreProllyStore`. <!-- [SRS-03/AC-01] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof-snapshot, SRS-03:start:end, proof: ac-1.log -->
- [x] [SRS-03/AC-02] The proof produces a `SnapshotManifest` with a root digest bound to the source `LineageCheckpoint`. <!-- [SRS-03/AC-02] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof-snapshot-json --json, SRS-03:start:end, proof: ac-2.log -->

#### Implementation Insights
- **VIF8a1x4U: Snapshot Proofs Should Bind To A Fresh Source Checkpoint**
  - Insight: The proof is cleaner when the snapshot manifest binds to a fresh post-catch-up checkpoint from the source stream, because the checkpoint already carries the verified stream id, head offset, manifest root, and production timestamp.
  - Suggested Action: Build snapshot manifests from a freshly verified `MaterializationCheckpoint` rather than synthesizing binding metadata separately in CLI code.
  - Applies To: `crates/transit-cli/src/main.rs`, `crates/transit-materialize/src/*`
  - Category: architecture

- **VIM1kQn2R: Materialization Proofs Need Public Resume Hooks**
  - Insight: Proof surfaces cannot validate checkpoint and resume behavior if `catch_up()`, `checkpoint()`, and checkpoint-based construction remain internal-only APIs.
  - Suggested Action: Keep checkpoint creation and checkpoint resume public on proof-facing engines so mission commands can verify lifecycle behavior directly.
  - Applies To: `crates/transit-materialize/src/engine.rs`, mission proof commands
  - Category: architecture


### Add Branch Aware Materialization Scenario To Proof
- **ID:** VEz8W0SPu
- **Status:** done

#### Summary
Extend the `materialization-proof` command with a branch-aware scenario: create a branch, append branch-specific records, materialize the branch independently, and produce a branch-local snapshot with a distinct root digest from the root stream snapshot.

#### Acceptance Criteria
- [x] [SRS-04/AC-01] The proof creates a branch, appends branch-specific records, and materializes the branch independently. <!-- [SRS-04/AC-01] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof-branch, SRS-04:start:end, proof: ac-1.log -->
- [x] [SRS-04/AC-02] The branch snapshot has a distinct root digest from the root stream snapshot. <!-- [SRS-04/AC-02] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture && cargo run -q -p transit-cli -- mission materialization-proof --root target/transit-mission/materialization-proof-branch-json --json, SRS-04:start:end, proof: ac-2.log -->
- [x] [SRS-05/AC-01] Materialization checkpoints and snapshots reference the same manifests and lineage model as the core engine. <!-- [SRS-05/AC-01] verify: cargo test -p transit-cli materialization_proof_ -- --nocapture, SRS-05:start:end, proof: ac-3.log -->

#### Implementation Insights
- **VIF8a1x4U: Snapshot Proofs Should Bind To A Fresh Source Checkpoint**
  - Insight: The proof is cleaner when the snapshot manifest binds to a fresh post-catch-up checkpoint from the source stream, because the checkpoint already carries the verified stream id, head offset, manifest root, and production timestamp.
  - Suggested Action: Build snapshot manifests from a freshly verified `MaterializationCheckpoint` rather than synthesizing binding metadata separately in CLI code.
  - Applies To: `crates/transit-cli/src/main.rs`, `crates/transit-materialize/src/*`
  - Category: architecture

- **VJ4yN7cLm: Branch Proofs Need Divergent Derived State**
  - Insight: If the reducer only tracks generic counters like processed-record count and last offset, a branch can accidentally produce the same snapshot digest as the root unless the branch point and branch-local appends force a different derived state.
  - Suggested Action: Choose branch fixtures that guarantee a distinct reduced state before asserting branch snapshot divergence, rather than assuming lineage alone will change the snapshot digest.
  - Applies To: `crates/transit-cli/src/main.rs`, materialization proof fixtures
  - Category: testing


### Integrate Materialization Proof Into Just Screen Flow
- **ID:** VEz8W9xVX
- **Status:** done

#### Summary
Add the `materialization-proof` mission command as a step in the `just screen` recipe.

#### Acceptance Criteria
- [x] [SRS-06/AC-01] `just screen` includes a "materialization proof" step that runs `transit mission materialization-proof` and reports pass/fail. <!-- [SRS-06/AC-01] verify: just screen, SRS-06:start:end, proof: ac-1.log -->
- [x] [SRS-NFR-02/AC-01] The materialization proof output is human-reviewable terminal text. <!-- [SRS-NFR-02/AC-01] verify: just screen, SRS-NFR-02:start:end, proof: ac-2.log -->

#### Implementation Insights
- **VK3sP2rNd: Proof Path Docs Must Track Just Screen Step Additions**
  - Insight: The `Justfile` change is not sufficient by itself because `README.md`, `GUIDE.md`, `AGENTS.md`, and `INSTRUCTIONS.md` all describe the default proof path and drift immediately if only one surface is updated.
  - Suggested Action: Treat `just screen` step changes as a bundled doc update across the recipe plus the operator-facing references that enumerate the default proof path.
  - Applies To: `Justfile`, `README.md`, `GUIDE.md`, `AGENTS.md`, `INSTRUCTIONS.md`
  - Category: process



