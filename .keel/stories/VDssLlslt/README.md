---
id: VDssLlslt
title: Implement Object Store Backend For Prolly Trees
type: feat
status: done
created_at: 2026-03-14T15:38:25
updated_at: 2026-03-14T15:40:00
operator-signal: 
scope: VDoZWCfw3/VDoaYfn6o
index: 6
started_at: 2026-03-14T15:38:36
completed_at: 2026-03-14T15:40:00
---

# Implement Object Store Backend For Prolly Trees

## Summary

Implement an `ObjectStoreProllyStore` that uses the shared `object_store` abstraction to persist Prolly Tree nodes to the tiered storage layer.

## Acceptance Criteria

- [x] [SRS-NFR-01/AC-02] Implement `ObjectStoreProllyStore` in `transit-materialize`. <!-- [SRS-NFR-01/AC-02] verify: cargo test -p transit-materialize prolly::tests::object_store_prolly_store_persists_to_filesystem, SRS-NFR-01:start, SRS-NFR-01:end -->
- [x] [SRS-NFR-01/AC-03] Prove Prolly Tree persistence to a local filesystem object store. <!-- [SRS-NFR-01/AC-03] verify: cargo test -p transit-materialize prolly::tests::object_store_prolly_store_persists_to_filesystem, SRS-NFR-01:continues, SRS-NFR-01:end -->
