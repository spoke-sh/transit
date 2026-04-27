---
# system-managed
id: VI1mjiCB8
status: done
created_at: 2026-04-27T14:08:05
updated_at: 2026-04-27T15:12:50
# authored
title: Replace Object Store Lease Writes With Conditional Fencing
type: feat
operator-signal:
scope: VI1mcFKum/VI1mfwr25
index: 2
started_at: 2026-04-27T15:05:47
completed_at: 2026-04-27T15:12:50
---

# Replace Object Store Lease Writes With Conditional Fencing

## Summary

Replace plain object-store lease overwrites with conditional fencing or an explicit weaker-backend contract for acquire, heartbeat, handoff, and manifest publication.

## Acceptance Criteria

- [x] [SRS-03/AC-01] Object-store consensus uses conditional writes or equivalent generation checks for acquire, heartbeat, and handoff where the backend supports it. <!-- [SRS-03/AC-01] verify: cargo test -p transit-core consensus::tests::object_store_consensus, SRS-03:start, SRS-03:end, proof: ac-1.log-->
- [x] [SRS-04/AC-01] Manifest publication fails closed when the current remote lease proof cannot be verified against the object-store authority. <!-- [SRS-04/AC-01] verify: cargo test -p transit-core manifest_publication_enforces_distributed_fencing, SRS-04:start, SRS-04:end, proof: ac-2.log-->
- [x] [SRS-NFR-02/AC-01] Tests cover stale owner overwrite attempts and prove Transit rejects overstated ownership or durability claims. <!-- [SRS-NFR-02/AC-01] verify: just test, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log-->
