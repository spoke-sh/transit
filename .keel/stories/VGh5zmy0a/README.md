---
# system-managed
id: VGh5zmy0a
status: backlog
created_at: 2026-04-13T10:44:00
updated_at: 2026-04-13T10:45:58
# authored
title: Prove Checkpointed Reconstruction Of Reference Projections
type: feat
operator-signal:
scope: VGh59soBt/VGh5CIxcc
index: 3
---

# Prove Checkpointed Reconstruction Of Reference Projections

## Summary

Prove that reference projections can be reconstructed from authoritative history and resumed checkpoints with equivalent results, giving external consumers a trustworthy rebuild path.

## Acceptance Criteria

- [ ] [SRS-04/AC-01] A proof surface rebuilds equivalent reference projection state from authoritative replay and checkpoint resume paths. <!-- verify: cargo run -q -p transit-cli -- mission reference-projection-proof --root target/transit-mission/reference-projection, SRS-04:start:end -->
- [ ] [SRS-NFR-02/AC-01] Projection checkpoints used by the proof anchor to the shared lineage and manifest model rather than a projection-only authority path. <!-- verify: cargo run -q -p transit-cli -- mission reference-projection-proof --root target/transit-mission/reference-projection --json, SRS-NFR-02:start:end -->
