---
# system-managed
id: VGj3nnHSG
status: done
created_at: 2026-04-13T18:47:49
updated_at: 2026-04-13T19:29:16
# authored
title: Define Consumer Acknowledgement And Error Contract
type: feat
operator-signal:
scope: VGj3EvcuK/VGj3HXPMa
index: 2
started_at: 2026-04-13T19:28:12
submitted_at: 2026-04-13T19:29:13
completed_at: 2026-04-13T19:29:16
---

# Define Consumer Acknowledgement And Error Contract

## Summary

Define the acknowledgement, durability, and error vocabulary that downstream
consumers must preserve literally as the canonical hosted Transit contract.

## Acceptance Criteria

- [x] [SRS-02/AC-01] The hosted consumer contract defines the acknowledgement, durability, and error surface for downstream repos. <!-- verify: manual, SRS-02:start:end, proof: ac-1.log -->
- [x] [SRS-NFR-02/AC-02] The authored contract makes replacement posture explicit enough that downstream repos do not redefine acknowledgement or error behavior locally. <!-- verify: manual, SRS-NFR-02:start:end, proof: ac-2.log -->
