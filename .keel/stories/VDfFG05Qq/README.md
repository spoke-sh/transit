---
id: VDfFG05Qq
title: Implement Remote Branch Merge And Lineage Inspection
type: feat
status: backlog
created_at: 2026-03-12T07:41:36
updated_at: 2026-03-12T07:48:16
operator-signal: 
scope: VDfEx13Wu/VDfF629DK
index: 3
---

# Implement Remote Branch Merge And Lineage Inspection

## Summary

Implement the lineage-heavy remote operations so branch creation, merge recording, and ancestry inspection are available over the first server API instead of remaining embedded-only behavior.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] The story implements remote branch creation from explicit parent positions on the shared engine. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-1.log-->
- [ ] [SRS-03/AC-02] The story implements remote merge recording and lineage inspection on the same server surface. <!-- [SRS-03/AC-02] verify: manual, SRS-03:continues, SRS-03:end, proof: ac-2.log-->
- [ ] [SRS-NFR-02/AC-01] The remote lineage surface remains explicitly single-node and does not smuggle in replication or multi-writer semantics. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log-->
