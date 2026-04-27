---
# system-managed
id: VI1mjhoAK
status: done
created_at: 2026-04-27T14:08:05
updated_at: 2026-04-27T15:05:09
# authored
title: Enforce Hosted Auth Posture In Server Protocol
type: feat
operator-signal:
scope: VI1mcFKum/VI1mfwr25
index: 1
started_at: 2026-04-27T14:56:52
submitted_at: 2026-04-27T15:04:52
completed_at: 2026-04-27T15:05:09
---

# Enforce Hosted Auth Posture In Server Protocol

## Summary

Enforce hosted token auth at the framed protocol boundary while preserving explicit local `none` mode and remote error envelopes.

## Acceptance Criteria

- [x] [SRS-01/AC-01] A server configured for token auth rejects unauthenticated framed requests before shared-engine mutation, while `none` mode remains available for local development. <!-- [SRS-01/AC-01] verify: cargo test -p transit-core auth, SRS-01:start, SRS-01:end, proof: ac-1.log-->
- [x] [SRS-02/AC-01] Auth failures return remote error envelopes with request id, topology, stable error code, and actionable message. <!-- [SRS-02/AC-01] verify: cargo test -p transit-core token_auth_rejects_unauthenticated_requests_before_shared_engine_mutation, SRS-02:start, SRS-02:end, proof: ac-2.log-->
- [x] [SRS-NFR-01/AC-01] Auth enforcement is a server boundary concern and does not introduce server-only storage or lineage semantics. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log-->
