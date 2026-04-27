---
# system-managed
id: VI1mjhoAK
status: backlog
created_at: 2026-04-27T14:08:05
updated_at: 2026-04-27T14:11:45
# authored
title: Enforce Hosted Auth Posture In Server Protocol
type: feat
operator-signal:
scope: VI1mcFKum/VI1mfwr25
index: 1
---

# Enforce Hosted Auth Posture In Server Protocol

## Summary

Enforce hosted token auth at the framed protocol boundary while preserving explicit local `none` mode and remote error envelopes.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] A server configured for token auth rejects unauthenticated framed requests before shared-engine mutation, while `none` mode remains available for local development. <!-- [SRS-01/AC-01] verify: automated, SRS-01:start, SRS-01:end -->
- [ ] [SRS-01/AC-02] Auth failures return remote error envelopes with request id, topology, stable error code, and actionable message. <!-- [SRS-01/AC-02] verify: automated, SRS-01:start, SRS-01:end -->
- [ ] [SRS-NFR-01/AC-01] Auth enforcement is a server boundary concern and does not introduce server-only storage or lineage semantics. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end -->
