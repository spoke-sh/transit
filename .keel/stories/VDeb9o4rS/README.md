---
id: VDeb9o4rS
title: Prove Tiered Durability And Shared Engine Boundaries
type: feat
status: backlog
created_at: 2026-03-12T05:02:19
updated_at: 2026-03-12T05:03:22
operator-signal: 
scope: VDeYUdLSW/VDeb794qi
index: 2
---

# Prove Tiered Durability And Shared Engine Boundaries

## Summary

Prove that tiered durability and cold restore are still properties of the shared `transit` engine rather than a separate server-only integration path.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] The story upgrades CLI or `just mission` proof surfaces so humans can verify publication, restore, and tiered durability behavior end to end. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-1.log-->
- [ ] [SRS-NFR-01/AC-01] The proof path demonstrates that publication and restore use shared engine semantics instead of introducing server-only behavior. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-2.log-->
- [ ] [SRS-NFR-02/AC-01] The proof path remains explicit about durability, publication, and restore guarantees rather than hiding them behind generic success output. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log-->
