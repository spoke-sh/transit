---
# system-managed
id: VHUAurAqP
status: backlog
created_at: 2026-04-21T20:10:53
updated_at: 2026-04-21T20:15:13
# authored
title: Publish Retention Proof Coverage And Operator Guidance
type: feat
operator-signal:
scope: VHUAlZWZG/VHUApus0L
index: 3
---

# Publish Retention Proof Coverage And Operator Guidance

## Summary

Publish proof coverage and operator guidance for retention so create/list/status behavior, bounded replay, and the distinction from compaction remain explicit and testable.

## Acceptance Criteria

- [ ] [SRS-06/AC-01] The proof path exercises retention-aware create/list/status behavior and records evidence for bounded replay surfaces. <!-- [SRS-06/AC-01] verify: manual, SRS-06:start, SRS-06:end, proof: ac-1.log -->
- [ ] [SRS-06/AC-02] Operator guidance explains that retention is coarse-grained history aging, not Kafka-style compaction or selective erasure. <!-- [SRS-06/AC-02] verify: manual, SRS-06:continues, SRS-06:end, proof: ac-2.log -->
- [ ] [SRS-NFR-04/AC-01] Public guidance names the retained frontier and bounded replay consequences so operators can reason about cursor and replay fallout. <!-- [SRS-NFR-04/AC-01] verify: manual, SRS-NFR-04:start, SRS-NFR-04:end, proof: ac-3.log -->
