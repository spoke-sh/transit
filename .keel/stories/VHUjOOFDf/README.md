---
# system-managed
id: VHUjOOFDf
status: done
created_at: 2026-04-21T22:27:49
updated_at: 2026-04-21T22:50:00
# authored
title: Route Published Manifests And Frontiers Through Object-Store Namespaces
type: feat
operator-signal:
scope: VHUjJj4Gh/VHUjMQyiY
index: 2
started_at: 2026-04-21T22:49:04
submitted_at: 2026-04-21T22:50:00
completed_at: 2026-04-21T22:50:00
---

# Route Published Manifests And Frontiers Through Object-Store Namespaces

## Summary

Implement the published authority model so Transit writes immutable manifest snapshots and frontier pointers through object-store namespaces for filesystem and remote backends, while preserving the local working-plane append model.

## Acceptance Criteria

- [x] [SRS-04/AC-01] Publication writes immutable segments before immutable manifests and advances the frontier pointer only after those artifacts are durable. <!-- [SRS-04/AC-01] verify: manual, SRS-04:start, SRS-04:end, proof: ac-1.log -->
- [x] [SRS-05/AC-01] Recovery and latest discovery use the frontier pointer and immutable manifest snapshots rather than backend-specific listing assumptions. <!-- [SRS-05/AC-01] verify: manual, SRS-05:start, SRS-05:end, proof: ac-1.log -->
- [x] [SRS-NFR-01/AC-01] Append, replay, lineage, durability, and retention semantics remain unchanged by the new authority model. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-2.log -->
- [x] [SRS-NFR-02/AC-01] Immutable published artifacts remain overwrite-free and only the small frontier pointer is updated in place. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-2.log -->
