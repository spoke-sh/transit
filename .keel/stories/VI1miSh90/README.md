---
# system-managed
id: VI1miSh90
status: done
created_at: 2026-04-27T14:08:01
updated_at: 2026-04-27T14:55:02
# authored
title: Publish Downstream Workload Examples And Docs
type: docs
operator-signal:
scope: VI1mbSnsy/VI1mf8o0n
index: 3
started_at: 2026-04-27T14:51:30
submitted_at: 2026-04-27T14:54:17
completed_at: 2026-04-27T14:55:02
---

# Publish Downstream Workload Examples And Docs

## Summary

Publish downstream-facing examples and documentation that show typed AI and communication helpers creating, branching, replaying, backlinking, summarizing, and merging lineage-rich workloads.

## Acceptance Criteria

- [x] [SRS-04/AC-01] Documentation includes one AI trace example that uses typed helpers for task root, branch, tool/evaluator event, merge artifact, and checkpoint flows. <!-- [SRS-04/AC-01] verify: manual, SRS-04:start, SRS-04:end, proof: ac-1.log-->
- [x] [SRS-04/AC-02] Documentation includes one communication example that uses typed helpers for channel root, thread branch, backlink, summary, and override flows. <!-- [SRS-04/AC-02] verify: manual, SRS-04:start, SRS-04:end, proof: ac-2.log-->
- [x] [SRS-03/AC-01] Examples demonstrate that helper output is ordinary Transit payload bytes plus lineage or artifact metadata usable through embedded and hosted APIs. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-3.log-->
- [x] [SRS-NFR-01/AC-01] Public names and examples match `AI_TRACES.md`, `AI_ARTIFACTS.md`, and `COMMUNICATION.md` vocabulary. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-4.log-->
