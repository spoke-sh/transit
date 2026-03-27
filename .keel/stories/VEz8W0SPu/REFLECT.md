---
created_at: 2026-03-26T23:46:18
---

# Reflection - Add Branch Aware Materialization Scenario To Proof

## Knowledge

- [VIF8a1x4U](../../knowledge/VIF8a1x4U.md) Snapshot Proofs Should Bind To A Fresh Source Checkpoint
- [VJ4yN7cLm](../../knowledge/VJ4yN7cLm.md) Branch Proofs Need Divergent Derived State

## Observations

- The cleanest implementation was refactoring snapshot construction into a helper so the root and branch scenarios share the same storage and manifest assertions.
- The branch scenario needed explicit lineage inspection against `StreamDescriptor::Branch` and manifest-root parity checks to satisfy the shared-model acceptance criterion without inventing extra client-side semantics.
- The human proof output was especially valuable here because it made the branch checkpoint root and branch snapshot root digest easy to compare at a glance.
