---
# system-managed
id: VGj3nnHSG
status: backlog
created_at: 2026-04-13T18:47:49
updated_at: 2026-04-13T18:49:16
# authored
title: Define Consumer Acknowledgement And Error Contract
type: feat
operator-signal:
scope: VGj3EvcuK/VGj3HXPMa
index: 2
---

# Define Consumer Acknowledgement And Error Contract

## Summary

Define the acknowledgement, durability, and error vocabulary that downstream
consumers must preserve literally as the canonical hosted Transit contract.

## Acceptance Criteria

- [ ] [SRS-02/AC-01] The hosted consumer contract defines the acknowledgement, durability, and error surface for downstream repos. <!-- verify: manual, SRS-02:start:end -->
- [ ] [SRS-NFR-02/AC-02] The authored contract makes replacement posture explicit enough that downstream repos do not redefine acknowledgement or error behavior locally. <!-- verify: manual, SRS-NFR-02:start:end -->
