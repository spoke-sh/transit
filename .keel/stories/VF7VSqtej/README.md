---
# system-managed
id: VF7VSqtej
status: backlog
created_at: 2026-03-27T18:10:29
updated_at: 2026-03-27T18:12:14
# authored
title: Surface Published Replication Frontier
type: feat
operator-signal:
scope: VDd1J2IDM/VF7VP3H4s
index: 2
---

# Surface Published Replication Frontier

## Summary

Surface the published segment-plus-manifest frontier that defines the clustered handoff boundary so follower catch-up, replicated acknowledgements, and proof surfaces all share one inspectable replication unit.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] Expose the published segment and manifest frontier as the first clustered handoff surface without creating a separate replicated log. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end -->
- [ ] [SRS-01/AC-02] Make frontier metadata explicit enough for follower catch-up and proof surfaces to identify the published positions and manifest state in play. <!-- [SRS-01/AC-02] verify: manual, SRS-01:continues, SRS-01:end -->
- [ ] [SRS-NFR-01/AC-01] Preserve shared-engine lineage and object-store semantics in the surfaced frontier. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end -->
