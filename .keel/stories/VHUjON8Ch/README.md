---
# system-managed
id: VHUjON8Ch
status: in-progress
created_at: 2026-04-21T22:27:49
updated_at: 2026-04-21T22:30:10
# authored
title: Define Published Frontier And Object-Store Authority Contract
type: feat
operator-signal:
scope: VHUjJj4Gh/VHUjMQyiY
index: 1
started_at: 2026-04-21T22:30:10
---

# Define Published Frontier And Object-Store Authority Contract

## Summary

Define the object-store-native authority contract for Transit's published state. This story captures the two-plane storage model, the immutable manifest snapshot plus mutable frontier pointer shape, and the namespace/schema decisions that implementation stories will build on.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] The authored planning artifacts explicitly separate the local mutable working plane from the object-store-native published authority plane. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end -->
- [ ] [SRS-02/AC-01] The published namespace contract is defined for both filesystem and remote object-store backends using the same segment/manifest/frontier concepts. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end -->
- [ ] [SRS-03/AC-01] The frontier object schema is defined with the fields needed for latest discovery and retained-frontier inspection. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end -->
- [ ] [SRS-NFR-03/AC-01] The contract keeps the hot append path outside the published object-store path. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end -->
