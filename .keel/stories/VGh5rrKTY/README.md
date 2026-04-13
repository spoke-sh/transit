---
# system-managed
id: VGh5rrKTY
status: backlog
created_at: 2026-04-13T10:43:29
updated_at: 2026-04-13T10:45:58
# authored
title: Document Hosted Authority Contract For External Workload Consumers
type: docs
operator-signal:
scope: VGh59soBt/VGh5B5qMT
index: 1
---

# Document Hosted Authority Contract For External Workload Consumers

## Summary

Author the canonical hosted-authority contract for Hub-like consumers so endpoint selection, access-token usage, and durability posture are explicit and local embedded authority is called out as the wrong model for hosted consumer-owned workloads.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] The authored contract explains how external workload consumers target transit-server for hosted append and replay, including endpoint, token, and durability posture expectations. <!-- verify: manual, SRS-01:start:end -->
- [ ] [SRS-NFR-01/AC-01] The contract keeps hosted authority framed as a thin remote protocol and server contract rather than a second storage engine embedded in the consumer. <!-- verify: manual, SRS-NFR-01:start:end -->
