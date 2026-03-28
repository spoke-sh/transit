---
# system-managed
id: VF7VSqlep
status: backlog
created_at: 2026-03-27T18:10:28
updated_at: 2026-03-27T18:12:14
# authored
title: Expose Replicated Acknowledgement Mode
type: feat
operator-signal:
scope: VDd1J2IDM/VF7VP3H4s
index: 2
---

# Expose Replicated Acknowledgement Mode

## Summary

Expose an explicit `replicated` acknowledgement mode that waits for publication of the clustered handoff frontier and keeps operator proof surfaces clear about what has, and has not, been guaranteed.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] Add an explicit `replicated` acknowledgement path that waits for publication of the handoff unit rather than reporting success on local durability alone. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end -->
- [ ] [SRS-04/AC-01] Extend proof or inspection surfaces so operators can distinguish `local`, `replicated`, and `tiered` commitments for the clustered slice. <!-- [SRS-04/AC-01] verify: manual, SRS-04:start, SRS-04:end -->
- [ ] [SRS-NFR-03/AC-01] Keep guarantee language explicit about publication, follower hydration, and the absence of failover or quorum claims. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end -->
