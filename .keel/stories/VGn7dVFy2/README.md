---
# system-managed
id: VGn7dVFy2
status: done
created_at: 2026-04-14T11:28:09
updated_at: 2026-04-14T11:47:43
# authored
title: Build Runtime Object-Store Provider Factory
type: feat
operator-signal:
scope: VGn6PdlVK/VGn6xmmDh
index: 1
started_at: 2026-04-14T11:42:21
completed_at: 2026-04-14T11:47:43
---

# Build Runtime Object-Store Provider Factory

## Summary

Add the shared object-store construction layer that turns authored Transit
storage config into a runtime object-store client. This is the enabling slice
for hosted tiered bootstrap and must fail closed instead of silently falling
back to local-only semantics.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Shared Transit runtime code can resolve the authored storage provider into a generic object-store client. <!-- verify: cargo test -p transit-core object_store_support::tests -- --nocapture, SRS-01:start:end, proof: ac-1.log -->
- [x] [SRS-NFR-01/AC-02] The provider-construction path is shared reusable runtime infrastructure instead of another ad hoc local-only helper. <!-- verify: cargo test -p transit-core object_store_support::tests -- --nocapture, SRS-NFR-01:start:end, proof: ac-2.log -->
