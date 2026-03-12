---
id: VDeb9oJrQ
title: Implement Object-Store Publication For Rolled Segments
type: feat
status: in-progress
created_at: 2026-03-12T05:02:19
updated_at: 2026-03-12T06:01:42
operator-signal: 
scope: VDeYUdLSW/VDeb794qi
index: 3
started_at: 2026-03-12T06:01:42
---

# Implement Object-Store Publication For Rolled Segments

## Summary

Implement publication of rolled immutable segments and their manifest references so object storage becomes part of the normal durable-engine lifecycle instead of an external afterthought.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] The story implements publication of rolled immutable segments to object storage through shared engine-facing code. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, proof: ac-1.log-->
- [ ] [SRS-01/AC-02] The story updates or emits manifest state so published remote objects remain resolvable for later restore. <!-- [SRS-01/AC-02] verify: manual, SRS-01:continues, SRS-01:end, proof: ac-2.log-->
- [ ] [SRS-NFR-02/AC-01] The publication path keeps durability and publication guarantees explicit in tests or proof notes. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log-->
