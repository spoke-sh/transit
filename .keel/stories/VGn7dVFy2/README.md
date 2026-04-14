---
# system-managed
id: VGn7dVFy2
status: backlog
created_at: 2026-04-14T11:28:09
updated_at: 2026-04-14T11:35:21
# authored
title: Build Runtime Object-Store Provider Factory
type: feat
operator-signal:
scope: VGn6PdlVK/VGn6xmmDh
index: 1
---

# Build Runtime Object-Store Provider Factory

## Summary

Add the shared object-store construction layer that turns authored Transit
storage config into a runtime object-store client. This is the enabling slice
for hosted tiered bootstrap and must fail closed instead of silently falling
back to local-only semantics.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] Shared Transit runtime code can resolve the authored storage provider into a generic object-store client. <!-- verify: manual, SRS-01:start:end -->
- [ ] [SRS-NFR-01/AC-02] The provider-construction path is shared reusable runtime infrastructure instead of another ad hoc local-only helper. <!-- verify: manual, SRS-NFR-01:start:end -->
