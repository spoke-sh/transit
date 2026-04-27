---
# system-managed
id: VI1mjiCB8
status: backlog
created_at: 2026-04-27T14:08:05
updated_at: 2026-04-27T14:11:45
# authored
title: Replace Object Store Lease Writes With Conditional Fencing
type: feat
operator-signal:
scope: VI1mcFKum/VI1mfwr25
index: 2
---

# Replace Object Store Lease Writes With Conditional Fencing

## Summary

Replace plain object-store lease overwrites with conditional fencing or an explicit weaker-backend contract for acquire, heartbeat, handoff, and manifest publication.

## Acceptance Criteria

- [ ] [SRS-02/AC-01] Object-store consensus uses conditional writes or equivalent generation checks for acquire, heartbeat, and handoff where the backend supports it. <!-- [SRS-02/AC-01] verify: automated, SRS-02:start, SRS-02:end -->
- [ ] [SRS-02/AC-02] Manifest publication fails closed when the current remote lease proof cannot be verified against the object-store authority. <!-- [SRS-02/AC-02] verify: automated, SRS-02:start, SRS-02:end -->
- [ ] [SRS-NFR-01/AC-01] Tests cover stale owner overwrite attempts and prove Transit rejects overstated ownership or durability claims. <!-- [SRS-NFR-01/AC-01] verify: automated, SRS-NFR-01:start, SRS-NFR-01:end -->
