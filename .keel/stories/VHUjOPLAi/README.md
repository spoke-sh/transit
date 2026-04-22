---
# system-managed
id: VHUjOPLAi
status: done
created_at: 2026-04-21T22:27:49
updated_at: 2026-04-21T22:59:08
# authored
title: Publish Proof Coverage And Operator Guidance For Object-Store Authority
type: feat
operator-signal:
scope: VHUjJj4Gh/VHUjMQyiY
index: 3
started_at: 2026-04-21T22:51:09
submitted_at: 2026-04-21T22:59:06
completed_at: 2026-04-21T22:59:08
---

# Publish Proof Coverage And Operator Guidance For Object-Store Authority

## Summary

Publish the proof path and public/operator guidance for the new authority model so users can see the mutable frontier boundary, understand immutable manifest snapshots, and verify that filesystem and remote backends share the same published concepts.

## Acceptance Criteria

- [x] [SRS-06/AC-01] Proof coverage demonstrates the object-store-native authority model and latest discovery path for published state. <!-- [SRS-06/AC-01] verify: manual, SRS-06:start, SRS-06:end -->
  Proof: `cargo test -p transit-cli --bin transit object_store_authority_proof` ([ac-1.log](./ac-1.log))
- [x] [SRS-NFR-04/AC-01] Public and operator-facing docs explicitly describe the working-plane versus published-plane split and the mutable frontier boundary. <!-- [SRS-NFR-04/AC-01] verify: manual, SRS-NFR-04:start, SRS-NFR-04:end -->
  Proof: public MDX docs plus `CONFIGURATION.md` updates ([ac-2.log](./ac-2.log))
