---
# system-managed
id: VHUAuquph
status: backlog
created_at: 2026-04-21T20:10:53
updated_at: 2026-04-21T20:15:13
# authored
title: Enforce Retention And Surface Retained Frontier Status
type: feat
operator-signal:
scope: VHUAlZWZG/VHUApus0L
index: 2
---

# Enforce Retention And Surface Retained Frontier Status

## Summary

Enforce age- and size-based retention in the shared engine by trimming only oldest eligible rolled segments, then expose the retained frontier through stream status so bounded replay is visible to operators and downstream tooling.

## Acceptance Criteria

- [ ] [SRS-04/AC-01] The shared engine trims oldest eligible rolled segments under configured age and/or size limits without touching the active segment. <!-- [SRS-04/AC-01] verify: manual, SRS-04:start, SRS-04:end, proof: ac-1.log -->
- [ ] [SRS-05/AC-01] Stream status exposes `retained_start_offset` or an equivalent earliest-retained field so callers can see where replayable history begins. <!-- [SRS-05/AC-01] verify: manual, SRS-05:start, SRS-05:end, proof: ac-2.log -->
- [ ] [SRS-NFR-02/AC-01] Retention logic remains shared-engine behavior across embedded and hosted surfaces instead of becoming a server-only lifecycle rule. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log -->
- [ ] [SRS-NFR-03/AC-01] Retention enforcement remains coarse-grained lifecycle management rather than compaction: retained history stays append-only and no individual retained records are rewritten. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-4.log -->
