---
source_type: Story
source: stories/VEz8VmRFM/REFLECT.md
scope: VEz2huKbt/VEz3VMCrg
source_story_id: VEz8VmRFM
created_at: 2026-03-26T23:40:11
---

### VIF8a1x4U: Snapshot Proofs Should Bind To A Fresh Source Checkpoint

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | When proving a derived materialization snapshot against stream lineage. |
| **Insight** | The proof is cleaner when the snapshot manifest binds to a fresh post-catch-up checkpoint from the source stream, because the checkpoint already carries the verified stream id, head offset, manifest root, and production timestamp. |
| **Suggested Action** | Build snapshot manifests from a freshly verified `MaterializationCheckpoint` rather than synthesizing binding metadata separately in CLI code. |
| **Applies To** | `crates/transit-cli/src/main.rs`, `crates/transit-materialize/src/*` |
| **Linked Knowledge IDs** | VIM1kQn2R |
| **Observed At** | 2026-03-26T23:40:30+00:00 |
| **Score** | 0.79 |
| **Confidence** | 0.90 |
| **Applied** | yes |
