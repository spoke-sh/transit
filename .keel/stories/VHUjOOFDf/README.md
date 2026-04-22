---
# system-managed
id: VHUjOOFDf
status: backlog
created_at: 2026-04-21T22:27:49
updated_at: 2026-04-21T22:29:47
# authored
title: Route Published Manifests And Frontiers Through Object-Store Namespaces
type: feat
operator-signal:
scope: VHUjJj4Gh/VHUjMQyiY
index: 2
---

# Route Published Manifests And Frontiers Through Object-Store Namespaces

## Summary

Implement the published authority model so Transit writes immutable manifest snapshots and frontier pointers through object-store namespaces for filesystem and remote backends, while preserving the local working-plane append model.

## Acceptance Criteria

- [ ] [SRS-04/AC-01] Publication writes immutable segments before immutable manifests and advances the frontier pointer only after those artifacts are durable. <!-- [SRS-04/AC-01] verify: manual, SRS-04:start, SRS-04:end -->
- [ ] [SRS-05/AC-01] Recovery and latest discovery use the frontier pointer and immutable manifest snapshots rather than backend-specific listing assumptions. <!-- [SRS-05/AC-01] verify: manual, SRS-05:start, SRS-05:end -->
- [ ] [SRS-NFR-01/AC-01] Append, replay, lineage, durability, and retention semantics remain unchanged by the new authority model. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end -->
- [ ] [SRS-NFR-02/AC-01] Immutable published artifacts remain overwrite-free and only the small frontier pointer is updated in place. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end -->
