---
id: VDeaLnceg
title: Implement Durable Local Append And Segment Roll
type: feat
status: backlog
created_at: 2026-03-12T04:59:06
updated_at: 2026-03-12T05:01:14
operator-signal: 
scope: VDeYUdLSW/VDeaFjrZW
index: 4
---

# Implement Durable Local Append And Segment Roll

## Summary

Implement the first local write path so `transit` can durably append into an active segment, advance stream heads, and roll immutable segments plus manifest state without requiring server mode.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] The story implements durable local append that writes committed records into an active segment and returns explicit local stream positions. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log-->
- [ ] [SRS-02/AC-01] The story implements local segment roll and manifest persistence for committed engine state. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-2.log-->
- [ ] [SRS-NFR-03/AC-01] The story keeps durability boundaries explicit in tests or proof notes so committed versus uncommitted append behavior remains inspectable. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log-->
