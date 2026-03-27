---
source_type: Story
source: stories/VEz8W0SPu/REFLECT.md
scope: VEz2huKbt/VEz3VMCrg
source_story_id: VEz8W0SPu
created_at: 2026-03-26T23:46:18
---

### VJ4yN7cLm: Branch Proofs Need Divergent Derived State

| Field | Value |
|-------|-------|
| **Category** | testing |
| **Context** | When proving branch-local snapshots with a very small reducer state. |
| **Insight** | If the reducer only tracks generic counters like processed-record count and last offset, a branch can accidentally produce the same snapshot digest as the root unless the branch point and branch-local appends force a different derived state. |
| **Suggested Action** | Choose branch fixtures that guarantee a distinct reduced state before asserting branch snapshot divergence, rather than assuming lineage alone will change the snapshot digest. |
| **Applies To** | `crates/transit-cli/src/main.rs`, materialization proof fixtures |
| **Linked Knowledge IDs** | VIF8a1x4U |
| **Observed At** | 2026-03-26T23:44:30+00:00 |
| **Score** | 0.74 |
| **Confidence** | 0.91 |
| **Applied** | yes |
