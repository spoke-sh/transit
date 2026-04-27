---
# system-managed
id: VI1mhEX4z
status: done
created_at: 2026-04-27T14:07:56
updated_at: 2026-04-27T14:29:59
# authored
title: Align Materialization Checkpoint Envelope With Published Contract
type: feat
operator-signal:
scope: VI1mae3rd/VI1meNvzJ
index: 2
started_at: 2026-04-27T14:23:24
submitted_at: 2026-04-27T14:29:51
completed_at: 2026-04-27T14:29:59
---

# Align Materialization Checkpoint Envelope With Published Contract

## Summary

Replace the thin hosted materialization checkpoint shape with the published checkpoint contract and keep resume validation tied to source lineage and manifest identity.

## Acceptance Criteria

- [x] [SRS-03/AC-01] The materialization checkpoint envelope carries view kind, source stream id, source offset, manifest generation/root, durability, lineage reference, state or state reference, optional snapshot reference, produced-at time, and materializer version. <!-- [SRS-03/AC-01] verify: cargo test -p transit-core materialization_checkpoint -- --nocapture, SRS-03:start, SRS-03:end, proof: ac-1.log-->
- [x] [SRS-04/AC-01] Resume validation rejects stale, tampered, missing, or mismatched checkpoint anchors before replaying pending records. <!-- [SRS-04/AC-01] verify: cargo test -p transit-core remote_materialization_resume -- --nocapture && cargo test -p transit-client materialization_resume_cursor_rejects_tampered_checkpoint -- --nocapture, SRS-04:start, SRS-04:end, proof: ac-2.log-->
- [x] [SRS-NFR-02/AC-01] Checkpoint creation and resume validation remain outside the append acknowledgement path and preserve shared-engine semantics. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log-->
