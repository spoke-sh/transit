---
# system-managed
id: VHYEATqz5
status: in-progress
created_at: 2026-04-22T12:48:53
updated_at: 2026-04-22T12:52:26
# authored
title: Add Hosted Materialization Cursor And Checkpoint Protocol Contract
type: feat
operator-signal:
scope: VHYE3HF6J/VHYE9AqjG
index: 1
started_at: 2026-04-22T12:52:26
---

# Add Hosted Materialization Cursor And Checkpoint Protocol Contract

## Summary

Define the hosted materialization progress contract by adding durable cursor primitives plus a hosted checkpoint envelope that bind external-daemon materializers to source stream identity, anchor position, and lineage-aware verification data.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] Hosted cursor primitives can create, inspect, advance, and delete materialization progress for a source stream and materialization identity. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log -->
- [ ] [SRS-02/AC-01] The hosted checkpoint envelope carries materialization id, source stream id, source anchor position, lineage or manifest verification identity, opaque state bytes, and produced-at timestamp. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-2.log -->
- [ ] [SRS-NFR-01/AC-01] Cursor and checkpoint contracts preserve shared-engine lineage semantics and do not change authoritative append, read, or tail behavior. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log -->
