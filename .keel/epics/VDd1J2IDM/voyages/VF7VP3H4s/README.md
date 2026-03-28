---
# system-managed
id: VF7VP3H4s
status: in-progress
epic: VDd1J2IDM
created_at: 2026-03-27T18:10:14
# authored
title: Deliver Remote-Tier Replication Handoff Foundations
index: 2
updated_at: 2026-03-27T18:12:14
started_at: 2026-03-27T18:16:41
---

# Deliver Remote-Tier Replication Handoff Foundations

> Implement the first clustered handoff path by reusing shared-engine publication and restore semantics, adding explicit follower catch-up and replicated acknowledgement boundaries without consensus or multi-primary behavior.

## Documents

<!-- BEGIN DOCUMENTS -->
| Document | Description |
|----------|-------------|
| [SRS.md](SRS.md) | Requirements and verification criteria |
| [SDD.md](SDD.md) | Architecture and implementation details |
<!-- END DOCUMENTS -->

## Stories

<!-- BEGIN GENERATED -->
**Progress:** 2/3 stories complete

| Title | Type | Status |
|-------|------|--------|
| [Bootstrap Read-Only Follower Catch-Up](../../../../stories/VF7VSpveo/README.md) | feat | done |
| [Expose Replicated Acknowledgement Mode](../../../../stories/VF7VSqlep/README.md) | feat | backlog |
| [Surface Published Replication Frontier](../../../../stories/VF7VSqtej/README.md) | feat | done |
<!-- END GENERATED -->
