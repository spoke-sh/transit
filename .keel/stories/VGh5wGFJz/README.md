---
# system-managed
id: VGh5wGFJz
status: backlog
created_at: 2026-04-13T10:43:46
updated_at: 2026-04-13T10:45:58
# authored
title: Hydrate Transit Server From Object-Store Authority When Warm Cache Is Missing
type: feat
operator-signal:
scope: VGh59soBt/VGh5BgrVO
index: 2
---

# Hydrate Transit Server From Object-Store Authority When Warm Cache Is Missing

## Summary

Implement the hydrate path that rebuilds server working state from authoritative remote manifests and segments when the warm cache is absent or stale.

## Acceptance Criteria

- [ ] [SRS-02/AC-01] transit-server can rebuild its working state from the authoritative remote tier when warm local state is missing or discarded. <!-- verify: cargo test -p transit-server hydrate_from_object_store_ -- --nocapture, SRS-02:start:end -->
- [ ] [SRS-NFR-02/AC-01] The hydrate path preserves acknowledged tiered history even when the warm cache has been removed. <!-- verify: cargo test -p transit-server hydrate_from_object_store_ -- --nocapture, SRS-NFR-02:start:end -->
