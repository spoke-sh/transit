---
# system-managed
id: VFDyklixV
status: done
created_at: 2026-03-28T20:44:27
updated_at: 2026-03-29T11:39:05
# authored
title: Surface Promotion Eligibility Frontier
type: feat
operator-signal:
scope: VFDyfjLlI/VFDyiCVpL
index: 1
started_at: 2026-03-29T11:34:49
submitted_at: 2026-03-29T11:39:00
completed_at: 2026-03-29T11:39:05
---

# Surface Promotion Eligibility Frontier

## Summary

Expose the frontier and ownership signals needed to decide whether a follower is promotable, so handoff logic and operator proof surfaces share one explicit readiness contract.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Surface promotion eligibility in terms of published frontier position and ownership posture rather than ad hoc node-local heuristics. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log-->
- [x] [SRS-01/AC-02] Make ineligibility explicit when a follower is behind the required frontier or lacks the ownership preconditions for transfer. <!-- [SRS-01/AC-02] verify: manual, SRS-01:continues, SRS-01:end, proof: ac-2.log-->
- [x] [SRS-NFR-01/AC-01] Preserve shared-engine lineage and publication semantics while surfacing readiness. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log-->
