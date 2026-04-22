---
# system-managed
id: VHUSh597Y
status: backlog
created_at: 2026-04-21T21:21:30
updated_at: 2026-04-21T21:24:13
# authored
title: Compress Rolled Segments And Preserve Replay Semantics
type: feat
operator-signal:
scope: VHUSaJ0w8/VHUSdlUHb
index: 2
---

# Compress Rolled Segments And Preserve Replay Semantics

## Summary

Implement immutable segment compression in the shared engine by compressing rolled segments only, preserving the active head as raw append state, and making replay, restore, and hosted reads transparently decode compressed history without changing logical records.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] Rolled immutable segments are compressed according to the authored codec while the active head remains uncompressed. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-1.log -->
- [ ] [SRS-04/AC-01] Replay, recovery, tiered publication/hydration, and hosted read paths verify stored bytes and transparently decompress before parsing logical records. <!-- [SRS-04/AC-01] verify: manual, SRS-04:start, SRS-04:end, proof: ac-2.log -->
- [ ] [SRS-05/AC-01] Size-sensitive behavior stays explicit about stored bytes while logical offsets, record counts, and replay-visible payloads remain unchanged. <!-- [SRS-05/AC-01] verify: manual, SRS-05:start, SRS-05:end, proof: ac-3.log -->
- [ ] [SRS-NFR-02/AC-01] Checksums and content digests continue to validate the stored segment bytes and remain bound to codec metadata in descriptors/manifests. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-4.log -->
- [ ] [SRS-NFR-03/AC-01] Compression does not change logical payload bytes, offsets, replay order, branch ancestry, merge ancestry, or hosted read/tail semantics. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-5.log -->
