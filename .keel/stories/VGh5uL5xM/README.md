---
# system-managed
id: VGh5uL5xM
status: done
created_at: 2026-04-13T10:43:39
updated_at: 2026-04-13T12:55:55
# authored
title: Define Object-Store Authority And Warm-Cache Configuration Surface
type: feat
operator-signal:
scope: VGh59soBt/VGh5BgrVO
index: 1
started_at: 2026-04-13T12:54:28
submitted_at: 2026-04-13T12:55:50
completed_at: 2026-04-13T12:55:55
---

# Define Object-Store Authority And Warm-Cache Configuration Surface

## Summary

Define the server configuration and operator contract that makes object storage authoritative for tiered durability while treating local filesystem state as warm cache and working set only.

## Acceptance Criteria

- [x] [SRS-01/AC-01] The server configuration contract names the object-store authority inputs and the warm-cache inputs needed for hosted tiered durability. <!-- verify: manual, SRS-01:start:end, proof: ac-1.log-->
- [x] [SRS-NFR-01/AC-01] The design keeps server authority aligned with the shared manifest and lineage model instead of inventing a server-only durability semantic. <!-- verify: manual, SRS-NFR-01:start:end, proof: ac-2.log-->
