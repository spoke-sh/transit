---
# system-managed
id: VGh5yTni5
status: backlog
created_at: 2026-04-13T10:43:54
updated_at: 2026-04-13T10:45:58
# authored
title: Define Reference Projection Reducer Contracts
type: feat
operator-signal:
scope: VGh59soBt/VGh5CIxcc
index: 1
---

# Define Reference Projection Reducer Contracts

## Summary

Define the reference reducer inputs, extension points, and checkpoint vocabulary needed to derive consumer-owned views from authoritative history without turning Transit core into a policy engine.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] The authored reducer contract defines the reference inputs and extension points required to derive authoritative views from replay. <!-- verify: manual, SRS-01:start:end -->
- [ ] [SRS-NFR-03/AC-01] The contract keeps provider-specific policy, consumer business rules, and canonical downstream schemas out of Transit core. <!-- verify: manual, SRS-NFR-03:start:end -->
