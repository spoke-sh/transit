---
id: VDexcKG5C
title: Define Transit Materialization Contract
type: feat
status: done
created_at: 2026-03-12T06:31:32
updated_at: 2026-03-12T06:37:55
operator-signal: 
scope: VDd0u3PFg/VDexXBU7g
index: 1
started_at: 2026-03-12T06:36:06
submitted_at: 2026-03-12T06:37:47
completed_at: 2026-03-12T06:37:55
---

# Define Transit Materialization Contract

## Summary

Define the canonical `transit` materialization contract so future processors can consume replayable history, persist resumable checkpoints, and stay aligned with explicit lineage boundaries.

## Acceptance Criteria

- [x] [SRS-01/AC-01] The story authors a canonical materialization contract that defines replay cursors, lineage boundaries, checkpoint envelopes, and resume semantics for a future `transit-materialize` layer. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log -->
- [x] [SRS-NFR-01/AC-01] The contract keeps processors, checkpoint creation, and snapshot maintenance out of the append acknowledgement path and describes them as adjacent replay consumers. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-2.log -->
- [x] [SRS-NFR-02/AC-01] The contract remains compatible with both embedded and server packaging and with local or restored tiered history. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log -->
