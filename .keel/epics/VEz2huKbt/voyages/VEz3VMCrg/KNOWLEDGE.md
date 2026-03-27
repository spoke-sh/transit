---
created_at: 2026-03-26T23:50:46
---

# Knowledge - VEz3VMCrg

> Automated synthesis of story reflections.

## Story Knowledge

## Story: Add Prolly Tree Snapshot Production To Materialization Proof (VEz8VmRFM)

### VIF8a1x4U: Snapshot Proofs Should Bind To A Fresh Source Checkpoint

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | When proving a derived materialization snapshot against stream lineage. |
| **Insight** | The proof is cleaner when the snapshot manifest binds to a fresh post-catch-up checkpoint from the source stream, because the checkpoint already carries the verified stream id, head offset, manifest root, and production timestamp. |
| **Suggested Action** | Build snapshot manifests from a freshly verified `MaterializationCheckpoint` rather than synthesizing binding metadata separately in CLI code. |
| **Applies To** | `crates/transit-cli/src/main.rs`, `crates/transit-materialize/src/*` |
| **Applied** | yes |

### VIM1kQn2R: Materialization Proofs Need Public Resume Hooks

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | Adding a CLI proof on top of `LocalMaterializationEngine` |
| **Insight** | Proof surfaces cannot validate checkpoint and resume behavior if `catch_up()`, `checkpoint()`, and checkpoint-based construction remain internal-only APIs. |
| **Suggested Action** | Keep checkpoint creation and checkpoint resume public on proof-facing engines so mission commands can verify lifecycle behavior directly. |
| **Applies To** | `crates/transit-materialize/src/engine.rs`, mission proof commands |
| **Applied** | yes |



---

## Story: Add Branch Aware Materialization Scenario To Proof (VEz8W0SPu)

### VIF8a1x4U: Snapshot Proofs Should Bind To A Fresh Source Checkpoint

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | When proving a derived materialization snapshot against stream lineage. |
| **Insight** | The proof is cleaner when the snapshot manifest binds to a fresh post-catch-up checkpoint from the source stream, because the checkpoint already carries the verified stream id, head offset, manifest root, and production timestamp. |
| **Suggested Action** | Build snapshot manifests from a freshly verified `MaterializationCheckpoint` rather than synthesizing binding metadata separately in CLI code. |
| **Applies To** | `crates/transit-cli/src/main.rs`, `crates/transit-materialize/src/*` |
| **Applied** | yes |

### VJ4yN7cLm: Branch Proofs Need Divergent Derived State

| Field | Value |
|-------|-------|
| **Category** | testing |
| **Context** | When proving branch-local snapshots with a very small reducer state. |
| **Insight** | If the reducer only tracks generic counters like processed-record count and last offset, a branch can accidentally produce the same snapshot digest as the root unless the branch point and branch-local appends force a different derived state. |
| **Suggested Action** | Choose branch fixtures that guarantee a distinct reduced state before asserting branch snapshot divergence, rather than assuming lineage alone will change the snapshot digest. |
| **Applies To** | `crates/transit-cli/src/main.rs`, materialization proof fixtures |
| **Applied** | yes |



---

## Story: Integrate Materialization Proof Into Just Screen Flow (VEz8W9xVX)

### VK3sP2rNd: Proof Path Docs Must Track Just Screen Step Additions

| Field | Value |
|-------|-------|
| **Category** | process |
| **Context** | When adding a new proof step to the canonical `just screen` operator flow. |
| **Insight** | The `Justfile` change is not sufficient by itself because `README.md`, `GUIDE.md`, `AGENTS.md`, and `INSTRUCTIONS.md` all describe the default proof path and drift immediately if only one surface is updated. |
| **Suggested Action** | Treat `just screen` step changes as a bundled doc update across the recipe plus the operator-facing references that enumerate the default proof path. |
| **Applies To** | `Justfile`, `README.md`, `GUIDE.md`, `AGENTS.md`, `INSTRUCTIONS.md` |
| **Applied** | yes |



---

## Story: Implement Materialization Proof CLI Command With Checkpoint And Resume (VEz8Veo9i)

### VIM1kQn2R: Materialization Proofs Need Public Resume Hooks

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | Adding a CLI proof on top of `LocalMaterializationEngine` |
| **Insight** | Proof surfaces cannot validate checkpoint and resume behavior if `catch_up()`, `checkpoint()`, and checkpoint-based construction remain internal-only APIs. |
| **Suggested Action** | Keep checkpoint creation and checkpoint resume public on proof-facing engines so mission commands can verify lifecycle behavior directly. |
| **Applies To** | `crates/transit-materialize/src/engine.rs`, mission proof commands |
| **Applied** | yes |



---

## Synthesis

