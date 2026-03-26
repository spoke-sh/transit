---
# system-managed
id: VEz8Y3TQE
status: backlog
created_at: 2026-03-26T07:49:16
updated_at: 2026-03-26T08:06:55
# authored
title: Add Merge And Lineage Inspection To Python Client
type: feat
operator-signal:
scope: VEz2iOasp/VEz3VaL0a
index: 2
---

# Add Merge And Lineage Inspection To Python Client

## Summary

Extend the Python client with `lineage()` method for inspecting stream lineage (branch/merge DAG). The existing `create_merge()` method is already implemented; this story adds the inspection side.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] `TransitClient.lineage()` returns the lineage DAG for a stream including branch and merge relationships. <!-- [SRS-03/AC-01] verify: just python-client-proof, SRS-03:start:end -->
- [ ] [SRS-04/AC-01] The client surfaces server acknowledgement and error envelopes for lineage operations without reinterpreting them. <!-- [SRS-04/AC-01] verify: code review + just python-client-proof, SRS-04:start:end -->
