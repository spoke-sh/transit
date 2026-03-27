---
created_at: 2026-03-26T23:40:11
---

# Reflection - Add Prolly Tree Snapshot Production To Materialization Proof

## Knowledge

- [VIF8a1x4U](../../knowledge/VIF8a1x4U.md) Snapshot Proofs Should Bind To A Fresh Source Checkpoint
- [VIM1kQn2R](../../knowledge/VIM1kQn2R.md) Materialization Proofs Need Public Resume Hooks

## Observations

- The proof extension stayed local to `transit-cli` because `transit-materialize` already exposed the builder and checkpoint primitives needed for snapshot production.
- The main integration hazard was crate-surface drift: using the checkpoint's existing `produced_at` avoided adding a new direct `chrono` dependency to `transit-cli`.
- Human and JSON proof runs were both useful here because the human output confirmed the snapshot evidence was readable, while JSON made it easy to assert the binding fields directly.
