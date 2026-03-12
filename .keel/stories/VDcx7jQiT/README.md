---
id: VDcx7jQiT
title: Implement Local Segment And Manifest Scaffolding
type: feat
status: done
created_at: 2026-03-11T22:17:01
updated_at: 2026-03-11T23:27:11
operator-signal: 
scope: VDcx2lQGz/VDcx4sb6D
index: 2
started_at: 2026-03-11T23:25:37
completed_at: 2026-03-11T23:27:11
---

# Implement Local Segment And Manifest Scaffolding

## Summary

Add the first local segment and manifest scaffold in `transit-core` so the repo has a real storage
kernel slice that still preserves the object-store-native architecture.

## Acceptance Criteria

- [x] [SRS-02/AC-01] `transit-core` defines immutable segment and manifest scaffold types shared by embedded and server-facing code. <!-- [SRS-02/AC-01] verify: cargo test --workspace, SRS-02:start, proof: ac-1.log-->
- [x] [SRS-02/AC-02] The scaffold keeps object-store-facing persistence boundaries explicit instead of collapsing into a purely local-only design. <!-- [SRS-02/AC-02] verify: cargo test --workspace; cargo run -p transit-cli --bin transit -- object-store probe --root target/transit-mission/object-store, SRS-02:continues, SRS-02:end, proof: ac-2.log-->
- [x] [SRS-03/AC-01] The segment and manifest scaffold leaves a clear checkpoint and snapshot boundary for a future materialization layer. <!-- [SRS-03/AC-01] verify: cargo test --workspace, SRS-03:start, SRS-03:end, proof: ac-3.log-->