### is801uy0A: Snapshot Proofs Should Bind To A Fresh Source Checkpoint

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | When proving a derived materialization snapshot against stream lineage. |
| **Insight** | The proof is cleaner when the snapshot manifest binds to a fresh post-catch-up checkpoint from the source stream, because the checkpoint already carries the verified stream id, head offset, manifest root, and production timestamp. |
| **Suggested Action** | Build snapshot manifests from a freshly verified `MaterializationCheckpoint` rather than synthesizing binding metadata separately in CLI code. |
| **Applies To** | `crates/transit-cli/src/main.rs`, `crates/transit-materialize/src/*` |
| **Linked Knowledge IDs** | VIF8a1x4U |
| **Score** | 0.79 |
| **Confidence** | 0.90 |
| **Applied** | yes |

### VBqVZWjo9: Materialization Proofs Need Public Resume Hooks

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | Adding a CLI proof on top of `LocalMaterializationEngine` |
| **Insight** | Proof surfaces cannot validate checkpoint and resume behavior if `catch_up()`, `checkpoint()`, and checkpoint-based construction remain internal-only APIs. |
| **Suggested Action** | Keep checkpoint creation and checkpoint resume public on proof-facing engines so mission commands can verify lifecycle behavior directly. |
| **Applies To** | `crates/transit-materialize/src/engine.rs`, mission proof commands |
| **Linked Knowledge IDs** | VIM1kQn2R |
| **Score** | 0.90 |
| **Confidence** | 0.95 |
| **Applied** | yes |

### XRDFrjgyN: Snapshot Proofs Should Bind To A Fresh Source Checkpoint

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | When proving a derived materialization snapshot against stream lineage. |
| **Insight** | The proof is cleaner when the snapshot manifest binds to a fresh post-catch-up checkpoint from the source stream, because the checkpoint already carries the verified stream id, head offset, manifest root, and production timestamp. |
| **Suggested Action** | Build snapshot manifests from a freshly verified `MaterializationCheckpoint` rather than synthesizing binding metadata separately in CLI code. |
| **Applies To** | `crates/transit-cli/src/main.rs`, `crates/transit-materialize/src/*` |
| **Linked Knowledge IDs** | VIF8a1x4U |
| **Score** | 0.79 |
| **Confidence** | 0.90 |
| **Applied** | yes |

### sae9OW7m8: Branch Proofs Need Divergent Derived State

| Field | Value |
|-------|-------|
| **Category** | testing |
| **Context** | When proving branch-local snapshots with a very small reducer state. |
| **Insight** | If the reducer only tracks generic counters like processed-record count and last offset, a branch can accidentally produce the same snapshot digest as the root unless the branch point and branch-local appends force a different derived state. |
| **Suggested Action** | Choose branch fixtures that guarantee a distinct reduced state before asserting branch snapshot divergence, rather than assuming lineage alone will change the snapshot digest. |
| **Applies To** | `crates/transit-cli/src/main.rs`, materialization proof fixtures |
| **Linked Knowledge IDs** | VJ4yN7cLm |
| **Score** | 0.74 |
| **Confidence** | 0.91 |
| **Applied** | yes |

### l4DfvsAi0: Proof Path Docs Must Track Just Screen Step Additions

| Field | Value |
|-------|-------|
| **Category** | process |
| **Context** | When adding a new proof step to the canonical `just screen` operator flow. |
| **Insight** | The `Justfile` change is not sufficient by itself because `README.md`, `GUIDE.md`, `AGENTS.md`, and `INSTRUCTIONS.md` all describe the default proof path and drift immediately if only one surface is updated. |
| **Suggested Action** | Treat `just screen` step changes as a bundled doc update across the recipe plus the operator-facing references that enumerate the default proof path. |
| **Applies To** | `Justfile`, `README.md`, `GUIDE.md`, `AGENTS.md`, `INSTRUCTIONS.md` |
| **Linked Knowledge IDs** | VK3sP2rNd |
| **Score** | 0.71 |
| **Confidence** | 0.95 |
| **Applied** | yes |

### Vp1gP8qI4: Materialization Proofs Need Public Resume Hooks

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | Adding a CLI proof on top of `LocalMaterializationEngine` |
| **Insight** | Proof surfaces cannot validate checkpoint and resume behavior if `catch_up()`, `checkpoint()`, and checkpoint-based construction remain internal-only APIs. |
| **Suggested Action** | Keep checkpoint creation and checkpoint resume public on proof-facing engines so mission commands can verify lifecycle behavior directly. |
| **Applies To** | `crates/transit-materialize/src/engine.rs`, mission proof commands |
| **Linked Knowledge IDs** | VIM1kQn2R |
| **Score** | 0.90 |
| **Confidence** | 0.95 |
| **Applied** | yes |

