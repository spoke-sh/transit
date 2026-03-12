---
id: VDeaLlyeK
title: Prove Crash Recovery And Durable Mission Verification
type: feat
status: in-progress
created_at: 2026-03-12T04:59:06
updated_at: 2026-03-12T05:33:30
operator-signal: 
scope: VDeYUdLSW/VDeaFjrZW
index: 3
started_at: 2026-03-12T05:33:30
---

# Prove Crash Recovery And Durable Mission Verification

## Summary

Prove that the local engine can restart from committed state safely and that `just mission` exposes durable-engine behavior instead of only static scaffolding.

## Acceptance Criteria

- [ ] [SRS-05/AC-01] The story proves crash recovery reconstructs committed local engine state while excluding trailing uncommitted bytes. <!-- [SRS-05/AC-01] verify: manual, SRS-05:start, SRS-05:end, proof: ac-1.log-->
- [ ] [SRS-06/AC-01] The story upgrades CLI or `just mission` proof surfaces so humans can verify append, replay, lineage, and recovery behavior end to end. <!-- [SRS-06/AC-01] verify: manual, SRS-06:start, SRS-06:end, proof: ac-2.log-->
- [ ] [SRS-NFR-03/AC-01] The durable-engine proof path remains explicit about durability and recovery guarantees instead of hiding them behind generic success output. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log-->
